@testable import AppBundle
import Common
import Foundation
import HotKey
import XCTest

let projectRoot: URL = {
    var url = URL(filePath: #filePath).absoluteURL
    check(FileManager.default.fileExists(atPath: url.path))
    while !FileManager.default.fileExists(atPath: url.appending(component: ".git").path) {
        url.deleteLastPathComponent()
    }
    return url
}()

/// The single reset hook. Every test class that touches the model calls it in setUp.
@MainActor
func setUpMonitorsForTests() {
    config = defaultConfig
    configUrl = defaultConfigUrl
    // Don't create any bindings for tests
    config.modes = [mainModeId: Mode(bindings: [:])]
    // Pin what the layout and tag tests assert on, so they survive edits to the shipped config
    config.tags = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    config.defaultLayout = .tile
    config.nmaster = 1
    config.mfact = 0.55

    allTestWindows = [:]
    MacWindow.ignoredWindows = [:]
    resetClosedWindowsCache()
    resetMonitorStatesForTests()

    TestApp.shared.focusedWindow = nil
    TestApp.shared._windows = []

    _ = mainMonitorInfo.focusMonitor()
    check(focus.windowOrNil == nil)
    check(focus.monitorState.clients.isEmpty)
}

/// Create windows so that the monitor's client list ends up in exactly this order.
/// ``MonitorState/attach(_:)`` prepends, so they are created back to front.
@discardableResult
@MainActor
func newWindows(_ ids: [UInt32], monitor: MonitorInfo = mainMonitorInfo) -> [TestWindow] {
    let windows = ids.reversed().map { TestWindow.new(id: $0, monitor: monitor) }
    check(monitor.state.clients.map(\.windowId) == ids)
    return windows.reversed()
}

/// The rects the tiling layout gives the monitor's windows, in client order
@MainActor
func arrangedRects(_ monitor: MonitorInfo = mainMonitorInfo) async throws -> [UInt32: Rect] {
    try await arrangeMonitors()
    var result: [UInt32: Rect] = [:]
    for window in monitor.state.clients {
        if let rect = window.lastAppliedRect { result[window.windowId] = rect }
    }
    return result
}

extension ParsedCmd {
    var errorOrNil: String? {
        return switch self {
            case .failure(let e): e.msg
            case .cmd, .help: nil
        }
    }

    var cmdOrDie: T { cmdOrNil ?? dieT("\(self)") }
}

func testParseCommandFail(_ command: String, msg expectedMsg: String, exitCode expectedExitCode: Int32, file: StaticString = #filePath, line: UInt = #line) {
    let parsed = parseCommand(command)
    switch parsed {
        case .cmd(let command): XCTFail("\(command) isn't supposed to be parcelable")
        case .help: die() // todo test help
        case .failure(let failure):
            assertEquals(failure, .init(expectedMsg, expectedExitCode), file: file, line: line)
    }
}

extension HotkeyBinding {
    init(_ modifiers: NSEvent.ModifierFlags, _ keyCode: Key, _ commands: Shell<any Command>) {
        let descriptionWithKeyNotation = modifiers.isEmpty
            ? keyCode.toString()
            : modifiers.toString() + "-" + keyCode.toString()
        self.init(modifiers, keyCode, commands, descriptionWithKeyNotation: descriptionWithKeyNotation)
    }
}

extension FocusCommand {
    static func new(direction: CardinalDirection) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], direction: .cardinal(direction)))
    }

    static func new(stack: NextPrev) -> FocusCommand {
        FocusCommand(args: FocusCmdArgs(rawArgs: [], direction: .stack(stack)))
    }
}

extension Rect: Equatable {
    public static func == (lhs: Rect, rhs: Rect) -> Bool {
        lhs.topLeftX == rhs.topLeftX && lhs.topLeftY == rhs.topLeftY &&
            lhs.width == rhs.width && lhs.height == rhs.height
    }
}

func parseCommand(_ raw: String) -> ParsedCmd<Shell<any Command>> { parseCommand(raw, allowExecAndForget: true, allowEval: true) }
