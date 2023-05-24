@testable import Caching
import XCTest

final class CacheTests: XCTestCase {
    func testValuesEqual() async {
        let singleExpectation = expectation(description: "Provider should have only been called once")
        singleExpectation.assertForOverFulfill = true
        singleExpectation.expectedFulfillmentCount = 1

        let cache = Cache<String, Int> { key in
            singleExpectation.fulfill()
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 10)
            return key.hashValue
        }

        let a = await cache.value(for: "123")
        let b = await cache.value(for: "123")

        await fulfillment(of: [singleExpectation])

        XCTAssertEqual(a, b, "Cache calls with the same key should be equal")
    }

    func testSimultaneousRequestsProcessOnce() async {
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
            _ = await cache.value(for: "123")
            doubleExpectation.fulfill()
        }

        Task {
            _ = await cache.value(for: "123")
            doubleExpectation.fulfill()
        }

        await fulfillment(of: [singleExpectation, doubleExpectation])
    }

    func testCallsDoNotBlockEachOther() async {
        let cache = Cache<String, Int> { key in
            try? await Task.sleep(nanoseconds: (NSEC_PER_SEC / 10) * UInt64(key.count))
            return key.hashValue
        }

        let firstExpectation = expectation(description: "First")
        firstExpectation.expectedFulfillmentCount = 2

        Task {
            _ = await cache.value(for: "123")
            firstExpectation.fulfill()
        }

        Task {
            _ = await cache.value(for: "123")
            firstExpectation.fulfill()
        }

        let secondExpectation = expectation(description: "Second")

        Task {
            _ = await cache.value(for: "1")
            secondExpectation.fulfill()
        }

        await fulfillment(of: [secondExpectation, firstExpectation], enforceOrder: true)
    }
}
