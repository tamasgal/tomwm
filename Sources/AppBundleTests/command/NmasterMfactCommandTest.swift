@testable import AppBundle
import Common
import XCTest

@MainActor
final class NmasterMfactCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    private var state: MonitorState { focus.monitorState }

    func testParseNmaster() {
        testParseSingleCommandSucc("nmaster 3", NmasterCmdArgs(rawArgs: ["3"], value: .absolute(3)))
        testParseSingleCommandSucc("nmaster +1", NmasterCmdArgs(rawArgs: ["+1"], value: .relative(1)))
        testParseSingleCommandSucc("nmaster -1", NmasterCmdArgs(rawArgs: ["-1"], value: .relative(-1)))

        assertEquals(parseCommand("nmaster").errorOrNil, "ERROR: Argument '<n>' is mandatory")
        assertEquals(
            parseCommand("nmaster abc").errorOrNil,
            "ERROR: Can't parse 'abc' as a number. Expected <n>, +<n> or -<n>",
        )
        testParseCommandHelp("nmaster -h")
    }

    func testParseMfact() {
        testParseSingleCommandSucc("mfact 0.5", MfactCmdArgs(rawArgs: ["0.5"], value: .absolute(0.5)))
        testParseSingleCommandSucc("mfact +0.05", MfactCmdArgs(rawArgs: ["+0.05"], value: .relative(0.05)))
        testParseSingleCommandSucc("mfact -0.05", MfactCmdArgs(rawArgs: ["-0.05"], value: .relative(-0.05)))

        assertEquals(parseCommand("mfact").errorOrNil, "ERROR: Argument '<fraction>' is mandatory")
        assertEquals(
            parseCommand("mfact abc").errorOrNil,
            "ERROR: Can't parse 'abc' as a number. Expected <fraction>, +<fraction> or -<fraction>",
        )
        testParseCommandHelp("mfact --help")
    }

    func testNmasterRelativeAndAbsolute() async {
        assertEquals(state.nmaster, 1)

        await parseCommand("nmaster +1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(state.nmaster, 2)

        await parseCommand("nmaster -1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(state.nmaster, 1)

        await parseCommand("nmaster 4").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(state.nmaster, 4)
    }

    /// dwm clamps nmaster at zero
    func testNmasterNeverGoesNegative() async {
        await parseCommand("nmaster -5").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(state.nmaster, 0)
    }

    func testMfactRelativeAndAbsolute() async {
        assertEquals(state.mfact, 0.55)

        await parseCommand("mfact +0.05").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertClose(state.mfact, 0.6)

        await parseCommand("mfact 0.25").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(state.mfact, 0.25)
    }

    func testMfactIsClamped() async {
        await parseCommand("mfact 5").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(state.mfact, maxMfact)

        await parseCommand("mfact -5").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(state.mfact, minMfact)
    }
}
