import Foundation

public actor Cache<Key: Hashable, Value> {
    // MARK: Lifecycle

    public init(provider: @escaping (Key) async throws -> Value) {
        self.provider = provider
    }

    // MARK: Public

    public func value(for key: Key) async throws -> Value {
        if let value = cache[key] {
            return value
        } else if inProgressValueFetches.contains(key) {
            return try await withCheckedThrowingContinuation { continuation in
                continuations[key, default: []].append(continuation)
            }
        } else {
            inProgressValueFetches.insert(key)
            defer {
                continuations[key] = nil
                inProgressValueFetches.remove(key)
            }
            do {
                let value = try await provider(key)
                cache[key] = value
                for continuation in continuations[key] ?? [] {
                    continuation.resume(returning: value)
                }
                return value
            } catch {
                for continuation in continuations[key] ?? [] {
                    continuation.resume(throwing: error)
                }
                throw error
            }
        }
    }

    public func clear() {
        cache.removeAll()
    }

    // MARK: Private

    private var cache: [Key: Value] = [:]

    private var inProgressValueFetches = Set<Key>()
    private var continuations: [Key: [CheckedContinuation<Value, Error>]] = [:]

    private let provider: (Key) async throws -> Value
}
