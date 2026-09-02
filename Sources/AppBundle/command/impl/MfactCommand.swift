import AppKit
import Common

/// dwm's setmfact. The value is clamped rather than rejected, so a binding held down stops at the
/// edge instead of doing nothing.
struct MfactCommand: Command {
    let args: MfactCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let state = target.monitorState
        let requested = min(max(args.value.val.apply(to: state.mfact), minMfact), maxMfact)
        state.mfact = (requested * 10000).rounded() / 10000
        return .succ
    }
}

let minMfact = 0.05
let maxMfact = 0.95
