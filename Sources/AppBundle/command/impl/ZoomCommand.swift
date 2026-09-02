import AppKit
import Common

/// dwm's zoom: move the focused window to the master area. If it is already the master, swap it
/// with the next tiled window, so pressing the binding twice takes you back.
struct ZoomCommand: Command {
    let args: ZoomCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        let state = window.monitorState
        if state.layout == .floating {
            return .succ(io.err("zoom does nothing under the floating layout"))
        }
        if window.isFloating {
            return .succ(io.err("zoom does nothing for a floating window"))
        }
        let tiled = state.tiledClients
        guard let master = tiled.first else { return .succ }

        let promoted: Window
        if window == master {
            guard let next = tiled.getOrNil(atIndex: 1) else {
                return .succ(io.err("The window is already the only master"))
            }
            promoted = next
        } else {
            promoted = window
        }
        state.promoteToMaster(promoted)
        _ = promoted.focusWindow()
        return .succ
    }
}
