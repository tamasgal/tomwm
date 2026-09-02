import AppKit
import Common

/// dwm's togglefloating. A dialog is dwm's `isfixed`: it can never be tiled.
struct FloatingCommand: Command {
    let args: FloatingCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }

        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !window.isFloating
        }
        if window.isDialog && !newState {
            return .fail(io.err("Window \(window.windowId) is a dialog. Dialogs are always managed floating"))
        }
        if newState == window.isFloating {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    let msg = newState
                        ? "Already floating. Tip: use --fail-if-noop to exit with non-zero code"
                        : "Already tiled. Tip: use --fail-if-noop to exit with non-zero code"
                    return .succ(io.err(msg))
            }
        }
        if newState {
            // Remember the tiled size so unfloating and refloating does not lose it
            window.floatingSize = (try? await window.getAxSize(.nonCancellable)) ?? window.floatingSize
        }
        window.isFloating = newState
        if newState, let size = window.floatingSize {
            window.setAxFrame(nil, size)
        }
        return .succ
    }
}
