import Foundation

// MARK: - Cache

public final actor Cache<Key: Hashable, Value> {
    // MARK: Lifecycle

    public init(provider: @escaping (Key) async throws -> Value) {
        self.provider = provider
    }

    // MARK: Public

    public func value(for key: Key) async throws -> (value: Value, cached: Bool) {
        if let value = cache.object(forKey: KeyWrapper(key))?.value {
            return (value, true)
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
                cache.setObject(ValueWrapper(value), forKey: KeyWrapper(key))
                for continuation in continuations[key] ?? [] {
                    continuation.resume(returning: (value, false))
                }
                return (value, false)
            } catch {
                for continuation in continuations[key] ?? [] {
                    continuation.resume(throwing: error)
                }
                throw error
            }
        }
    }

    public func clear() {
        cache.removeAllObjects()
    }

    // MARK: Private

    private var cache = NSCache<KeyWrapper, ValueWrapper>()

    private var inProgressValueFetches = Set<Key>()
    private var continuations: [Key: [CheckedContinuation<(Value, Bool), Error>]] = [:]

    private let provider: (Key) async throws -> Value
}

extension Cache {
    private final class KeyWrapper: NSObject {
        // MARK: Lifecycle

        init(_ key: Key) { self.key = key }

        // MARK: Internal

        let key: Key

        override var hash: Int { key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            guard let keyWrapper = object as? KeyWrapper else { return false }
            return keyWrapper.key == key
        }
    }

    private final class ValueWrapper {
        // MARK: Lifecycle

        init(_ value: Value) { self.value = value }

        // MARK: Internal

        let value: Value
    }
}
