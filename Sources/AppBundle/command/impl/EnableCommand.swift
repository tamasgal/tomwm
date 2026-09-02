import AppKit
import Common

struct EnableCommand: Command {
    let args: EnableCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        let prevState = TrayMenuModel.shared.isEnabled
        let newState: Bool = switch args.targetState.val {
            case .on: true
            case .off: false
            case .toggle: !TrayMenuModel.shared.isEnabled
        }
        if newState == prevState {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    let msg = newState
                        ? "Already enabled. Tip: use --fail-if-noop to exit with non-zero code"
                        : "Already disabled. Tip: use --fail-if-noop to exit with non-zero code"
                    return .succ(io.err(msg))
            }
        }

        TrayMenuModel.shared.isEnabled = newState
        if newState {
            for window in Window.all where window.isFloating {
                window.floatingSize = (try? await window.getAxSize(.nonCancellable)) ?? window.floatingSize
            }
            await activateMode_nonCancellable(mainModeId)
        } else {
            await activateMode_nonCancellable(nil)
        }
        return .succ
    }
}
