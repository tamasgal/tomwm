@testable import AppBundle
import Common
import XCTest

@MainActor
final class LayoutCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    private var layout: TomLayout { focus.monitorState.layout }

    func testParse() {
        testParseSingleCommandSucc("layout tile", LayoutCmdArgs(rawArgs: ["tile"], toggleBetween: [.tile]))
        testParseSingleCommandSucc("layout monocle", LayoutCmdArgs(rawArgs: ["monocle"], toggleBetween: [.monocle]))
        testParseSingleCommandSucc("layout floating", LayoutCmdArgs(rawArgs: ["floating"], toggleBetween: [.floating]))
        testParseSingleCommandSucc(
            "layout tile monocle",
            LayoutCmdArgs(rawArgs: ["tile", "monocle"], toggleBetween: [.tile, .monocle]),
        )
        testParseSingleCommandSucc(
            "layout --toggle",
            LayoutCmdArgs(rawArgs: ["--toggle"], toggleBetween: []).copy(\.toggleWithPrevious, true),
        )

        assertEquals(
            parseCommand("layout").errorOrNil,
            "Either --toggle or at least one tile|monocle|floating argument is required",
        )
        assertEquals(
            parseCommand("layout --toggle tile").errorOrNil,
            "Either --toggle or at least one tile|monocle|floating argument is required",
        )
        assertEquals(
            parseCommand("layout bogus").errorOrNil,
            "ERROR: Can't parse 'bogus'\n       Possible values: tile|monocle|floating",
        )
        assertEquals(
            parseCommand("layout --fail-if-noop tile monocle").errorOrNil,
            "--fail-if-noop allows only one <target-layout> argument",
        )
        testParseCommandHelp("layout -h")
    }

    func testSetLayout() async {
        assertEquals(layout, .tile)

        await parseCommand("layout monocle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(layout, .monocle)

        await parseCommand("layout floating").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(layout, .floating)
    }

    /// Several layouts cycle: the first one that is not the current layout wins
    func testCycleBetweenTwoLayouts() async {
        await parseCommand("layout tile monocle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(layout, .monocle)

        await parseCommand("layout tile monocle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(layout, .tile)
    }

    func testToggleReturnsToThePreviousLayout() async {
        await parseCommand("layout monocle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(layout, .monocle)

        await parseCommand("layout --toggle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(layout, .tile)

        await parseCommand("layout --toggle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(layout, .monocle)
    }

    func testAlreadyInThatLayout() async {
        let result = await parseCommand("layout tile").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["Already in the tile layout. Tip: use --fail-if-noop to exit with non-zero exit code"])
    }

    func testFailIfNoop() async {
        let result = await parseCommand("layout --fail-if-noop tile").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [])
        assertEquals(layout, .tile)
    }
}
