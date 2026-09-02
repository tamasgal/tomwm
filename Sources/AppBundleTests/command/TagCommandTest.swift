@testable import AppBundle
import Common
import XCTest

@MainActor
final class TagCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testParse() {
        testParseSingleCommandSucc("tag 3", TagCmdArgs(rawArgs: ["3"], tags: ["3"]))
        testParseSingleCommandSucc(
            "tag --toggle 3",
            TagCmdArgs(rawArgs: ["--toggle", "3"], tags: ["3"]).copy(\.toggle, true),
        )
        testParseSingleCommandSucc("tag --all", TagCmdArgs(rawArgs: ["--all"], tags: []).copy(\.all, true))

        testParseSingleCommandSucc("tag --index 3", TagCmdArgs(rawArgs: ["--index", "3"], indices: [3]))
        testParseSingleCommandSucc(
            "tag --toggle --index 2",
            TagCmdArgs(rawArgs: ["--toggle", "--index", "2"], indices: [2]).copy(\.toggle, true),
        )

        assertEquals(parseCommand("tag").errorOrNil, "At least one <tag> or --index argument is required")
        assertEquals(parseCommand("tag --all 3").errorOrNil, "--all takes no <tag> arguments")
        assertEquals(parseCommand("tag --all --index 1").errorOrNil, "ERROR: Conflicting options: --all, --index")
        testParseCommandHelp("tag --help")
    }

    /// A binding names a tag by position, so renaming a tag leaves every binding alone
    func testTagByIndex() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        await parseCommand("tag --index 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.tags.tagNames, ["4"])

        config.tags = ["base", "web", "dev", "doc"]
        await parseCommand("tag --window-id 1 --index 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.tags.tagNames, ["dev"])
    }

    func testTagToggleByIndex() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        await parseCommand("tag --toggle --index 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.tags.tagNames, ["1", "4"])
    }

    func testTagIndexOutOfRange() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()
        config.tags = ["a", "b"]

        let result = await parseCommand("tag --index 9").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Tag position 9 is out of range. There are 2 tags"])
    }

    func testRetagTheFocusedWindow() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        await parseCommand("tag 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.tags.tagNames, ["4"])
        // The window left the view, so it is no longer focused
        assertNil(focus.windowOrNil)
    }

    /// dwm's toggletag
    func testToggleAddsAndRemoves() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        await parseCommand("tag --toggle 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.tags.tagNames, ["1", "4"])

        await parseCommand("tag --toggle 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.tags.tagNames, ["1"])
    }

    /// A window always carries at least one tag, or it could never be reached again
    func testToggleCannotLeaveAWindowUntagged() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        let result = await parseCommand("tag --toggle 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["A window must carry at least one tag"])
        assertEquals(window.tags.tagNames, ["1"])
    }

    func testTagAllMakesTheWindowVisibleEverywhere() async {
        let window = TestWindow.new(id: 1)
        _ = window.focusWindow()

        await parseCommand("tag --all").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.tags.tagNames, config.tags)

        await parseCommand("view 6").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testNoWindow() async {
        let result = await parseCommand("tag 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
    }

    func testTagViaWindowIdFlag() async {
        let other = TestWindow.new(id: 2)
        _ = TestWindow.new(id: 1).focusWindow()

        await parseCommand("tag --window-id 2 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(other.tags.tagNames, ["4"])
        assertEquals(Window.get(byId: 1)?.tags.tagNames, ["1"])
    }
}
