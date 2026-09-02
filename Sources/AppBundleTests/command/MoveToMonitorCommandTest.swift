@testable import AppBundle
import Common
import XCTest

@MainActor
final class MoveToMonitorCommandTest: XCTestCase {
    override func setUp() async throws { setUpMonitorsForTests() }

    func testParse() {
        testParseSingleCommandSucc("move-to-monitor next", MoveToMonitorCmdArgs(target: .relative(.next)))
        testParseSingleCommandSucc("move-to-monitor --fail-if-noop main", MoveToMonitorCmdArgs(target: .patterns([.main])).copy(\.failIfNoop, true))
        assertEquals(parseCommand("move-to-monitor --fail-if-noop next").errorOrNil, "--fail-if-noop is incompatible with (left|down|up|right|next|prev)")
        assertEquals(parseCommand("move-to-monitor --fail-if-noop left").errorOrNil, "--fail-if-noop is incompatible with (left|down|up|right|next|prev)")
        assertEquals(parseCommand("move-to-monitor --wrap-around main").errorOrNil, "--wrap-around is incompatible with <monitor-pattern> argument")
    }

    func testParseDashDash() {
        testParseSingleCommandSucc("move-to-monitor -- next", MoveToMonitorCmdArgs(target: .patterns([.pattern("next")!])))
        testParseSingleCommandSucc(
            "move-to-monitor -- main 2",
            MoveToMonitorCmdArgs(target: .patterns([.main, .sequenceNumber(2)])),
        )
        testParseSingleCommandSucc(
            "move-to-monitor --fail-if-noop -- next",
            MoveToMonitorCmdArgs(target: .patterns([.pattern("next")!])).copy(\.failIfNoop, true),
        )
        assertEquals(parseCommand("move-to-monitor --").errorOrNil, "ERROR: Argument \'(left|down|up|right|next|prev|<monitor-pattern>)\' is mandatory")
    }

    func testSameMonitorIsNoop() async {
        let window = TestWindow.new(id: 1)
        TestWindow.new(id: 2)
        assertEquals(window.focusWindow(), true)
        let tags = window.tags

        let result = await parseCommand("move-to-monitor main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 0)
        assertEquals(result.stderr, ["The window is already on that monitor"])
        assertEquals(mainMonitorInfo.state.clients.map(\.windowId), [2, 1])
        assertEquals(window.monitorPoint, mainMonitorInfo.rect.topLeftCorner)
        assertEquals(window.tags, tags)
        assertEquals(focus.windowOrNil?.windowId, 1)
    }

    func testSameMonitorFailIfNoop() async {
        let window = TestWindow.new(id: 1)
        assertEquals(window.focusWindow(), true)

        let result = await parseCommand("move-to-monitor --fail-if-noop main").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(result.exitCode.rawValue, 2)
        assertEquals(result.stderr, [])
        assertEquals(mainMonitorInfo.state.clients.map(\.windowId), [1])
        assertEquals(focus.windowOrNil?.windowId, 1)
    }
}
