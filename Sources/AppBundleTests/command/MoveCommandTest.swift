@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    private var clients: [UInt32] { focus.monitorState.clients.map(\.windowId) }

    func testParse() {
        testParseSingleCommandSucc("move next", MoveCmdArgs(rawArgs: ["next"], direction: .next))
        testParseSingleCommandSucc("move prev", MoveCmdArgs(rawArgs: ["prev"], direction: .prev))

        assertEquals(parseCommand("move").errorOrNil, "ERROR: Argument 'next|prev' is mandatory")
        assertEquals(
            parseCommand("move left").errorOrNil,
            "ERROR: Can't parse 'left'. Possible values: next|prev",
        )
        testParseCommandHelp("move -h")
    }

    func testMoveNext() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[0].focusWindow()

        await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [2, 1, 3])
        // Moving reorders the tiling, it does not change which window is focused
        assertEquals(focus.windowOrNil?.windowId, 1)

        await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [2, 3, 1])
    }

    func testMovePrev() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[2].focusWindow()

        await parseCommand("move prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [1, 3, 2])
    }

    func testMoveNextWrapsAround() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[2].focusWindow()

        await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [3, 2, 1])
    }

    func testMovePrevWrapsAround() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[0].focusWindow()

        await parseCommand("move prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [3, 2, 1])
    }

    /// Only tiled windows take part, and the ones that do not keep their slot
    func testFloatingWindowsAreSkipped() async {
        let windows = newWindows([1, 2, 3])
        windows[1].isFloating = true
        _ = windows[0].focusWindow()

        await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [3, 2, 1])
    }

    func testInvisibleWindowsAreSkipped() async {
        let windows = newWindows([1, 2, 3])
        windows[1].tags = TagMask(index: 6)
        _ = windows[0].focusWindow()

        await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(clients, [3, 2, 1])
    }

    func testFloatingWindowCannotBeMoved() async {
        let windows = newWindows([1, 2])
        windows[0].isFloating = true
        _ = windows[0].focusWindow()

        let result = await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["Only tiled windows can be moved in the stack"])
        assertEquals(clients, [1, 2])
    }

    func testFloatingLayoutCannotBeMoved() async {
        let windows = newWindows([1, 2])
        mainMonitorInfo.state.layout = .floating
        _ = windows[0].focusWindow()

        let result = await parseCommand("move --fail-if-noop next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(clients, [1, 2])
    }

    func testSingleWindowHasNowhereToGo() async {
        let windows = newWindows([1])
        _ = windows[0].focusWindow()

        let result = await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["Nowhere to move the window"])
    }

    func testNoWindow() async {
        let result = await parseCommand("move next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
    }
}
