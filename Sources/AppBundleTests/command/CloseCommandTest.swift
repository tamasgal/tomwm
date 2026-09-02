@testable import AppBundle
import Common
import XCTest

@MainActor
final class CloseCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testSimple() async {
        TestWindow.new(id: 2)
        _ = TestWindow.new(id: 1).focusWindow()

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.monitorState.clients.count, 2)

        await parseCommand("close").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 2)
        assertEquals(focus.monitorState.clients.count, 1)
    }

    func testCloseViaWindowIdFlag() async {
        TestWindow.new(id: 2)
        _ = TestWindow.new(id: 1).focusWindow()

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.monitorState.clients.count, 2)

        await parseCommand("close --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(focus.windowOrNil?.windowId, 1)
        assertEquals(focus.monitorState.clients.count, 1)
        assertEquals(focus.monitorState.clients.map(\.windowId), [1])
    }

    func testCloseAllWindowsButCurrent() async {
        TestWindow.new(id: 3)
        TestWindow.new(id: 2)
        _ = TestWindow.new(id: 1).focusWindow()

        await parseCommand("close-all-windows-but-current").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(focus.monitorState.clients.map(\.windowId), [1])
    }

    /// A window on a tag nobody is looking at is not "in the way", so it survives
    func testCloseAllWindowsButCurrentSpareInvisibleWindows() async {
        TestWindow.new(id: 3, tags: TagMask(index: 4))
        TestWindow.new(id: 2)
        _ = TestWindow.new(id: 1).focusWindow()

        await parseCommand("close-all-windows-but-current").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(focus.monitorState.clients.map(\.windowId).sorted(), [1, 3])
    }
}
