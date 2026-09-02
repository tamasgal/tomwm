import SwiftUI

struct ExperimentalUISettings {
    var displayStyle: MenuBarStyle {
        get {
            switch UserDefaults.standard.string(forKey: ExperimentalUISettingsItems.displayStyle.rawValue) {
                case let value?: MenuBarStyle(rawValue: value) ?? .dwmTags
                case nil: .dwmTags
            }
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: ExperimentalUISettingsItems.displayStyle.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Equatable, Hashable {
    case monospacedText
    case systemText
    case squares
    case i3
    case i3Ordered
    case dwmTags
    case dwmTagsBoxed
    var id: String { rawValue }
    var title: String {
        switch self {
            case .monospacedText: "Monospaced font"
            case .systemText: "System font"
            case .squares: "Square images"
            case .i3: "i3 style grouped"
            case .i3Ordered: "i3 style ordered"
            case .dwmTags: "dwm tag bar"
            case .dwmTagsBoxed: "dwm tag bar, boxed"
        }
    }

    /// The dwm styles are sized to fit the menu bar instead of being drawn at .largeTitle and clipped
    var isCompact: Bool {
        switch self {
            case .monospacedText, .systemText, .squares, .i3, .i3Ordered: false
            case .dwmTags, .dwmTagsBoxed: true
        }
    }
}

enum ExperimentalUISettingsItems: String {
    case displayStyle
}

@MainActor
func getExperimentalUISettingsMenu(viewModel: TrayMenuModel) -> some View {
    let color = AppearanceTheme.current == .dark ? Color.white : Color.black
    return Menu {
        Text("Menu bar style (macOS 14 or later):")
        ForEach(MenuBarStyle.allCases, id: \.id) { style in
            MenuBarStyleButton(style: style, color: color).environmentObject(viewModel)
        }
    } label: {
        Text("Experimental UI Settings (No stability guarantees)")
    }
}

@MainActor
struct MenuBarStyleButton: View {
    @EnvironmentObject var viewModel: TrayMenuModel
    let style: MenuBarStyle
    let color: Color

    var body: some View {
        Button {
            viewModel.experimentalUISettings.displayStyle = style
        } label: {
            Toggle(isOn: .constant(viewModel.experimentalUISettings.displayStyle == style)) {
                MenuBarLabel(style: style, color: color)
                    .environmentObject(viewModel)
                Text(" -  " + style.title)
            }
        }
    }
}
