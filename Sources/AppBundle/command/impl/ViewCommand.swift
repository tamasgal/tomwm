import AppKit
import Common

/// dwm's view and toggleview
struct ViewCommand: Command {
    let args: ViewCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        let state = target.monitorState

        let requested: TagMask
        switch true {
            case args.all:
                requested = .allConfigured
            case args.backAndForth || !args.hasTargets:
                // dwm's view with an empty mask: swap the two tag sets
                let prev = state.prevTagset.clampedToConfig
                if prev == state.tagset {
                    return .succ(io.err("Already showing the previous tags"))
                }
                requested = prev
            default:
                guard let mask = resolveTagsOrReportError(names: args.tags, indices: args.indices, io) else { return .fail }
                requested = args.toggle ? state.tagset.symmetricDifference(mask) : mask
        }

        if requested.isEmpty {
            return .fail(io.err("The view would become empty. At least one tag has to stay selected"))
        }
        if requested != state.tagset {
            state.prevTagset = state.tagset
            state.tagset = requested
        }
        // dwm calls focus(NULL) after every view change
        setFocus(to: LiveFocus(windowOrNil: state.mruVisibleClient, monitorPoint: target.monitorPoint))
        return .succ
    }
}

/// Tags can be named or addressed by their 1-based position in the `tags` config option. Bindings
/// use the position so that renaming a tag does not mean rewriting every binding that names it.
@MainActor
func resolveTagsOrReportError(names: [String], indices: [Int], _ io: CmdIo) -> TagMask? {
    var mask = TagMask.none
    for name in names {
        guard let tag = TagMask.named(name) else {
            io.err("Unknown tag '\(name)'. Known tags: \(config.tags.joined(separator: ", "))")
            return nil
        }
        mask.formUnion(tag)
    }
    for index in indices {
        guard index >= 1 && index <= config.tags.count else {
            io.err("Tag position \(index) is out of range. There are \(config.tags.count) tags")
            return nil
        }
        mask.formUnion(TagMask(index: index - 1))
    }
    return mask
}
