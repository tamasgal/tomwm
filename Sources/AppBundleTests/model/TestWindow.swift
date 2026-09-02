@testable import AppBundle
import AppKit
import Common

final class TestWindow: Window, CustomStringConvertible {
    var rect: Rect?
    var isMacosFullscreenForTest = false
    var isHiddenInCornerForTest = false

    @MainActor
    private init(_ id: UInt32, tags: TagMask, monitorPoint: CGPoint, isDialog: Bool, rect: Rect?) {
        self.rect = rect
        super.init(id: id, TestApp.shared, tags: tags, monitorPoint: monitorPoint, isDialog: isDialog, floatingSize: rect?.size)
    }

    /// Register a window the way ``MacWindow/getOrRegister`` does: it becomes the master of the
    /// monitor and carries the tags that monitor is showing.
    @discardableResult
    @MainActor
    static func new(
        id: UInt32,
        monitor: MonitorInfo = mainMonitorInfo,
        tags: TagMask? = nil,
        isDialog: Bool = false,
        rect: Rect? = nil,
    ) -> TestWindow {
        let point = monitor.rect.topLeftCorner
        let state = monitorStateFor(point)
        let window = TestWindow(id, tags: tags ?? state.tagset, monitorPoint: point, isDialog: isDialog, rect: rect)
        allTestWindows[id] = window
        TestApp.shared._windows.append(window)
        state.attach(window)
        return window
    }

    nonisolated var description: String { "TestWindow(\(windowId))" }

    @MainActor
    override func nativeFocus() {
        appForTests = TestApp.shared
        TestApp.shared.focusedWindow = self
    }

    @MainActor
    override func closeAxWindow() {
        allTestWindows.removeValue(forKey: windowId)
        TestApp.shared._windows.remove(element: self)
        if TestApp.shared.focusedWindow == self { TestApp.shared.focusedWindow = nil }
        monitorState.detach(self)
    }

    override func getTitle(_ cm: CancellationMode) async throws -> String { description }

    @MainActor override func getAxRect(_ cm: CancellationMode) async throws -> Rect? { rect }

    @MainActor override func getAxSize(_ cm: CancellationMode) async throws -> CGSize? {
        rect.map { CGSize(width: $0.width, height: $0.height) }
    }

    override func isMacosFullscreen(_ cm: CancellationMode) async throws -> Bool { isMacosFullscreenForTest }

    override func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        rect = Rect(
            topLeftX: topLeft?.x ?? rect?.topLeftX ?? 0,
            topLeftY: topLeft?.y ?? rect?.topLeftY ?? 0,
            width: size?.width ?? rect?.width ?? 0,
            height: size?.height ?? rect?.height ?? 0,
        )
    }

    override var isHiddenInCorner: Bool { isHiddenInCornerForTest }

    @MainActor override func hideInCorner(_ corner: OptimalHideCorner, on monitor: MonitorInfo) async throws {
        isHiddenInCornerForTest = true
    }

    @MainActor override func unhideFromCorner(on monitor: MonitorInfo) {
        isHiddenInCornerForTest = false
    }
}
