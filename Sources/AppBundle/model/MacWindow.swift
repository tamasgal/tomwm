import AppKit
import Common

final class MacWindow: Window {
    let macApp: MacApp
    private var prevUnhiddenProportionalPositionInsideMonitorRect: CGPoint?

    @MainActor
    private init(_ id: UInt32, _ app: MacApp, tags: TagMask, monitorPoint: CGPoint, isDialog: Bool, floatingSize: CGSize?) {
        self.macApp = app
        super.init(id: id, app, tags: tags, monitorPoint: monitorPoint, isDialog: isDialog, floatingSize: floatingSize)
    }

    @MainActor static var allWindowsMap: [UInt32: MacWindow] = [:]
    @MainActor static var allWindows: [MacWindow] { Array(allWindowsMap.values) }

    /// Window ids that look like windows to the Accessibility API but are not windows to a human.
    /// They are re-validated on every refresh, so a misdetection is recoverable.
    @MainActor static var ignoredWindows: [UInt32: MacApp] = [:]

    @MainActor
    @discardableResult
    static func getOrRegister(windowId: UInt32, macApp: MacApp) async throws -> MacWindow? {
        if let existing = allWindowsMap[windowId] { return existing }
        if ignoredWindows[windowId] != nil { return nil }
        let rect = try await macApp.getAxRect(windowId, .cancellable)
        let windowLevel = getWindowLevel(for: windowId)
        let type = try await macApp.getAxUiElementWindowType(windowId, windowLevel, .cancellable)
        // The monitor the window is born on: where it actually is at startup, where the user is
        // looking otherwise.
        let monitorPoint = (isStartup
            ? (rect?.center.monitorApproximation ?? mainMonitorInfo).rect.topLeftCorner
            : focus.monitorPoint)

        // atomic synchronous section
        if let existing = allWindowsMap[windowId] { return existing }
        if type == .popup {
            ignoredWindows[windowId] = macApp
            return nil
        }
        let state = monitorStateFor(monitorPoint)
        let window = MacWindow(
            windowId,
            macApp,
            // dwm's applyrules default: a new window carries the tags its monitor is showing
            tags: state.tagset,
            monitorPoint: monitorPoint,
            isDialog: type == .dialog,
            floatingSize: rect?.size,
        )
        allWindowsMap[windowId] = window
        state.attach(window)

        try await debugWindowsIfRecording(window, .cancellable)
        if try await !restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window) {
            await tryOnWindowDetected(window)
        }
        return window
    }

    func isWindowHeuristic(_ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool {
        try await macApp.isWindowHeuristic(windowId, windowLevel, cm)
    }

    func isDialogHeuristic(_ windowLevel: MacOsWindowLevel?, _ cm: CancellationMode) async throws -> Bool {
        try await macApp.isDialogHeuristic(windowId, windowLevel, cm)
    }

    func dumpAxInfo(_ cm: CancellationMode) async throws -> [String: Json] {
        try await macApp.dumpWindowAxInfo(windowId: windowId, cm)
    }

    func setNativeFullscreen(_ value: Bool) { macApp.setNativeFullscreen(windowId, value) }
    func setNativeMinimized(_ value: Bool) { macApp.setNativeMinimized(windowId, value) }

    // skipClosedWindowsCache is an optimization when it's definitely not necessary to cache the
    // closed window. If you are unsure, it's better to pass `false`
    @MainActor
    func garbageCollect(skipClosedWindowsCache: Bool) {
        if MacWindow.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        if !skipClosedWindowsCache { cacheClosedWindowIfNeeded() }
        let state = monitorStateFor(monitorPoint)
        let wasVisible = macosState == .normal && tags.intersects(state.tagset)
        state.detach(self)

        let focus = focus
        let wasOnFocusedMonitor = monitorPoint == focus.monitorPoint ||
            (monitorPoint == prevFocusedMonitorPoint && prevFocusedMonitorDate.distance(to: .now) < 1)
        // Don't steal focus back when a minimized window or a popup goes away
        if wasVisible && wasOnFocusedMonitor && macosState == .normal {
            let heir = LiveFocus(windowOrNil: state.mruVisibleClient, monitorPoint: monitorPoint)
            setFocus(to: heir)
            // Guard against the "Apple Reminders popup" bug
            if focus.windowOrNil?.app.pid != app.pid {
                // Force focus to fix the macOS annoyance with focused apps without windows
                heir.windowOrNil?.nativeFocus()
            }
        }
    }

    override func getTitle(_ cm: CancellationMode) async throws -> String { try await macApp.getAxTitle(windowId, cm) ?? "" }
    override func isMacosFullscreen(_ cm: CancellationMode) async throws -> Bool { try await macApp.isMacosNativeFullscreen(windowId, cm) == true }
    override func isMacosMinimized(_ cm: CancellationMode) async throws -> Bool { try await macApp.isMacosNativeMinimized(windowId, cm) == true }

    @MainActor override func nativeFocus() { macApp.nativeFocus(windowId) }

    override func closeAxWindow() {
        garbageCollect(skipClosedWindowsCache: true)
        macApp.closeAndUnregisterAxWindow(windowId)
    }

    @MainActor
    override func hideInCorner(_ corner: OptimalHideCorner, on monitor: MonitorInfo) async throws {
        // Don't accidentally override the remembered position on subsequent hideInCorner calls
        if !isHiddenInCorner {
            guard let windowRect = try await getAxRect(.cancellable) else { return }
            // Check isHiddenInCorner a second time because of the suspension point above
            if !isHiddenInCorner {
                let monitorRect = windowRect.center.monitorApproximation.rect // Non idempotent, like the floating re-anchor
                let absolutePoint = windowRect.topLeftCorner - monitorRect.topLeftCorner
                prevUnhiddenProportionalPositionInsideMonitorRect =
                    CGPoint(x: absolutePoint.x / monitorRect.width, y: absolutePoint.y / monitorRect.height)
                floatingSize = windowRect.size
            }
        }
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                guard let s = try await getAxSize(.cancellable) else { fallthrough }
                // Zoom jumps off screen if you do the one pixel offset
                let onePixelOffset = macApp.appId == .zoom ? .zero : CGPoint(x: 1, y: -1)
                p = monitor.visibleRect.bottomLeftCorner + onePixelOffset + CGPoint(x: -s.width, y: 0)
            case .bottomRightCorner:
                let onePixelOffset = macApp.appId == .zoom ? .zero : CGPoint(x: 1, y: 1)
                p = monitor.visibleRect.bottomRightCorner - onePixelOffset
        }
        setAxFrame(p, nil)
    }

    @MainActor
    override func unhideFromCorner(on monitor: MonitorInfo) {
        guard let prev = prevUnhiddenProportionalPositionInsideMonitorRect else { return }
        // A window that the arrange pass will position anyway needs no restore. Everything else,
        // floating windows and every window under the floating layout, has to be put back by hand.
        if isFloating || monitorStateFor(monitor.rect.topLeftCorner).layout == .floating {
            let monitorRect = monitor.rect
            var newX = monitorRect.topLeftX + monitorRect.width * prev.x
            var newY = monitorRect.topLeftY + monitorRect.height * prev.y
            let windowWidth = floatingSize?.width ?? 0
            let windowHeight = floatingSize?.height ?? 0
            newX = newX.coerce(in: monitorRect.minX ... max(monitorRect.minX, monitorRect.maxX - windowWidth))
            newY = newY.coerce(in: monitorRect.minY ... max(monitorRect.minY, monitorRect.maxY - windowHeight))
            setAxFrame(CGPoint(x: newX, y: newY), floatingSize)
        }
        prevUnhiddenProportionalPositionInsideMonitorRect = nil
    }

    override var isHiddenInCorner: Bool { prevUnhiddenProportionalPositionInsideMonitorRect != nil }

    override func getAxSize(_ cm: CancellationMode) async throws -> CGSize? { try await macApp.getAxSize(windowId, cm) }
    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { macApp.setAxFrame(windowId, topLeft, size) }
    override func getAxRect(_ cm: CancellationMode) async throws -> Rect? { try await macApp.getAxRect(windowId, cm) }
}

