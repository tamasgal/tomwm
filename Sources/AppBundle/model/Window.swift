import AppKit
import Common

/// How macOS itself is currently treating the window. tomwm does not manage windows that are in
/// any state other than `.normal`.
enum MacosWindowState: Equatable, Sendable {
    case normal
    case nativeFullscreen
    case minimized
    /// The window belongs to an application hidden with cmd-h
    case hiddenApp
}

open class Window: Hashable {
    let windowId: UInt32
    let app: any AbstractApp

    /// The tags the window carries. Never empty for a managed window.
    var tags: TagMask
    /// Top left corner of the monitor that owns the window. See ``MonitorState``.
    var monitorPoint: CGPoint

    /// dwm's `isfixed`. A dialog is managed floating whatever the layout, and can never be tiled.
    let isDialog: Bool
    private var _isFloating: Bool
    /// dwm's `isfloating`. Always true for dialogs.
    var isFloating: Bool {
        get { isDialog || _isFloating }
        set { _isFloating = newValue }
    }

    /// The size to restore the window to when it stops being tiled
    var floatingSize: CGSize?
    /// tomwm's own fullscreen, which is not macOS native fullscreen
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var macosState: MacosWindowState = .normal
    /// The rect the last arrange pass gave the window
    var lastAppliedRect: Rect? = nil

    @MainActor
    init(id: UInt32, _ app: any AbstractApp, tags: TagMask, monitorPoint: CGPoint, isDialog: Bool, floatingSize: CGSize?) {
        self.windowId = id
        self.app = app
        self.tags = tags
        self.monitorPoint = monitorPoint
        self.isDialog = isDialog
        self._isFloating = isDialog
        self.floatingSize = floatingSize
    }

    @MainActor static func get(byId windowId: UInt32) -> Window? {
        isUnitTest
            ? allTestWindows[windowId]
            : MacWindow.allWindowsMap[windowId]
    }

    /// Every window tomwm manages, in no particular order
    @MainActor static var all: [Window] {
        isUnitTest ? Array(allTestWindows.values) : MacWindow.allWindows
    }

    @MainActor
    func closeAxWindow() { die("Not implemented") }

    public func hash(into hasher: inout Hasher) { hasher.combine(windowId) }
    public static func == (lhs: Window, rhs: Window) -> Bool { lhs === rhs }

    func getAxSize(_ cm: CancellationMode) async throws -> CGSize? { die("Not implemented") }
    func getTitle(_ cm: CancellationMode) async throws -> String { die("Not implemented") }
    func isMacosFullscreen(_ cm: CancellationMode) async throws -> Bool { false }
    func isMacosMinimized(_ cm: CancellationMode) async throws -> Bool { false }
    var isHiddenInCorner: Bool { die("Not implemented") }
    @MainActor func nativeFocus() { die("Not implemented") }
    func getAxRect(_ cm: CancellationMode) async throws -> Rect? { die("Not implemented") }
    func getCenter(_ cm: CancellationMode) async throws -> CGPoint? { try await getAxRect(cm)?.center }

    func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) { die("Not implemented") }
    @MainActor func hideInCorner(_ corner: OptimalHideCorner, on monitor: MonitorInfo) async throws { die("Not implemented") }
    @MainActor func unhideFromCorner(on monitor: MonitorInfo) { die("Not implemented") }
}

/// The registry the test harness uses in place of ``MacWindow/allWindowsMap``
@MainActor var allTestWindows: [UInt32: Window] = [:]

extension Window {
    /// The monitor that arranges this window
    @MainActor var monitor: MonitorInfo { monitorInfo(at: monitorPoint) }
    @MainActor var monitorState: MonitorState { monitorStateFor(monitorPoint) }

    /// dwm's ISVISIBLE: the window carries a tag its monitor is currently showing
    @MainActor var isVisible: Bool { macosState == .normal && tags.intersects(monitorState.tagset) }

    /// dwm's nexttiled: visible and not floating
    @MainActor var isTiled: Bool { isVisible && !isFloating }

    func asMacWindow() -> MacWindow { self as! MacWindow }
}
