import AppKit
import Common

/// dwm's incnmaster
struct NmasterCommand: Command {
    let args: NmasterCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let state = target.monitorState
        state.nmaster = max(args.value.val.apply(to: state.nmaster), 0)
        return .succ
    }
}
