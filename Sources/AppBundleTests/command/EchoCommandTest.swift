@testable import AppBundle
import Common
import XCTest

@MainActor
final class EchoCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testParse() {
        testParseSingleCommandSucc(
            "echo -- foo",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("foo")]])),
        )
        testParseSingleCommandSucc(
            "echo -- foo bar",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("foo")], [.literal("bar")]])),
        )
        testParseSingleCommandSucc(
            "echo --stderr -- foo",
            EchoCmdArgs(rawArgs: [])
                .copy(\.args, .initialized([[.literal("foo")]]))
                .copy(\.isStderr, true),
        )
        testParseSingleCommandSucc(
            "echo -- '%{window-id}'",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.interVar(.formatVar(.window(.windowId)))]])),
        )
        testParseSingleCommandSucc(
            "echo -- 'id: %{window-id}'",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("id: "), .interVar(.formatVar(.window(.windowId)))]])),
        )
        testParseSingleCommandSucc(
            "echo -- '%{tag}'",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.interVar(.formatVar(.tag(.tagName)))]])),
        )
        testParseSingleCommandSucc(
            "echo -- --stderr",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("--stderr")]])),
        )
        testParseSingleCommandSucc(
            "echo -- -h",
            EchoCmdArgs(rawArgs: []).copy(\.args, .initialized([[.literal("-h")]])),
        )

        testParseCommandFail("echo", msg: "ERROR: Argument '--' is mandatory\nERROR: Argument '<string>' is mandatory", exitCode: 2)
        testParseCommandFail("echo --", msg: "ERROR: Argument '<string>' is mandatory", exitCode: 2)
        testParseCommandFail("echo foo", msg: "ERROR: Expected: --. Got: 'foo'", exitCode: 2)
        testParseCommandFail("echo --stderr foo", msg: "ERROR: Expected: --. Got: 'foo'", exitCode: 2)
        testParseCommandFail("echo -- %{foo}", msg: "ERROR: Can't parse 'foo'.\n       Possible values: (window-id|window-is-fullscreen|window-is-floating|window-is-dialog|window-is-visible|window-tags|window-title|tag|tag-is-selected|tag-is-occupied|app-bundle-id|app-name|app-pid|app-exec-path|app-bundle-path|monitor-id|monitor-appkit-nsscreen-screens-id|monitor-name|monitor-is-main|monitor-layout|monitor-layout-symbol|monitor-tags|monitor-nmaster|monitor-mfact|right-padding|newline|tab)", exitCode: 2)

        testParseCommandHelp("echo -h")
        testParseCommandHelp("echo --help")
    }

    func testRunPlainNoWindow() async {
        let result = await parseCommand("echo -- foo").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["foo"])
    }

    func testRunMultipleArgs() async {
        let result = await parseCommand("echo -- foo bar baz").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["foo", "bar", "baz"])
    }

    func testRunStderr() async {
        let result = await parseCommand("echo --stderr -- foo").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["foo"])
    }

    func testRunWindowInterpolation() async {
        assertEquals(TestWindow.new(id: 1).focusWindow(), true)
        let result = await parseCommand("echo -- '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["1"])
    }

    func testRunWindowInterpolationNoWindow() async {
        let result = await parseCommand("echo -- '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, [noWindowIsFocused])
    }

    func testRunWindowTagsInterpolation() async {
        assertEquals(TestWindow.new(id: 1).focusWindow(), true)
        let result = await parseCommand("echo -- '%{window-tags}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunMonitorInterpolationNoWindow() async {
        let result = await parseCommand("echo -- '%{monitor-tags} %{monitor-layout-symbol}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["1 []="])
    }

    func testRunMixedLiteralAndInterpolation() async {
        assertEquals(TestWindow.new(id: 42).focusWindow(), true)
        let result = await parseCommand("echo -- 'id: %{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["id: 42"])
    }

    func testRunStderrWithInterpolation() async {
        assertEquals(TestWindow.new(id: 5).focusWindow(), true)
        let result = await parseCommand("echo --stderr -- '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["5"])
    }
}
