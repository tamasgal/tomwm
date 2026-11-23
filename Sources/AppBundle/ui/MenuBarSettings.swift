import SwiftUI

struct MenuBarSettings {
    var displayStyle: MenuBarStyle {
        get {
            switch UserDefaults.standard.string(forKey: MenuBarSettingsItems.displayStyle.rawValue) {
                case let value?: MenuBarStyle(rawValue: value) ?? .dwmTags
                case nil: .dwmTags
            }
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: MenuBarSettingsItems.displayStyle.rawValue)
            UserDefaults.standard.synchronize()
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Equatable, Hashable {
    case dwmTags
    case dwmTagsBoxed
    case monospacedText
    case systemText
    case squares
    case i3
    case i3Ordered
    var id: String { rawValue }
    var title: String {
        switch self {
            case .dwmTags: "dwm tag bar"
            case .dwmTagsBoxed: "dwm tag bar, boxed"
            case .monospacedText: "Monospaced font"
            case .systemText: "System font"
            case .squares: "Square images"
            case .i3: "i3 style grouped"
            case .i3Ordered: "i3 style ordered"
        }
    }

    /// The dwm styles are sized to fit the menu bar instead of being drawn at .largeTitle and clipped
    var isCompact: Bool {
        switch self {
            case .dwmTags, .dwmTagsBoxed: true
            case .monospacedText, .systemText, .squares, .i3, .i3Ordered: false
        }
    }
}

enum MenuBarSettingsItems: String {
    case displayStyle
}

@MainActor
func getTagStyleMenu(viewModel: TrayMenuModel) -> some View {
    let color = AppearanceTheme.current == .dark ? Color.white : Color.black
    return Menu {
        Text("Menu bar style (macOS 14 or later):")
        ForEach(MenuBarStyle.allCases, id: \.id) { style in
            MenuBarStyleButton(style: style, color: color).environmentObject(viewModel)
        }
    } label: {
        Text("Tag style")
    }
}

@MainActor
struct MenuBarStyleButton: View {
    @EnvironmentObject var viewModel: TrayMenuModel
    let style: MenuBarStyle
    let color: Color

    var body: some View {
        Button {
            viewModel.menuBarSettings.displayStyle = style
        } label: {
            Toggle(isOn: .constant(viewModel.menuBarSettings.displayStyle == style)) {
                MenuBarLabel(style: style, color: color)
                    .environmentObject(viewModel)
                Text(" -  " + style.title)
            }
        }
    }
}
