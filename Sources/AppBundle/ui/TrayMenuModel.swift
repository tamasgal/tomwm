import AppKit
import Common

public final class TrayMenuModel: ObservableObject {
    @MainActor public static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    @Published var trayItems: [TrayItem] = []
    /// Is window management enabled
    @Published var isEnabled: Bool = true
    @Published var tags: [TagViewModel] = []
    /// Every monitor with its own tags and layout, in the order the menu bar draws them
    @Published var monitors: [MonitorViewModel] = []
    /// The active binding mode, or nil while the main mode is active
    @Published var activeModeName: String? = nil
    @Published var experimentalUISettings: ExperimentalUISettings = ExperimentalUISettings()
    @Published var lastReloadConfigContainedWarnings: Bool = false
    @Published var axPermissionStatus: AxPermissionStatus = .waitingWithPrompt
}

enum AxPermissionStatus: Equatable {
    case granted
    case waiting
    case waitingWithPrompt
}

/// The dwm status bar: the tags of every monitor, then the layout symbol.
/// A tag nobody is looking at and nothing lives on is left out, to keep the bar short.
@MainActor func updateTrayText() {
    let sortedMonitors = sortedMonitorInfos
    let focus = focus
    let modePrefix = activeMode?.takeIf { $0 != mainModeId }?.first.map { "(\($0.uppercased())) " } ?? ""

    TrayMenuModel.shared.trayText = modePrefix + sortedMonitors
        .map { monitor in
            let state = monitor.state
            let occupied = state.occupiedTags
            let names = config.tags.enumerated().compactMap { (index, name) -> String? in
                let mask = TagMask(index: index)
                let isSelected = state.tagset.intersects(mask)
                let isOccupied = occupied.intersects(mask)
                return switch true {
                    case isSelected: "[\(name)]"
                    case isOccupied: "\(name)"
                    default: nil
                }
            }
            let isFocused = monitor.rect.topLeftCorner == focus.monitorPoint && sortedMonitors.count > 1
            return (isFocused ? "*" : "") + names.joined(separator: " ") + " " + state.layout.symbol
        }
        .joined(separator: " │ ")

    let focusedState = focus.monitorState
    let occupied = focusedState.occupiedTags
    TrayMenuModel.shared.tags = config.tags.enumerated().map { (index, name) in
        let mask = TagMask(index: index)
        let windows = focusedState.clients.filter { $0.tags.intersects(mask) }
        let apps = windows.map { $0.app.name?.takeIf { !$0.isEmpty } }.filterNotNil().toSet()
        let dash = " - "
        let suffix = apps.isEmpty ? "" : dash + apps.sorted().joinTruncating(separator: ", ", length: 25)
        return TagViewModel(
            name: name,
            suffix: suffix,
            isSelected: focusedState.tagset.intersects(mask),
            isOccupied: occupied.intersects(mask),
            hasFullscreenWindows: windows.contains { $0.isFullscreen },
        )
    }

    TrayMenuModel.shared.activeModeName = activeMode?.takeIf { $0 != mainModeId }

    TrayMenuModel.shared.monitors = sortedMonitors.map { monitor in
        let state = monitor.state
        let occupied = state.occupiedTags
        return MonitorViewModel(
            tags: config.tags.enumerated().map { (index, name) in
                let mask = TagMask(index: index)
                return TagViewModel(
                    name: name,
                    suffix: "",
                    isSelected: state.tagset.intersects(mask),
                    isOccupied: occupied.intersects(mask),
                    hasFullscreenWindows: state.clients.contains { $0.tags.intersects(mask) && $0.isFullscreen },
                )
            },
            layout: state.layout,
            isFocused: monitor.rect.topLeftCorner == focus.monitorPoint,
        )
    }

    var items = sortedMonitors.flatMap { monitor -> [TrayItem] in
        let state = monitor.state
        let occupied = state.occupiedTags
        let isFocusedMonitor = monitor.rect.topLeftCorner == focus.monitorPoint
        let tagItems = config.tags.enumerated().compactMap { (index, name) -> TrayItem? in
            let mask = TagMask(index: index)
            let isSelected = state.tagset.intersects(mask)
            guard isSelected || occupied.intersects(mask) else { return nil }
            return TrayItem(
                type: .tag,
                name: name,
                isActive: isSelected && isFocusedMonitor,
                isOccupied: occupied.intersects(mask),
                hasFullscreenWindows: state.clients.contains { $0.tags.intersects(mask) && $0.isFullscreen },
            )
        }
        return tagItems + [TrayItem(type: .layout, name: state.layout.symbol, isActive: false, isOccupied: false, hasFullscreenWindows: false)]
    }
    let mode = activeMode?.takeIf { $0 != mainModeId }?.first.map {
        TrayItem(type: .mode, name: $0.uppercased(), isActive: true, isOccupied: false, hasFullscreenWindows: false)
    }
    if let mode {
        items.insert(mode, at: 0)
    }
    TrayMenuModel.shared.trayItems = items
}

struct TagViewModel: Hashable {
    let name: String
    let suffix: String
    let isSelected: Bool
    let isOccupied: Bool
    let hasFullscreenWindows: Bool
}

struct MonitorViewModel: Hashable {
    let tags: [TagViewModel]
    let layout: TomLayout
    let isFocused: Bool

    /// The tags the text styles list: the ones being looked at, and the ones holding windows
    var shownTags: [TagViewModel] { tags.filter { $0.isSelected || $0.isOccupied } }
}

enum TrayItemType: String, Hashable {
    case mode
    case tag
    case layout
}

private let validLetters = "A" ... "Z"

struct TrayItem: Hashable, Identifiable {
    let type: TrayItemType
    let name: String
    let isActive: Bool
    let isOccupied: Bool
    let hasFullscreenWindows: Bool

    var systemImageName: String? {
        // The layout symbol is deliberately drawn as text
        if type == .layout { return nil }
        // A system image only exists for numbers 0 to 50 and for a single capital letter
        switch Int(name) {
            case let number?: if !(0 ... 50).contains(number) { return nil }
            case nil where name.count == 1: if !validLetters.contains(name) { return nil }
            default: return nil
        }
        let lowercasedName = name.lowercased()
        return switch type {
            case .mode: "\(lowercasedName).circle"
            case .tag where isActive: "\(lowercasedName).square.fill"
            case .tag: "\(lowercasedName).square"
            case .layout: nil
        }
    }

    var id: String { type.rawValue + name }
}
