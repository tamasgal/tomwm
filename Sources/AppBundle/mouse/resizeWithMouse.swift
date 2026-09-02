import AppKit
import Common

@MainActor
private var resizeWithMouseTask: Task<(), any Error>? = nil

func resizedObs(_: AXObserver, ax: AXUIElement, notif: CFString, _: UnsafeMutableRawPointer?) {
    let notif = notif as String
    let windowId = ax.containingWindowId()
    Task.startUnstructured { @MainActor in
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        guard let windowId, let window = Window.get(byId: windowId), try await isManipulatedWithMouse(window) else {
            scheduleCancellableCompleteRefreshSession(.ax(notif))
            return
        }
        resizeWithMouseTask?.cancel()
        resizeWithMouseTask = Task.startUnstructured {
            try checkCancellation()
            try await runLightSession(.ax(notif), token) {
                try await resizeWithMouse(window)
            }
        }
    }
}

@MainActor
func resetManipulatedWithMouseIfPossible() async throws {
    if currentlyManipulatedWithMouseWindowId != nil {
        currentlyManipulatedWithMouseWindowId = nil
        scheduleCancellableCompleteRefreshSession(.resetManipulatedWithMouse, optimisticallyPreArrange: true)
    }
}

/// A tiled window's size belongs to the layout, so dragging its edge snaps back, as in dwm. Use
/// `mfact` and `nmaster` to resize the tiling. A floating window is free, and the size it is given
/// is remembered.
@MainActor
private func resizeWithMouse(_ window: Window) async throws {
    if window.macosState != .normal { return }
    resetClosedWindowsCache()
    guard window.isFloating else { return }
    window.floatingSize = try await window.getAxSize(.cancellable) ?? window.floatingSize
    currentlyManipulatedWithMouseWindowId = window.windowId
}
