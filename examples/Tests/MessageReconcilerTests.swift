import XCTest
// Add this file to a test target that imports the app module and exposes the example type.
// Replace YourAppModule with the real product module name before compiling.
// @testable import YourAppModule

final class MessageReconcilerTests: XCTestCase {
    func testRepeatedConfirmationDoesNotCreateExtraMessage() async {
        let store = VKMessageReconciler()
        let pending = await store.prepare(peerID: 10, content: "Привет", randomID: 123456)
        let first = await store.confirm(localID: pending.id, serverID: 900)
        let second = await store.confirm(localID: pending.id, serverID: 900)
        let list = await store.snapshot()
        XCTAssertEqual(first?.serverID, 900)
        XCTAssertEqual(second?.serverID, 900)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].state, .sent)
    }

    func testFailureRetainsPendingRecordForRetry() async {
        let store = VKMessageReconciler()
        let item = await store.prepare(peerID: 42, content: "Повторить", randomID: 445566)
        await store.markFailed(localID: item.id)
        let list = await store.snapshot()
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].state, .failed)
    }
}
