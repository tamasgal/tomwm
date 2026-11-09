@testable import AppBundle
import Common
import XCTest

@MainActor
final class FocusCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    private var focused: UInt32? { focus.windowOrNil?.windowId }

    func testParse() {
        testParseSingleCommandSucc("focus next", FocusCmdArgs(rawArgs: ["next"], direction: .stack(.next)))
        testParseSingleCommandSucc("focus prev", FocusCmdArgs(rawArgs: ["prev"], direction: .stack(.prev)))
        testParseSingleCommandSucc("focus master", FocusCmdArgs(rawArgs: ["master"], direction: .master))
        testParseSingleCommandSucc("focus left", FocusCmdArgs(rawArgs: ["left"], direction: .cardinal(.left)))
        testParseSingleCommandSucc("focus --window-id 42", FocusCmdArgs(rawArgs: ["--window-id", "42"], windowId: 42))

        assertEquals(
            parseCommand("focus").errorOrNil,
            "Mandatory argument is missing. left|down|up|right|next|prev|master or --window-id is required",
        )
        assertEquals(
            parseCommand("focus bogus").errorOrNil,
            "ERROR: Can't parse 'bogus'\n       Possible values: left|down|up|right|next|prev|master",
        )
        assertEquals(
            parseCommand("focus --window-id 42 left").errorOrNil,
            "--window-id is incompatible with other options",
        )
        testParseCommandHelp("focus -h")
    }

    /// dwm's focusstack walks the client list, which is the tiling order
    func testFocusNext() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[0].focusWindow()

        await parseCommand("focus next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 2)

        await parseCommand("focus next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 3)
    }

    func testFocusMasterBackAndForth() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[2].focusWindow()

        await parseCommand("focus master").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 1)

        await parseCommand("focus master").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 3)

        await parseCommand("focus master").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 1)
    }

    func testFocusMasterSkipsInvisibleWindows() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[2].focusWindow()
        _ = windows[0].focusWindow()
        windows[2].tags = TagMask(index: 7)

        await parseCommand("focus master").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 2)
    }

    func testFocusNextWrapsAround() async {
        let windows = newWindows([1, 2])
        _ = windows[1].focusWindow()

        await FocusCommand.new(stack: .next).run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 1)
    }

    func testFocusPrev() async {
        let windows = newWindows([1, 2, 3])
        _ = windows[2].focusWindow()

        await parseCommand("focus prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 2)
    }

    func testFocusPrevWrapsAround() async {
        let windows = newWindows([1, 2])
        _ = windows[0].focusWindow()

        await parseCommand("focus prev").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 2)
    }

    func testInvisibleWindowsAreSkipped() async {
        let windows = newWindows([1, 2, 3])
        windows[1].tags = TagMask(index: 7)
        _ = windows[0].focusWindow()

        await parseCommand("focus next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 3)
    }

    func testIgnoreFloating() async {
        let windows = newWindows([1, 2, 3])
        windows[1].isFloating = true
        _ = windows[0].focusWindow()

        await parseCommand("focus --ignore-floating next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 3)
    }

    func testFocusByWindowId() async {
        let windows = newWindows([1, 2])
        _ = windows[0].focusWindow()

        await parseCommand("focus --window-id 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 2)
    }

    func testSingleWindowIsANoop() async {
        let windows = newWindows([1])
        _ = windows[0].focusWindow()

        let result = await parseCommand("focus next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["No window to focus"])
        assertEquals(focused, 1)
    }

    func testFailIfNoop() async {
        let windows = newWindows([1])
        _ = windows[0].focusWindow()

        let result = await parseCommand("focus --fail-if-noop next").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
    }

    /// The cardinal directions use the rects the tiling layout applied
    func testCardinalFocus() async throws {
        let windows = newWindows([1, 2, 3])
        _ = try await arrangedRects()
        // master on the left, two stacked windows on the right
        _ = windows[0].focusWindow()

        await parseCommand("focus right").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 2)

        await parseCommand("focus down").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 3)

        await parseCommand("focus up").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 2)

        await parseCommand("focus left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focused, 1)
    }

    func testCardinalFocusStopsAtTheEdge() async throws {
        let windows = newWindows([1, 2])
        _ = try await arrangedRects()
        _ = windows[0].focusWindow()

        let result = await parseCommand("focus left").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["No window to focus"])
        assertEquals(focused, 1)
    }
}
