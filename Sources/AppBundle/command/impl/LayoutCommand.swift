import AppKit
import Common

/// dwm's setlayout. With several layouts it behaves like the cyclelayouts patch: the first one that
/// is not the current layout wins.
struct LayoutCommand: Command {
    let args: LayoutCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let state = target.monitorState

        let requested: TomLayout = if args.toggleWithPrevious {
            state.prevLayout
        } else {
            args.toggleBetween.first { $0 != state.layout } ?? args.toggleBetween.first.orDie()
        }

        if requested == state.layout {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    let msg = "Already in the \(requested.rawValue) layout. " +
                        "Tip: use --fail-if-noop to exit with non-zero exit code"
                    return .succ(io.err(msg))
            }
        }
        state.prevLayout = state.layout
        state.layout = requested
        return .succ
    }
}
