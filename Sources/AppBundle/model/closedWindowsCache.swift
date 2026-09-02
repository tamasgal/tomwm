import AppKit
import Common

/// First line of defence against the lock screen.
///
/// When you lock the screen, the whole Accessibility API becomes unobservable (all attributes
/// become empty, window ids become nil), which tricks tomwm into thinking every window was closed.
/// So every time a window dies tomwm caches the "entire world" (unless the window is already in the
/// cache) and restores it when the windows reappear.
@MainActor private var closedWindowsCache = FrozenWorld(windows: [], monitors: [], windowIds: [])

struct FrozenWorld: Sendable {
    let windows: [FrozenWindow]
    let monitors: [FrozenMonitor]
    let windowIds: Set<UInt32>
}

struct FrozenWindow: Sendable {
    let id: UInt32
    let tags: TagMask
    let isFloating: Bool
    let monitorPoint: CGPoint
    /// Position in the monitor's client list, which is the tiling order
    let index: Int
}

struct FrozenMonitor: Sendable {
    let topLeftCorner: CGPoint
    let tagset: TagMask
    let prevTagset: TagMask
    let layout: TomLayout
    let nmaster: Int
    let mfact: Double
}

@MainActor func cacheClosedWindowIfNeeded() {
    let allWindowIds = Window.all.map(\.windowId).toSet()
    if allWindowIds.isSubset(of: closedWindowsCache.windowIds) {
        return // already cached
    }
    var windows: [FrozenWindow] = []
    var monitors: [FrozenMonitor] = []
    for (point, state) in monitorStates {
        monitors.append(FrozenMonitor(
            topLeftCorner: point,
            tagset: state.tagset,
            prevTagset: state.prevTagset,
            layout: state.layout,
            nmaster: state.nmaster,
            mfact: state.mfact,
        ))
        for (index, client) in state.clients.enumerated() {
            windows.append(FrozenWindow(
                id: client.windowId,
                tags: client.tags,
                isFloating: client.isFloating,
                monitorPoint: point,
                index: index,
            ))
        }
    }
    closedWindowsCache = FrozenWorld(windows: windows, monitors: monitors, windowIds: allWindowIds)
}

@MainActor func restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: Window) async throws -> Bool {
    guard let frozen = closedWindowsCache.windows.first(where: { $0.id == newlyDetectedWindow.windowId }) else {
        return false
    }
    for frozenMonitor in closedWindowsCache.monitors {
        let point = resolvedMonitorPoint(frozenMonitor.topLeftCorner)
        let state = monitorStateFor(point)
        state.tagset = frozenMonitor.tagset
        state.prevTagset = frozenMonitor.prevTagset
        state.layout = frozenMonitor.layout
        state.nmaster = frozenMonitor.nmaster
        state.mfact = frozenMonitor.mfact
    }

    let point = resolvedMonitorPoint(frozen.monitorPoint)
    let state = monitorStateFor(point)
    monitorStateFor(newlyDetectedWindow.monitorPoint).detach(newlyDetectedWindow)
    newlyDetectedWindow.monitorPoint = point
    newlyDetectedWindow.tags = frozen.tags
    newlyDetectedWindow.isFloating = frozen.isFloating
    // Put the window back where it was in the tiling order. Windows come back one at a time, so
    // the recorded index can be past the end while the rest are still missing.
    state.clients.insert(newlyDetectedWindow, at: min(frozen.index, state.clients.count))
    state.focusStack.pushOrRaise(newlyDetectedWindow)
    return true
}

// Consider the following case:
// 1. Close a window
// 2. The previous step caches the whole world
// 3. Change something in the layout
// 4. Lock the screen
// 5. The cache is not updated because all alive windows are already cached
// 6. Unlock the screen
// 7. The wrong cache is used
//
// That's why the cache is reset every time the layout changes. The layout can only be changed by
// running commands and by mouse manipulations.
@MainActor func resetClosedWindowsCache() {
    closedWindowsCache = FrozenWorld(windows: [], monitors: [], windowIds: [])
}
