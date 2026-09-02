@testable import AppBundle
import Common
import XCTest

@MainActor
final class FloatingCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testParse() {
        testParseSingleCommandSucc("floating", FloatingCmdArgs(rawArgs: []))
        testParseSingleCommandSucc("floating on", FloatingCmdArgs(rawArgs: ["on"]).copy(\.toggle, .on))
        testParseSingleCommandSucc("floating off", FloatingCmdArgs(rawArgs: ["off"]).copy(\.toggle, .off))
        assertEquals(
            parseCommand("floating --fail-if-noop").errorOrNil,
            "--fail-if-noop requires 'on' or 'off' argument",
        )
        testParseCommandHelp("floating -h")
    }

    func testToggle() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()
        assertEquals(window.isFloating, false)

        await parseCommand("floating").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isFloating, true)

        await parseCommand("floating").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isFloating, false)
    }

    func testOnAndOff() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        await parseCommand("floating on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isFloating, true)

        await parseCommand("floating off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isFloating, false)
    }

    /// dwm's isfixed: a window that can never be tiled cannot be un-floated either
    func testDialogsCannotBeTiled() async {
        let dialog = TestWindow.new(id: 1, isDialog: true)
        _ = dialog.focusWindow()
        assertEquals(dialog.isFloating, true)

        let result = await parseCommand("floating off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Window 1 is a dialog. Dialogs are always managed floating"])
        assertEquals(dialog.isFloating, true)
    }

    func testAlreadyInThatState() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        let result = await parseCommand("floating off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["Already tiled. Tip: use --fail-if-noop to exit with non-zero code"])
    }

    func testFailIfNoop() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        let result = await parseCommand("floating --fail-if-noop off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [])
    }

    func testNoWindow() async {
        let result = await parseCommand("floating").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
    }
}
