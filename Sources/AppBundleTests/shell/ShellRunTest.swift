@testable import AppBundle
import Common
import XCTest

@MainActor
final class ShellRunTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    private var selectedTags: [String] { focus.monitorState.tagset.tagNames }

    func testOrFirstSucceeds_shortCircuits() async {
        let result = await parseCommand("true || view 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(selectedTags, ["1"])
    }

    func testOrFirstFails_runsNext() async {
        let result = await parseCommand("false || view 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(selectedTags, ["2"])
    }

    func testOrAllFail_returnsLastExitCode() async {
        let result = await parseCommand("false || false || false").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 1)
    }

    func testOrChainStopsOnFirstSuccess() async {
        let result = await parseCommand("false || view 2 || view 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(selectedTags, ["2"])
    }

    func testAndFirstFails_shortCircuits() async {
        let result = await parseCommand("false && view 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 1)
        assertEquals(selectedTags, ["1"])
    }

    func testAndAllSucceed_returnsZero() async {
        let result = await parseCommand("true && view 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(selectedTags, ["2"])
    }

    func testAndChainStopsOnFirstFailure() async {
        let result = await parseCommand("view 2 && false && view 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 1)
        assertEquals(selectedTags, ["2"])
    }

    func testAndReturnsLastSuccessExitCode() async {
        let result = await parseCommand("true && true && true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
    }

    func testSeqRunsAllRegardlessOfExitCode() async {
        let result = await parseCommand("false; view 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(selectedTags, ["2"])
    }

    func testSeqReturnsLastCommandExitCode() async {
        let succThenFail = await parseCommand("true; false").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(succThenFail.exitCode.rawValue, 1)

        let failThenSucc = await parseCommand("false; true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(failThenSucc.exitCode.rawValue, 0)
    }

    func testSeqConcatenatesStdout() async {
        let result = await parseCommand("echo -- foo; echo -- bar; echo -- baz").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["foo", "bar", "baz"])
    }

    func testPipeReturnsOnlyLastStdout() async {
        let result = await parseCommand("echo -- foo | echo -- bar").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["bar"])
    }

    func testPipeForwardsIntermediateStderr() async {
        let result = await parseCommand("echo --stderr -- err1 | echo -- out2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["out2"])
        assertEquals(result.stderr, ["err1"])
    }

    func testPipePipefailReturnsRightmostNonZero() async {
        let leftFails = await parseCommand("false | true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(leftFails.exitCode.rawValue, 1)

        let rightFails = await parseCommand("true | false").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(rightFails.exitCode.rawValue, 1)

        let allSucceed = await parseCommand("true | true").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(allSucceed.exitCode.rawValue, 0)
    }

    func testPipeRunsBothSides() async {
        let result = await parseCommand("view 2 | view 3").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(selectedTags, ["3"])
    }
}
