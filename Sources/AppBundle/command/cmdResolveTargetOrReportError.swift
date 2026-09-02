import Common

extension CmdArgs {
    /// The monitor the command acts on, when it was named explicitly
    @MainActor
    var targetMonitor: MonitorInfo? {
        guard let monitorId else { return nil }
        return sortedMonitorInfos.getOrNil(atIndex: monitorId - 1)
    }

    /// Precedence: --window-id, then --monitor, then the TOMWM_WINDOW_ID and TOMWM_MONITOR env
    /// variables, then the real focus.
    @MainActor
    func resolveTargetOrReportError(_ env: CmdEnv, _ io: CmdIo) -> LiveFocus? {
        // Flags
        if let windowId {
            if let window = Window.get(byId: windowId) {
                return window.toLiveFocus()
            } else {
                io.err("Invalid <window-id> \(windowId) passed to --window-id")
                return nil
            }
        }
        if let monitorId {
            guard let monitor = targetMonitor else {
                io.err("Invalid <monitor-id> \(monitorId) passed to --monitor")
                return nil
            }
            return monitor.toLiveFocus()
        }
        // Env
        if let windowId = env.windowId {
            if let window = Window.get(byId: windowId) {
                return window.toLiveFocus()
            } else {
                io.err("Invalid <window-id> \(windowId) specified in \(TOMWM_WINDOW_ID) env variable")
                return nil
            }
        }
        if let monitorId = env.monitorId {
            guard let monitor = sortedMonitorInfos.getOrNil(atIndex: monitorId - 1) else {
                io.err("Invalid <monitor-id> \(monitorId) specified in \(TOMWM_MONITOR) env variable")
                return nil
            }
            return monitor.toLiveFocus()
        }
        // Real focus
        return focus
    }
}

extension Window {
    @MainActor
    func toLiveFocus() -> LiveFocus {
        LiveFocus(windowOrNil: self, monitorPoint: resolvedMonitorPoint(monitorPoint))
    }
}

extension MonitorInfo {
    @MainActor
    func toLiveFocus() -> LiveFocus {
        let point = rect.topLeftCorner
        return LiveFocus(windowOrNil: monitorStateFor(point).mruVisibleClient, monitorPoint: point)
    }
}
