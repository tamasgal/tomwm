@testable import AppBundle
import Common
import XCTest

@MainActor
final class ViewCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    private var selected: [String] { focus.monitorState.tagset.tagNames }

    func testParse() {
        testParseSingleCommandSucc("view 3", ViewCmdArgs(rawArgs: ["3"], tags: ["3"]))
        testParseSingleCommandSucc(
            "view --toggle 3",
            ViewCmdArgs(rawArgs: ["--toggle", "3"], tags: ["3"]).copy(\.toggle, true),
        )
        testParseSingleCommandSucc("view --all", ViewCmdArgs(rawArgs: ["--all"], tags: []).copy(\.all, true))
        testParseSingleCommandSucc(
            "view --back-and-forth",
            ViewCmdArgs(rawArgs: ["--back-and-forth"], tags: []).copy(\.backAndForth, true),
        )
        testParseSingleCommandSucc("view 1 2 3", ViewCmdArgs(rawArgs: ["1", "2", "3"], tags: ["1", "2", "3"]))

        testParseSingleCommandSucc("view --index 3", ViewCmdArgs(rawArgs: ["--index", "3"], indices: [3]))
        testParseSingleCommandSucc(
            "view --toggle --index 2",
            ViewCmdArgs(rawArgs: ["--toggle", "--index", "2"], indices: [2]).copy(\.toggle, true),
        )
        testParseSingleCommandSucc("view --index 1 3", ViewCmdArgs(rawArgs: ["--index", "1", "3"], indices: [1, 3]))

        assertEquals(parseCommand("view --all 3").errorOrNil, "--all and --back-and-forth take no <tag> arguments")
        assertEquals(parseCommand("view --toggle").errorOrNil, "--toggle requires at least one <tag> or --index argument")
        assertEquals(parseCommand("view --all --toggle 1").errorOrNil, "ERROR: Conflicting options: --all, --toggle")
        assertEquals(parseCommand("view --all --index 1").errorOrNil, "ERROR: Conflicting options: --all, --index")
        assertEquals(
            parseCommand("view --index 0").errorOrNil,
            "ERROR: Can't parse '0' as a tag position. Positions are 1-based",
        )
        assertEquals(
            parseCommand("view --index").errorOrNil,
            "ERROR: '--index' must be followed by at least one 1-based tag position",
        )
        testParseCommandHelp("view -h")
    }

    /// A binding names a tag by position, so renaming a tag leaves every binding alone
    func testViewByIndex() async {
        await parseCommand("view --index 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["3"])

        config.tags = ["base", "web", "dev", "doc"]
        await parseCommand("view --index 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["web"])
    }

    func testViewByIndexAndNameAgree() async {
        await parseCommand("view --index 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let byIndex = focus.monitorState.tagset

        await parseCommand("view 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        await parseCommand("view 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.monitorState.tagset, byIndex)
    }

    func testViewToggleByIndex() async {
        await parseCommand("view --toggle --index 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["1", "2"])

        await parseCommand("view --toggle --index 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["1"])
    }

    func testViewSeveralIndices() async {
        await parseCommand("view --index 2 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["2", "4"])
    }

    func testIndexOutOfRange() async {
        config.tags = ["a", "b"]
        let result = await parseCommand("view --index 5").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Tag position 5 is out of range. There are 2 tags"])
    }

    func testViewSingleTag() async {
        let result = await parseCommand("view 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(selected, ["3"])
    }

    func testViewSeveralTags() async {
        await parseCommand("view 2 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["2", "4"])
    }

    func testViewAll() async {
        await parseCommand("view --all").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, config.tags)
    }

    /// dwm's toggleview
    func testToggleAddsAndRemoves() async {
        await parseCommand("view --toggle 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["1", "2"])

        await parseCommand("view --toggle 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["1"])
    }

    /// dwm refuses a toggle that would leave nothing selected
    func testToggleCannotEmptyTheView() async {
        let result = await parseCommand("view --toggle 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["The view would become empty. At least one tag has to stay selected"])
        assertEquals(selected, ["1"])
    }

    /// dwm's view with an empty mask swaps the two tag sets
    func testBackAndForth() async {
        await parseCommand("view 5").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["5"])

        await parseCommand("view --back-and-forth").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["1"])

        await parseCommand("view --back-and-forth").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(selected, ["5"])
    }

    func testUnknownTag() async {
        let result = await parseCommand("view nope").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Unknown tag 'nope'. Known tags: 1, 2, 3, 4, 5, 6, 7, 8, 9"])
    }

    /// dwm calls focus(NULL) after every view change
    func testFocusFollowsTheView() async {
        let onTagOne = TestWindow.new(id: 1)
        let onTagTwo = TestWindow.new(id: 2, tags: TagMask(index: 1))
        _ = onTagOne.focusWindow()
        assertEquals(focus.windowOrNil?.windowId, 1)

        await parseCommand("view 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, onTagTwo.windowId)

        await parseCommand("view 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testViewingAnEmptyTagLeavesNoFocusedWindow() async {
        TestWindow.new(id: 1)
        await parseCommand("view 7").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertNil(focus.windowOrNil)
    }
}
