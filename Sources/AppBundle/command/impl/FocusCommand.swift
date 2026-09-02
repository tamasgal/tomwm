import AppKit
import Common

struct FocusCommand: Command {
    let args: FocusCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        // --window-id resolves the target to that very window, so focusing the target is the job
        guard let direction = args.direction else {
            guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
            return window.focusWindow() ? .succ : .fail
        }

        let result: Window? = switch direction {
            case .stack(let nextPrev): stackNeighbour(target, nextPrev)
            case .cardinal(let cardinal): cardinalNeighbour(target, cardinal)
        }
        guard let result else {
            return args.failIfNoop ? .fail : .succ(io.err("No window to focus"))
        }
        return result.focusWindow() ? .succ : .fail
    }

    /// dwm's focusstack: walk the client list, skipping invisible windows, wrapping around
    @MainActor
    private func stackNeighbour(_ target: LiveFocus, _ nextPrev: NextPrev) -> Window? {
        let state = target.monitorState
        let candidates = state.visibleClients.filter { args.includeFloating || !$0.isFloating }
        guard !candidates.isEmpty else { return nil }
        guard let current = target.windowOrNil, let index = candidates.firstIndex(of: current) else {
            return candidates.first
        }
        let step = nextPrev == .next ? 1 : -1
        let next = (index + step + candidates.count) % candidates.count
        return candidates[next] != current ? candidates[next] : nil
    }

    /// Pick the nearest visible window in the given direction, by the rect the last arrange applied
    @MainActor
    private func cardinalNeighbour(_ target: LiveFocus, _ direction: CardinalDirection) -> Window? {
        let monitors: [MonitorInfo] = switch args.boundaries {
            case .monitor: [target.monitor]
            case .allMonitors: monitorInfos
        }
        let candidates = monitors
            .flatMap { $0.state.visibleClients }
            .filter { args.includeFloating || !$0.isFloating }
            .filter { $0 != target.windowOrNil }

        guard let origin = target.windowOrNil?.lastAppliedRect ?? target.monitor.visibleRect.takeIf({ _ in true }) else {
            return nil
        }
        let from = origin.center
        var best: (window: Window, score: CGFloat)? = nil
        for candidate in candidates {
            guard let rect = candidate.lastAppliedRect else { continue }
            let to = rect.center
            let along: CGFloat
            let across: CGFloat
            switch direction {
                case .left: along = from.x - to.x; across = abs(from.y - to.y)
                case .right: along = to.x - from.x; across = abs(from.y - to.y)
                case .up: along = from.y - to.y; across = abs(from.x - to.x)
                case .down: along = to.y - from.y; across = abs(from.x - to.x)
            }
            if along <= 0 { continue }
            // Prefer windows that are close along the axis and well aligned across it
            let score = along + 2 * across
            if best == nil || score < best.orDie().score {
                best = (candidate, score)
            }
        }
        return best?.window
    }
}

let noWindowIsFocused = "No window is focused"