@MainActor
func tryOnWindowDetected(_ window: Window) async {
    _ = await onWindowDetected(.defaultEnv, CmdIoImpl.emptyStdinIgnoringOut, window)
}

@MainActor
func onWindowDetected(_ env: CmdEnv, _ io: CmdIo, _ window: Window) async -> Int32ExitCode {
    broadcastEvent(.windowDetected(
        windowId: window.windowId,
        tags: window.tags.tagNames,
        appBundleId: window.app.rawAppBundleId,
        appName: window.app.name,
    ))
    var lastExitCode = Int32ExitCode.succ
    for callback in config.onWindowDetected where await callback.matches(window) {
        lastExitCode = await callback.run.run(env.withWindowId(window.windowId), io)
        if !callback.checkFurtherCallbacks {
            return lastExitCode
        }
    }
    return lastExitCode
}

extension WindowDetectedCallback {
    @MainActor
    func matches(_ window: Window) async -> Bool {
        switch self.matcher {
            case .legacy(let matcher):
                if let startupMatcher = matcher.duringTomWmStartup, startupMatcher != isStartup {
                    return false
                }
                if let regex = matcher.windowTitleRegexSubstring, (try? await window.getTitle(.nonCancellable))?.contains(caseInsensitiveRegex: regex) != true {
                    return false
                }
                if let appId = matcher.appId, appId != window.app.rawAppBundleId {
                    return false
                }
                if let regex = matcher.appNameRegexSubstring, !(window.app.name ?? "").contains(caseInsensitiveRegex: regex) {
                    return false
                }
                if let tag = matcher.tag {
                    guard let mask = TagMask.named(tag), window.tags.intersects(mask) else { return false }
                }
                return true
            case .command(let command):
                return await command.run(.defaultEnv.withWindowId(window.windowId), .emptyStdin).exitCode.rawValue == 0
        }
    }
}
