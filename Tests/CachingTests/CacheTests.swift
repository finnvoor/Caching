@testable import Caching
import XCTest

final class CacheTests: XCTestCase {
    func testValuesEqual() async throws {
        let singleExpectation = expectation(description: "Provider should have only been called once")
        singleExpectation.assertForOverFulfill = true
        singleExpectation.expectedFulfillmentCount = 1

        let cache = Cache<String, Int> { key in
            singleExpectation.fulfill()
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 10)
            return key.hashValue
        }

        let (a, cachedA) = try await cache.value(for: "123")
        let (b, cachedB) = try await cache.value(for: "123")

        await fulfillment(of: [singleExpectation])

        XCTAssertEqual(a, b, "Cache calls with the same key should be equal")
        XCTAssertFalse(cachedA, "A should not have been cached")
        XCTAssertTrue(cachedB, "B should have been cached")
    }

    func testSimultaneousRequestsProcessOnce() async throws {
        let singleExpectation = expectation(description: "Provider should have only been called once")
        singleExpectation.assertForOverFulfill = true
        singleExpectation.expectedFulfillmentCount = 1

        let doubleExpectation = expectation(description: "Value should have been received twice")
        doubleExpectation.assertForOverFulfill = true
        doubleExpectation.expectedFulfillmentCount = 2

        let cache = Cache<String, Int> { key in
            singleExpectation.fulfill()
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 10)
            return key.hashValue
        }

        Task {
            _ = try await cache.value(for: "123")
            doubleExpectation.fulfill()
        }

        Task {
            _ = try await cache.value(for: "123")
            doubleExpectation.fulfill()
        }

        await fulfillment(of: [singleExpectation, doubleExpectation])
    }

    func testCallsDoNotBlockEachOther() async throws {
        let cache = Cache<String, Int> { key in
            try? await Task.sleep(nanoseconds: (NSEC_PER_SEC / 10) * UInt64(key.count))
            return key.hashValue
        }

        let firstExpectation = expectation(description: "First")
        firstExpectation.expectedFulfillmentCount = 2

        Task {
            _ = try await cache.value(for: "123")
            firstExpectation.fulfill()
        }

        Task {
            _ = try await cache.value(for: "123")
            firstExpectation.fulfill()
        }

        let secondExpectation = expectation(description: "Second")

        Task {
            _ = try await cache.value(for: "1")
            secondExpectation.fulfill()
        }

        await fulfillment(of: [secondExpectation, firstExpectation], enforceOrder: true)
    }
}
