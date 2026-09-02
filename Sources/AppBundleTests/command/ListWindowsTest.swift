@testable import AppBundle
import Common
import XCTest

@MainActor
final class ListWindowsTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testParse() {
        assertEquals(parseCommand("list-windows --pid 1").errorOrNil, "Mandatory option is not specified (--focused|--all|--monitor|--tag)")
        assertNil(parseCommand("list-windows --tag 1 --pid 1").errorOrNil)
        assertEquals(parseCommand("list-windows --pid 1 --focused").errorOrNil, "--focused conflicts with other \"filtering\" flags")
        assertEquals(parseCommand("list-windows --pid 1 --all").errorOrNil, "--all conflicts with \"filtering\" flags. Please use '--monitor all' instead of '--all' alias")
        assertNil(parseCommand("list-windows --all").errorOrNil)
        assertEquals(parseCommand("list-windows --all --tag 1").errorOrNil, "ERROR: Conflicting options: --all, --tag")
        assertEquals(parseCommand("list-windows --all --focused").errorOrNil, "ERROR: Conflicting options: --all, --focused")
        assertEquals(parseCommand("list-windows --all --count --format %{window-title}").errorOrNil, "ERROR: Conflicting options: --count, --format")
        assertEquals(
            parseCommand("list-windows --all --focused --monitor mouse").errorOrNil,
            "ERROR: Conflicting options: --all, --focused")
        assertEquals(
            parseCommand("list-windows --all --focused --monitor mouse --tag selected").errorOrNil,
            "ERROR: Conflicting options: --all, --focused, --tag")
        assertEquals(
            parseCommand("list-windows --all --tag selected").errorOrNil,
            "ERROR: Conflicting options: --all, --tag")
        assertNil(parseCommand("list-windows --monitor mouse").errorOrNil)
        assertNil(parseCommand("list-windows --tag selected").errorOrNil)
        assertNil(parseCommand("list-windows --tag 1 2").errorOrNil)

        // --tag values
        assertEquals(
            parseCommand("list-windows --tag").errorOrNil,
            "ERROR: <tag>... is mandatory. <tag> possible values: (<tag-name>|selected)")
        assertEquals(parseCommand("list-windows --tag all").errorOrNil, "ERROR: 'all' is a reserved tag name")

