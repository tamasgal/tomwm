import AppKit
import Common

struct MoveToMonitorCommand: Command {
    let args: MoveToMonitorCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = true

    func run(_ env: CmdEnv, _ io: CmdIo) -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else { return .fail(io.err(noWindowIsFocused)) }
        let currentMonitor = window.monitor

        switch args.target.val.resolve(currentMonitor, wrapAround: args.wrapAround) {
            case .success(let targetMonitor):
                let targetPoint = targetMonitor.rect.topLeftCorner
                if targetPoint == window.monitorPoint {
                    return args.failIfNoop ? .fail : .succ(io.err("The window is already on that monitor"))
                }
                moveWindowToMonitor(window, targetPoint, focusFollowsWindow: args.focusFollowsWindow)
                return .succ
            case .failure(let msg):
                return .fail(io.err(msg))
        }
    }
}

/// dwm's sendmon: the window is re-tagged with the destination monitor's current tags, so it cannot
/// end up somewhere nobody is looking.
@MainActor
func moveWindowToMonitor(_ window: Window, _ targetPoint: CGPoint, focusFollowsWindow: Bool) {
    let sourcePoint = window.monitorPoint
    let source = monitorStateFor(sourcePoint)
    let destination = monitorStateFor(targetPoint)
    source.detach(window)
    window.monitorPoint = targetPoint
    window.tags = destination.tagset
    destination.attach(window)
    if focusFollowsWindow {
        _ = window.focusWindow()
    } else {
        setFocus(to: LiveFocus(windowOrNil: source.mruVisibleClient, monitorPoint: sourcePoint))
    }
}
