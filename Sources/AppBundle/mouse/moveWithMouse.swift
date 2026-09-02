import AppKit
import Common

@MainActor
private var moveWithMouseTask: Task<(), any Error>? = nil

func movedObs(_: AXObserver, ax: AXUIElement, notif: CFString, _: UnsafeMutableRawPointer?) {
    let windowId = ax.containingWindowId()
    let notif = notif as String
    Task.startUnstructured { @MainActor in
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        guard let windowId, let window = Window.get(byId: windowId), try await isManipulatedWithMouse(window) else {
            scheduleCancellableCompleteRefreshSession(.ax(notif))
            return
        }
        moveWithMouseTask?.cancel()
        moveWithMouseTask = Task.startUnstructured {
            try checkCancellation()
            try await runLightSession(.ax(notif), token) {
                try await moveWithMouse(window)
            }
        }
    }
}

@MainActor
private func moveWithMouse(_ window: Window) async throws {
    if window.macosState != .normal { return }
    resetClosedWindowsCache()
    if window.isFloating {
        try await moveFloatingWindow(window)
    } else {
        moveTiledWindow(window)
    }
}

/// A floating window follows the cursor. All that is left to do is hand it to the monitor it
/// landed on.
@MainActor
private func moveFloatingWindow(_ window: Window) async throws {
    guard let center = try await window.getCenter(.cancellable) else { return }
    let targetPoint = center.monitorApproximation.rect.topLeftCorner
    if targetPoint != window.monitorPoint {
        moveWindowToMonitor(window, targetPoint, focusFollowsWindow: false)
    }
}

/// Dragging a tiled window swaps it with the tiled window under the cursor, or hands it to the
/// monitor the cursor is on.
@MainActor
private func moveTiledWindow(_ window: Window) {
    currentlyManipulatedWithMouseWindowId = window.windowId
    window.lastAppliedRect = nil
    let mouse = mouseLocation
    let targetPoint = mouse.monitorApproximation.rect.topLeftCorner

    if targetPoint != window.monitorPoint {
        moveWindowToMonitor(window, targetPoint, focusFollowsWindow: false)
        return
    }
    let state = monitorStateFor(targetPoint)
    guard let swapTarget = state.tiledClients.first(where: { $0 != window && $0.lastAppliedRect?.contains(mouse) == true })
    else { return }
    swapWindows(window, swapTarget)
}

@MainActor
func swapWindows(_ window1: Window, _ window2: Window) {
    if window1 == window2 { return }
    let state = window1.monitorState
    guard state === window2.monitorState,
          let index1 = state.clients.firstIndex(of: window1),
          let index2 = state.clients.firstIndex(of: window2)
    else { return }
    state.clients.swapAt(index1, index2)
}