        // --json
        assertEquals(parseCommand("list-windows --all --count --json").errorOrNil, "ERROR: Conflicting options: --count, --json")
        assertEquals(parseCommand("list-windows --all --format '%{right-padding}' --json").errorOrNil, "%{right-padding} interpolation variable is not allowed when --json is used")
        assertEquals(parseCommand("list-windows --all --format '%{window-title} |' --json").errorOrNil, "Only interpolation variables and spaces are allowed in \'--format\' when \'--json\' is used")
        assertNil(parseCommand("list-windows --all --format '%{window-title}' --json").errorOrNil)
    }

    func testInterpolationVariablesConsistency() {
        for kind in TomObjKind.allCases {
            switch kind {
                case .window:
                    assertTrue(FormatVar.WindowFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "window-") })
                case .app:
                    assertTrue(FormatVar.AppFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "app-") })
                case .tag:
                    assertTrue(FormatVar.TagFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "tag") })
                case .monitor:
                    assertTrue(FormatVar.MonitorFormatVar.allCases.allSatisfy { $0.rawValue.starts(with: "monitor-") })
            }
        }
    }

    func testFormat() {
        let titles: [TomObj] = [
            .window(.forTest(window: TestWindow.new(id: 2), title: "non-empty")),
            .window(.forTest(window: TestWindow.new(id: 1), title: "")),
        ]
        assertSucc(titles.format([.interVar(.formatVar(.window(.windowTitle)))]), ["non-empty", ""])

        let padded: [TomObj] = [
            .window(.forTest(window: TestWindow.new(id: 4), title: "non-empty")),
            .window(.forTest(window: TestWindow.new(id: 10), title: "")),
        ]
        assertSucc(padded.format([.interVar(.formatVar(.window(.windowId))), .interVar(.plainInterVar(.rightPadding)), .interVar(.formatVar(.window(.windowTitle)))]), ["4 non-empty", "10"])

        let separated: [TomObj] = [
            .window(.forTest(window: TestWindow.new(id: 6), title: "title1")),
            .window(.forTest(window: TestWindow.new(id: 20), title: "title2")),
        ]
        assertSucc(separated.format([.interVar(.formatVar(.window(.windowId))), .interVar(.plainInterVar(.rightPadding)), .literal(" | "), .interVar(.formatVar(.window(.windowTitle)))]), ["6  | title1", "20 | title2"])
    }

    func testRunFocusedNoWindow() async {
        let result = await parseCommand("list-windows --focused --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [noWindowIsFocused])
        assertEquals(result.stdout, [])
    }

    func testRunFocusedHappy() async {
        assertEquals(TestWindow.new(id: 1).focusWindow(), true)
        TestWindow.new(id: 2)
        let result = await parseCommand("list-windows --focused --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout, ["1"])
    }

    func testRunAll() async {
        TestWindow.new(id: 1, tags: TagMask(index: 0))
        TestWindow.new(id: 2, tags: TagMask(index: 1))
        let result = await parseCommand("list-windows --all --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, [])
        assertEquals(result.stdout.sorted(), ["1", "2"])
    }

    func testRunCount() async {
        TestWindow.new(id: 1, tags: TagMask(index: 0))
        TestWindow.new(id: 2, tags: TagMask(index: 0))
        TestWindow.new(id: 3, tags: TagMask(index: 1))
        let result = await parseCommand("list-windows --all --count").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["3"])
    }

    func testRunJson() async {
        TestWindow.new(id: 7)
        let result = await parseCommand("list-windows --all --format '%{window-id}' --json").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let expected = JSONEncoder.tomWmDefault.encodeToString([["window-id": 7]])
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, [expected])
    }

    func testRunFilterByTagName() async {
        TestWindow.new(id: 1, tags: TagMask(index: 0))
        TestWindow.new(id: 2, tags: TagMask(index: 1))
        let result = await parseCommand("list-windows --tag 1 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunFilterByMultipleTags() async {
        TestWindow.new(id: 1, tags: TagMask(index: 0))
        TestWindow.new(id: 2, tags: TagMask(index: 1))
        TestWindow.new(id: 3, tags: TagMask(index: 2))
        let result = await parseCommand("list-windows --tag 1 2 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout.sorted(), ["1", "2"])
    }

    func testRunFilterByTagSelected() async {
        TestWindow.new(id: 1, tags: TagMask(index: 0))
        TestWindow.new(id: 2, tags: TagMask(index: 1))
        assertEquals(mainMonitorInfo.state.tagset, TagMask(index: 0))
        let result = await parseCommand("list-windows --tag selected --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunFilterByUnknownTag() async {
        TestWindow.new(id: 1)
        let result = await parseCommand("list-windows --tag unknown-tag --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Unknown tag 'unknown-tag'. Known tags: \(config.tags.joined(separator: ", "))"])
    }

    func testRunFilterByMonitor() async {
        TestWindow.new(id: 1)
        let result = await parseCommand("list-windows --monitor focused --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stdout, ["1"])
    }

    func testRunInvalidMonitor() async {
        TestWindow.new(id: 1)
        let result = await parseCommand("list-windows --monitor 99 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stdout, [])
        assertEquals(result.stderr, ["Invalid monitor ID: 99"])
    }

    func testRunFilterByPid() async {
        TestWindow.new(id: 1)
        let matching = await parseCommand("list-windows --monitor all --pid 0 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(matching.exitCode.rawValue, 0)
        assertEquals(matching.stdout, ["1"])

        let mismatching = await parseCommand("list-windows --monitor all --pid 9999 --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(mismatching.exitCode.rawValue, 0)
        assertEquals(mismatching.stdout, [])
    }

    func testRunFilterByAppBundleId() async {
        TestWindow.new(id: 1)
        let matching = await parseCommand("list-windows --monitor all --app-bundle-id com.tamasgal.tomwm.test-app --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(matching.exitCode.rawValue, 0)
        assertEquals(matching.stdout, ["1"])

        let mismatching = await parseCommand("list-windows --monitor all --app-bundle-id com.unknown.app --format '%{window-id}'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(mismatching.exitCode.rawValue, 0)
        assertEquals(mismatching.stdout, [])
    }
}
