import AppKit
import Common

extension MonitorId {
    @MainActor func resolve(_ io: CmdIo, sortedMonitors: [MonitorInfo]) -> [MonitorInfo] {
        switch self {
            case .focused:
                return [focus.monitor]
            case .mouse:
                return [mouseLocation.monitorApproximation]
            case .all:
                return monitorInfos
            case .index(let index):
                if let monitor = sortedMonitors.getOrNil(atIndex: index) {
                    return [monitor]
                } else {
                    io.err("Invalid monitor ID: \(index + 1)")
                    return []
                }
        }
    }
}

extension [MonitorId] {
    @MainActor func resolveMonitorPoints(_ io: CmdIo) -> Set<CGPoint> {
        var requested: Set<CGPoint> = []
        let sortedMonitors = sortedMonitorInfos
        for id in self {
            let resolved = id.resolve(io, sortedMonitors: sortedMonitors)
            if resolved.isEmpty { return [] }
            for monitor in resolved { requested.insert(monitor.rect.topLeftCorner) }
        }
        return requested
    }

    @MainActor func resolveMonitors(_ io: CmdIo) -> [MonitorInfo] {
        let points = resolveMonitorPoints(io)
        return sortedMonitorInfos.filter { points.contains($0.rect.topLeftCorner) }
    }
}
