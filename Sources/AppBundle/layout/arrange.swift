import AppKit
import Common

enum OptimalHideCorner {
    case bottomLeftCorner, bottomRightCorner
}

/// The single place where the model turns into window frames on screen.
/// Runs once per refresh session, and recomputes every frame from scratch.
@MainActor
func arrangeMonitors() async throws {
    let monitors = monitorInfos
    if !TrayMenuModel.shared.isEnabled {
        // Window management is off. Give every window back to the user rather than leaving some of
        // them parked in a screen corner.
        for monitor in monitors {
            for window in monitor.state.clients { window.unhideFromCorner(on: monitor) }
            try await arrange(monitor, tagset: .all(count: config.tags.count))
        }
        return
    }

    let corners = optimalHideCorners(monitors)
    // Unhide before hiding, to reduce flicker
    for monitor in monitors {
        let state = monitor.state
        for window in state.clients where window.tags.intersects(state.tagset) {
            window.unhideFromCorner(on: monitor)
        }
        try await arrange(monitor)
    }
    for monitor in monitors {
        let state = monitor.state
        let corner = corners[monitor.rect.topLeftCorner] ?? .bottomRightCorner
        for window in state.clients
            where window.macosState == .normal && !window.tags.intersects(state.tagset)
        {
            try await window.hideInCorner(corner, on: monitor)
        }
    }
}

@MainActor
private func arrange(_ monitor: MonitorInfo, tagset: TagMask? = nil) async throws {
    let state = monitor.state
    let tagset = tagset ?? state.tagset
    let visible = state.clients.filter { $0.macosState == .normal && $0.tags.intersects(tagset) }
    if visible.isEmpty { return }

    let gaps = ResolvedGaps(gaps: config.gaps, monitor: monitor)
    let padded = monitor.visibleRectPaddedByOuterGaps
    // If monitors are stacked vertically and the one below is narrower, macOS may refuse to give a
    // window on the upper monitor its full height. Asking for one point less works around it.
    let area = Rect(
        topLeftX: padded.topLeftX,
        topLeftY: padded.topLeftY,
        width: padded.width,
        height: padded.height - 1,
    )

    // tomwm's own fullscreen. Only the focused window of the monitor can hold it.
    let fullscreen = state.mruVisibleClient.flatMap { $0.isFullscreen && visible.contains($0) ? $0 : nil }
    if let fullscreen {
        let rect = fullscreen.noOuterGapsInFullscreen ? monitor.visibleRect : padded
        place(fullscreen, rect)
    }
    for window in visible where window != fullscreen { window.isFullscreen = false }

    let tiled = visible.filter { !$0.isFloating && $0 != fullscreen }
    switch state.layout {
        case .floating: break
        case .monocle: for window in tiled { place(window, area) }
        case .tile: layoutTile(tiled, area, gaps, nmaster: state.nmaster, mfact: state.mfact)
    }

    for window in visible where window.isFloating && window != fullscreen {
        try await reanchorFloatingWindow(window, on: monitor)
    }
}

/// dwm's tile(): `nmaster` windows fill a master column on the left, the rest share a stack column
/// on the right. Heights are divided incrementally so the remainder is spread, not dumped on the
/// last window.
@MainActor
private func layoutTile(_ tiled: [Window], _ area: Rect, _ gaps: ResolvedGaps, nmaster: Int, mfact: Double) {
    let n = tiled.count
    if n == 0 { return }
    let colGapRaw = CGFloat(gaps.inner.horizontal)
    let rowGap = CGFloat(gaps.inner.vertical)

    let masterCount = min(max(nmaster, 0), n)
    let stackCount = n - masterCount
    let colGap = masterCount > 0 && stackCount > 0 ? colGapRaw : 0
    let masterWidth: CGFloat = stackCount > 0
        ? (masterCount > 0 ? (area.width - colGap) * CGFloat(mfact) : 0)
        : area.width
    let stackWidth = area.width - masterWidth - colGap

    layoutColumn(tiled.prefix(masterCount), x: area.topLeftX, width: masterWidth, area, rowGap)
    layoutColumn(tiled.suffix(stackCount), x: area.topLeftX + masterWidth + colGap, width: stackWidth, area, rowGap)
}

@MainActor
private func layoutColumn(_ windows: ArraySlice<Window>, x: CGFloat, width: CGFloat, _ area: Rect, _ rowGap: CGFloat) {
    let count = windows.count
    if count == 0 || width <= 0 { return }
    var y = area.topLeftY
    var remaining = area.height - rowGap * CGFloat(count - 1)
    for (i, window) in windows.enumerated() {
        let height = remaining / CGFloat(count - i)
        place(window, Rect(topLeftX: x, topLeftY: y, width: width, height: height))
        y += height + rowGap
        remaining -= height
    }
}

@MainActor
private func place(_ window: Window, _ rect: Rect) {
    // A window the user is dragging must not be yanked back under the cursor
    if window.windowId == currentlyManipulatedWithMouseWindowId { return }
    window.lastAppliedRect = rect
    window.setAxFrame(rect.topLeftCorner, CGSize(width: rect.width, height: rect.height))
}

/// Floating windows keep the geometry the user gave them, but a window whose owning monitor changed
/// has to be brought over to it, keeping its relative position.
@MainActor
private func reanchorFloatingWindow(_ window: Window, on monitor: MonitorInfo) async throws {
    guard let windowRect = try await window.getAxRect(.cancellable) else { return } // Not idempotent
    let currentMonitor = windowRect.center.monitorApproximation
    if currentMonitor.rect.topLeftCorner == monitor.rect.topLeftCorner { return }

    let topLeft = windowRect.topLeftCorner
    let xProportion = (topLeft.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
    let yProportion = (topLeft.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height

    let target = monitor.visibleRect
    var newX = target.topLeftX + xProportion * target.width
    var newY = target.topLeftY + yProportion * target.height
    newX = newX.coerce(in: target.minX ... max(target.minX, target.maxX - windowRect.width))
    newY = newY.coerce(in: target.minY ... max(target.minY, target.maxY - windowRect.height))
    window.setAxFrame(CGPoint(x: newX, y: newY), nil)
}

/// Pick, per monitor, the screen corner least likely to be visible on a neighbouring monitor.
@MainActor
private func optimalHideCorners(_ monitors: [MonitorInfo]) -> [CGPoint: OptimalHideCorner] {
    var result: [CGPoint: OptimalHideCorner] = [:]
    for monitor in monitors {
        let xOff = monitor.width * 0.1
        let yOff = monitor.height * 0.1

        let brc1 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: -yOff)
        let brc2 = monitor.rect.bottomRightCorner + CGPoint(x: -xOff, y: 2)
        let brc3 = monitor.rect.bottomRightCorner + CGPoint(x: 2, y: 2)

        let blc1 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: -yOff)
        let blc2 = monitor.rect.bottomLeftCorner + CGPoint(x: xOff, y: 2)
        let blc3 = monitor.rect.bottomLeftCorner + CGPoint(x: -2, y: 2)

        func contains(_ monitor: MonitorInfo, _ point: CGPoint) -> Int { monitor.rect.contains(point) ? 1 : 0 }
        let important = 10

        result[monitor.rect.topLeftCorner] =
            monitors.sumOfInt { contains($0, blc1) + contains($0, blc2) + important * contains($0, blc3) } <
            monitors.sumOfInt { contains($0, brc1) + contains($0, brc2) + important * contains($0, brc3) }
            ? .bottomLeftCorner
            : .bottomRightCorner
    }
    return result
}
