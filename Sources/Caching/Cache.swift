import Foundation

public actor Cache<Key: Hashable, Value> {
    // MARK: Lifecycle

    public init(provider: @escaping (Key) async -> Value) {
        self.provider = provider
    }

    // MARK: Public

    public func value(for key: Key) async -> Value {
        if let value = cache[key] {
            return value
        } else if inProgressValueFetches.contains(key) {
            return await withCheckedContinuation { continuation in
                continuations[key, default: []].append(continuation)
            }
        } else {
            inProgressValueFetches.insert(key)
            let value = await provider(key)
            cache[key] = value
            inProgressValueFetches.remove(key)
            for continuation in continuations[key] ?? [] {
                continuation.resume(returning: value)
            }
            continuations[key] = nil
            return value
        }
    }

    // MARK: Private

    private var cache: [Key: Value] = [:]

    private var inProgressValueFetches = Set<Key>()
    private var continuations: [Key: [CheckedContinuation<Value, Never>]] = [:]

    private let provider: (Key) async -> Value
}
