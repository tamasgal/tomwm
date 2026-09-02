import Common

/// macOS can put a window into a state tomwm must not manage: native fullscreen, minimized, or
/// belonging to an application hidden with cmd-h. There is no notification for all of these, so the
/// state is polled once per refresh session.
@MainActor
func normalizeMacosState() async throws {
    for window in Window.all {
        let isMacosFullscreen = try await window.isMacosFullscreen(.cancellable)
        let isMacosMinimized = try await (!isMacosFullscreen).andAsync { @MainActor @Sendable in try await window.isMacosMinimized(.cancellable) }
        let isWindowOfHiddenApp = !isMacosFullscreen && !isMacosMinimized &&
            !config.automaticallyUnhideMacosHiddenApps && window.macAppUnsafe.nsApp.isHidden
        window.macosState = switch true {
            case isMacosFullscreen: .nativeFullscreen
            case isMacosMinimized: .minimized
            case isWindowOfHiddenApp: .hiddenApp
            default: .normal
        }
    }
    try await validateIgnoredWindows()
}

/// A window that looked like a popup at registration time may turn out to be a real window later
/// (a minimized or fullscreened window reports itself very differently). Give every ignored window
/// another chance on each refresh.
@MainActor
private func validateIgnoredWindows() async throws {
    for (windowId, macApp) in MacWindow.ignoredWindows {
        let windowLevel = getWindowLevel(for: windowId)
        if try await macApp.isWindowHeuristic(windowId, windowLevel, .cancellable) {
            MacWindow.ignoredWindows.removeValue(forKey: windowId)
            // getOrRegister runs the on-window-detected callbacks itself
            _ = try await MacWindow.getOrRegister(windowId: windowId, macApp: macApp)
        }
    }
}
