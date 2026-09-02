import AppKit
import Common

/// dwm's tag and toggletag
struct TagCommand: Command {
    let args: TagCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }

        let requested: TagMask
        if args.all {
            requested = .allConfigured
        } else {
            guard let mask = resolveTagsOrReportError(names: args.tags, indices: args.indices, io) else { return .fail }
            requested = args.toggle ? window.tags.symmetricDifference(mask) : mask
        }
        if requested.isEmpty {
            return .fail(io.err("A window must carry at least one tag"))
        }
        window.tags = requested

        let state = window.monitorState
        setFocus(to: LiveFocus(windowOrNil: state.mruVisibleClient, monitorPoint: window.monitorPoint))
        return .succ
    }
}
