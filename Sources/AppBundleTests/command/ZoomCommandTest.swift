@testable import AppBundle
import Common
import XCTest

@MainActor
final class ZoomCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    private var clients: [UInt32] { focus.monitorState.clients.map(\.windowId) }

    func testParse() {
        testParseSingleCommandSucc("zoom", ZoomCmdArgs(rawArgs: []))
        testParseCommandHelp("zoom -h")
    }

    func testPromotesToMaster() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[2].focusWindow()

        await parseCommand("zoom").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(clients, [3, 1, 2])
        assertEquals(focus.windowOrNil?.windowId, 3)
    }

    /// dwm's zoom on the master swaps it with the next tiled window, so pressing twice takes you back
    func testZoomOnMasterSwapsWithTheNextWindow() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[0].focusWindow()

        await parseCommand("zoom").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [2, 1, 3])
        assertEquals(focus.windowOrNil?.windowId, 2)

        await parseCommand("zoom").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [1, 2, 3])
    }

    func testSingleWindowIsANoop() async {
        let windows = newWindows([1])
        _ = windows[0].focusWindow()

        let result = await parseCommand("zoom").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["The window is already the only master"])
        assertEquals(clients, [1])
    }

    func testFloatingWindowIsANoop() async {
        let windows = newWindows([1, 2])
        windows[1].isFloating = true
        _ = windows[1].focusWindow()

        let result = await parseCommand("zoom").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["zoom does nothing for a floating window"])
        assertEquals(clients, [1, 2])
    }

    func testFloatingLayoutIsANoop() async {
        let windows = newWindows([1, 2])
        mainMonitorInfo.state.layout = .floating
        _ = windows[1].focusWindow()

        let result = await parseCommand("zoom").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["zoom does nothing under the floating layout"])
        assertEquals(clients, [1, 2])
    }

    /// Only the visible windows take part, so a window on another tag keeps its place
    func testInvisibleWindowsKeepTheirPlace() async {
        let windows = newWindows([1, 2, 3])
        windows[1].tags = TagMask(index: 5)
        _ = windows[2].focusWindow()

        await parseCommand("zoom").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(clients, [3, 1, 2])
    }
}
