import AppKit
import Common

enum EffectiveLeaf {
    case window(Window)
    case emptyMonitor(CGPoint)
}
extension LiveFocus {
    var asLeaf: EffectiveLeaf {
        if let windowOrNil { .window(windowOrNil) } else { .emptyMonitor(monitorPoint) }
    }
}

/// This object should be only passed around but never memorized
struct LiveFocus: TomAny, Equatable {
    let windowOrNil: Window?
    /// Top left corner of the focused monitor. Always a live monitor.
    let monitorPoint: CGPoint

    @MainActor var monitor: MonitorInfo { monitorInfo(at: monitorPoint) }
    @MainActor var monitorState: MonitorState { monitorStateFor(monitorPoint) }

    @MainActor var frozen: FrozenFocus {
        FrozenFocus(windowId: windowOrNil?.windowId, monitorPoint: monitorPoint)
    }
}

/// "old", "captured", "frozen in time" Focus.
/// It's safe to keep a hard reference to this object. Unlike in LiveFocus, the information inside
/// isn't guaranteed to be self-consistent: the window-monitor relation could change since the
/// moment the object was created, and the monitor could be unplugged entirely.
struct FrozenFocus: TomAny, Equatable, Sendable {
    let windowId: UInt32?
    let monitorPoint: CGPoint

    @MainActor var live: LiveFocus {
        if let window = windowId.flatMap({ Window.get(byId: $0) }), window.isVisible {
            return LiveFocus(windowOrNil: window, monitorPoint: resolvedMonitorPoint(window.monitorPoint))
        }
        let point = resolvedMonitorPoint(monitorPoint)
        return LiveFocus(windowOrNil: monitorStateFor(point).mruVisibleClient, monitorPoint: point)
    }
}

/// There is no stable monitor identity on macOS, so instead of a stable key the resolution is made
/// total: a point that no longer names a live monitor resolves to the nearest one.
@MainActor
func resolvedMonitorPoint(_ point: CGPoint) -> CGPoint {
    monitorInfos.contains { $0.rect.topLeftCorner == point }
        ? point
        : point.monitorApproximation.rect.topLeftCorner
}

@MainActor private var _focus: FrozenFocus = FrozenFocus(windowId: nil, monitorPoint: mainMonitorInfo.rect.topLeftCorner)

/// Global focus.
/// Commands must be cautious about accessing this property directly. There are legitimate cases.
/// But, in general, commands must firstly check --window-id, --monitor, TOMWM_WINDOW_ID env and
/// TOMWM_MONITOR env before accessing the global focus.
@MainActor var focus: LiveFocus { _focus.live }

@MainActor
@discardableResult
func setFocus(to newFocus: LiveFocus) -> Bool {
    if _focus == newFocus.frozen { return true }
    _focus = newFocus.frozen
    if let window = newFocus.windowOrNil {
        monitorStateFor(window.monitorPoint).focusStack.pushOrRaise(window)
    }
    return true
}

extension Window {
    @MainActor func focusWindow() -> Bool {
        guard macosState == .normal else { return false }
        return setFocus(to: LiveFocus(windowOrNil: self, monitorPoint: resolvedMonitorPoint(monitorPoint)))
    }
}

extension MonitorInfo {
    @MainActor func focusMonitor() -> Bool {
        let point = rect.topLeftCorner
        return setFocus(to: LiveFocus(windowOrNil: monitorStateFor(point).mruVisibleClient, monitorPoint: point))
    }
}

@MainActor private var _lastKnownFocus: FrozenFocus = _focus

// Used by the focus recovery heuristic when a window dies
@MainActor var prevFocusedMonitorPoint: CGPoint? = nil {
    didSet { prevFocusedMonitorDate = .now }
}
@MainActor var prevFocusedMonitorDate: Date = .distantPast

// Used by focus-back-and-forth
@MainActor private var _prevFocus: FrozenFocus? = nil
@MainActor var prevFocus: LiveFocus? { _prevFocus?.live.takeIf { $0 != focus } }

@MainActor private var _lastKnownTagset: TagMask = .none

@MainActor private var onFocusChangedRecursionGuard = false
// Should be called in refreshSession
@MainActor func checkOnFocusChangedCallbacks_nonCancellable() async {
    if refreshSessionEvent?.isStartup == true { return }
    let focus = focus
    let frozenFocus = focus.frozen
    var hasFocusChanged = false
    var hasFocusedMonitorChanged = false
    if frozenFocus != _lastKnownFocus {
        _prevFocus = _lastKnownFocus
        hasFocusChanged = true
    }
    if frozenFocus.monitorPoint != _lastKnownFocus.monitorPoint {
        prevFocusedMonitorPoint = _lastKnownFocus.monitorPoint
        hasFocusedMonitorChanged = true
    }
    _lastKnownFocus = frozenFocus

    let tagset = focus.monitorState.tagset
    let hasTagsChanged = tagset != _lastKnownTagset
    let prevTagset = _lastKnownTagset
    _lastKnownTagset = tagset

    if onFocusChangedRecursionGuard { return }
    onFocusChangedRecursionGuard = true
    defer { onFocusChangedRecursionGuard = false }
    if hasFocusChanged {
        _ = await onFocusChanged(.defaultEnv, CmdIoImpl.emptyStdinIgnoringOut, focus)
    }
    if hasTagsChanged {
        broadcastEvent(.tagsChanged(tags: tagset.tagNames, prevTags: prevTagset.tagNames))
    }
    if hasFocusedMonitorChanged {
        _ = await onFocusedMonitorChanged(.defaultEnv, CmdIoImpl.emptyStdinIgnoringOut, focus)
    }
}

@MainActor func onFocusedMonitorChanged(_ env: CmdEnv, _ io: CmdIo, _ focus: LiveFocus) async -> Int32ExitCode {
    broadcastEvent(.focusedMonitorChanged(
        tags: focus.monitorState.tagset.tagNames,
        monitorId_oneBased: focus.monitor.monitorId_oneBased ?? 0,
    ))
    return await config.onFocusedMonitorChanged.run(env.withFocus(focus), io)
}

@MainActor func onFocusChanged(_ env: CmdEnv, _ io: CmdIo, _ focus: LiveFocus) async -> Int32ExitCode {
    broadcastEvent(.focusChanged(
        windowId: focus.windowOrNil?.windowId,
        tags: focus.monitorState.tagset.tagNames,
    ))
    return await config.onFocusChanged.run(env.withFocus(focus), io)
}
