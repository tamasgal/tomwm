import AppKit
import Common

/// Everything tomwm knows about one monitor. The direct equivalent of dwm's `Monitor`.
@MainActor
final class MonitorState {
    /// dwm's `clients`. The tiling order: index 0 is the master window. New windows are prepended.
    var clients: [Window] = []
    /// dwm's `stack`. The focus order, most recently focused first.
    let focusStack: MruStack<Window> = MruStack()
    /// dwm's `tagset[seltags]`. The tags currently shown on this monitor.
    var tagset: TagMask
    /// dwm's `tagset[seltags ^ 1]`. What `view --back-and-forth` returns to.
    var prevTagset: TagMask
    var layout: TomLayout
    var prevLayout: TomLayout
    var nmaster: Int
    var mfact: Double

    init() {
        self.tagset = TagMask(index: 0)
        self.prevTagset = TagMask(index: 0)
        self.layout = config.defaultLayout
        self.prevLayout = config.defaultLayout == .tile ? .monocle : .tile
        self.nmaster = config.nmaster
        self.mfact = config.mfact
    }

    /// dwm's ISVISIBLE over this monitor's clients, in tiling order
    var visibleClients: [Window] { clients.filter { $0.macosState == .normal && $0.tags.intersects(tagset) } }
    /// dwm's nexttiled sequence
    var tiledClients: [Window] { visibleClients.filter { !$0.isFloating } }
    /// The tags that hold at least one window on this monitor
    var occupiedTags: TagMask {
        clients.reduce(into: TagMask.none) { $0.formUnion($1.tags) }
    }

    /// dwm's `attach`: a new window becomes the master
    func attach(_ window: Window) {
        detach(window)
        clients.insert(window, at: 0)
        focusStack.pushOrRaise(window)
    }

    func detach(_ window: Window) {
        clients.remove(element: window)
        focusStack.remove(window)
    }

    /// dwm's `pop`: move to the head of the client list
    func promoteToMaster(_ window: Window) {
        guard clients.contains(window) else { return }
        clients.remove(element: window)
        clients.insert(window, at: 0)
    }

    /// dwm's `focus(NULL)`: the most recently focused visible window
    var mruVisibleClient: Window? {
        focusStack.first { $0.macosState == .normal && $0.tags.intersects(tagset) } ?? visibleClients.first
    }
}

@MainActor private var _monitorStates: [CGPoint: MonitorState] = [:]

@MainActor var monitorStates: [CGPoint: MonitorState] { _monitorStates }

/// Total lookup. Never auto-vivifies under a stale key: a miss triggers the display remap first,
/// and an unresolvable point falls back to the nearest live monitor.
@MainActor
func monitorStateFor(_ point: CGPoint) -> MonitorState {
    if let existing = _monitorStates[point] { return existing }
    rearrangeMonitorStates()
    if let existing = _monitorStates[point] { return existing }
    let fallback = point.monitorApproximation.rect.topLeftCorner
    if let existing = _monitorStates[fallback] { return existing }
    let fresh = MonitorState()
    _monitorStates[fallback] = fresh
    return fresh
}

/// Total lookup of the live monitor a stored point refers to
@MainActor
func monitorInfo(at point: CGPoint) -> MonitorInfo {
    monitorInfos.first { $0.rect.topLeftCorner == point } ?? point.monitorApproximation
}

extension MonitorInfo {
    @MainActor var state: MonitorState { monitorStateFor(rect.topLeftCorner) }
}

/// Re-key the monitor states after a display reconfiguration, mapping each old monitor to the
/// nearest new one. A state whose monitor is gone hands its clients to the main monitor, and those
/// clients are re-tagged with the destination's current tags so they cannot become unreachable.
/// This mirrors dwm's `cleanupmon` + `sendmon`.
@MainActor
func rearrangeMonitorStates() {
    let livePoints = monitorInfos.map(\.rect.topLeftCorner)
    guard !livePoints.isEmpty else { return }
    if Set(_monitorStates.keys) == Set(livePoints) { return }

    let old = _monitorStates
    // For every live monitor, the closest old monitor that no closer old monitor has already claimed
    var claimed: [CGPoint: CGPoint] = [:]
    for oldPoint in old.keys {
        guard let live = livePoints.minBy({ ($0 - oldPoint).vectorLength }) else { continue }
        if let prev = claimed[live], (prev - live).vectorLength <= (oldPoint - live).vectorLength { continue }
        claimed[live] = oldPoint
    }

    var new: [CGPoint: MonitorState] = [:]
    for live in livePoints {
        let state = claimed[live].flatMap { old[$0] } ?? MonitorState()
        for client in state.clients { client.monitorPoint = live }
        new[live] = state
    }

    let survivors = Set(claimed.values)
    let mainPoint = mainMonitorInfo.rect.topLeftCorner
    let homePoint = new[mainPoint] != nil ? mainPoint : livePoints.first.orDie()
    let home = new[homePoint].orDie()
    for (oldPoint, state) in old where !survivors.contains(oldPoint) {
        for client in state.clients {
            client.monitorPoint = homePoint
            client.tags = home.tagset
            home.clients.append(client)
            home.focusStack.pushOrRaise(client)
        }
    }

    _monitorStates = new
}

/// Called on every refresh. Cheap when nothing changed.
@MainActor
func gcMonitors() {
    if Set(_monitorStates.keys) != Set(monitorInfos.map(\.rect.topLeftCorner)) {
        rearrangeMonitorStates()
    }
}

@MainActor
func resetMonitorStatesForTests() {
    _monitorStates = [:]
    for monitor in monitorInfos { _monitorStates[monitor.rect.topLeftCorner] = MonitorState() }
}
