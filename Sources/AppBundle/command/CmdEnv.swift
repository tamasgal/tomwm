import Common

struct CmdEnv {
    var windowId: UInt32? = nil
    /// 1-based monitor id
    var monitorId: Int? = nil
    var tags: [String] = []

    static let defaultEnv: CmdEnv = .init()

    @MainActor
    consuming func withFocus(_ focus: LiveFocus) -> Self {
        self.tags = focus.monitorState.tagset.tagNames
        return switch focus.asLeaf {
            case .window(let window): withWindowId(window.windowId)
            case .emptyMonitor: withMonitorId(focus.monitor.monitorId_oneBased ?? 1)
        }
    }

    consuming func withWindowId(_ windowId: UInt32) -> CmdEnv {
        self.windowId = windowId
        self.monitorId = nil
        return self
    }

    consuming func withMonitorId(_ monitorId: Int) -> CmdEnv {
        self.windowId = nil
        self.monitorId = monitorId
        return self
    }

    var asMap: [String: String] {
        var result = [String: String]()
        if let windowId {
            result[TOMWM_WINDOW_ID] = windowId.description
        }
        if let monitorId {
            result[TOMWM_MONITOR] = monitorId.description
        }
        if !tags.isEmpty {
            result[TOMWM_TAGS] = tags.joined(separator: ",")
        }
        return result
    }
}
