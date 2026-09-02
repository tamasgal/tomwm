@testable import AppBundle
import Common
import XCTest

@MainActor
final class EvalCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testParse() {
        testParseSingleCommandSucc("eval 'view 2'", EvalCmdArgs(rawArgs: []).copy(\.shellExpr, .initialized("view 2")))
        assertEquals(parseCommand("eval").errorOrNil, "ERROR: Argument '<tomwm-shell-expr>' is mandatory")
    }

    func testParseDashDash() {
        testParseSingleCommandSucc(
            "eval -- '--anything'",
            EvalCmdArgs(rawArgs: []).copy(\.shellExpr, .initialized("--anything")),
        )
        assertEquals(parseCommand("eval --").errorOrNil, "ERROR: Argument '<tomwm-shell-expr>' is mandatory")
    }

    func testRunSimpleCommand() async {
        let result = await parseCommand("eval 'view 2'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(focus.monitorState.tagset.tagNames, ["2"])
    }

    func testRunForwardsStdout() async {
        let result = await parseCommand("eval 'echo -- hello'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["hello"])
        assertEquals(result.stderr, [])
    }

    func testRunShellComposition() async {
        let result = await parseCommand("eval 'view 2 && view 3'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(focus.monitorState.tagset.tagNames, ["3"])
    }

    func testRunEmptyShellExpr() async {
        let result = await parseCommand("eval ''").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [])
    }

    func testRunUnrecognizedSubcommand() async {
        let result = await parseCommand("eval 'no-such-command'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Unrecognized subcommand 'no-such-command'"])
    }

    func testRunInnerParseFailureForwardsErrorAndExitCode() async {
        let result = await parseCommand("eval 'move'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["ERROR: Argument 'next|prev' is mandatory"])
    }

    func testRunRejectsInnerHelp() async {
        let result = await parseCommand("eval 'view --help'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["--help is not supported inside eval command"])
    }

    func testRunNestedEval() async {
        let result = await parseCommand("eval 'eval \"view 2\"'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, ["Illegal eval (Tip: nested evals are forbidden)"])
        assertEquals(focus.monitorState.tagset.tagNames, ["1"])
    }
}
