import AppKit
import Common

struct CloseAllWindowsButCurrentCommand: Command {
    let args: CloseAllWindowsButCurrentCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let focused = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        var result = BinaryExitCode.succ
        for window in focused.monitorState.visibleClients where window != focused {
            result = await CloseCommand(args: args.closeArgs).run(env.withWindowId(window.windowId), io).and(result)
        }
        return result
    }
}
