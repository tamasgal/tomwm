@testable import AppBundle
import Common
import SwiftUI
import XCTest

/// macOS draws the menu bar label image at its natural size and clips whatever sticks out, so a
/// label taller than the bar silently loses content. This renders every compact style through the
/// real ImageRenderer pipeline and checks that it fits.
///
/// Set SNAPSHOT_DIR to also write the rendered images for inspection.
final class DwmMenuBarLabelTest: XCTestCase {
    @MainActor
    func testDwmStylesFitTheMenuBar() throws {
        let outDir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]
        let model = TrayMenuModel.shared

        let scenarios: [(String, [MonitorViewModel], String?)] = [
            ("A. one monitor, dev selected", [monitor(selected: ["dev"], occupied: ["base", "web", "dev", "doc"], layout: .tile, focused: true)], nil),
            ("B. two selected, doc fullscreen", [monitor(selected: ["dev", "doc"], occupied: ["base", "web", "dev", "doc"], fullscreen: ["doc"], layout: .tile, focused: true)], nil),
            ("C. two monitors, service mode", [
                monitor(selected: ["dev"], occupied: ["base", "web", "dev"], layout: .tile, focused: true),
                monitor(selected: ["img"], occupied: ["img", "vid"], layout: .monocle, focused: false),
            ], "service"),
        ]

        // What macOS adds around the label image, measured on a real status item
        let statusItemPadding: CGFloat = 19
        var lines: [String] = []
        for (title, monitors, mode) in scenarios {
            model.monitors = monitors
            model.activeModeName = mode
            model.trayText = trayTextFor(monitors, mode: mode)
            for style in MenuBarStyle.allCases where style.isCompact {
                let renderer = ImageRenderer(content: viewFor(style, model))
                renderer.scale = 3
                guard let image = renderer.nsImage else {
                    XCTFail("\(style.rawValue) rendered nothing")
                    continue
                }
                XCTAssertLessThanOrEqual(
                    image.size.height, DwmMenuBarLabel.maxLabelHeight,
                    "\(style.rawValue) is \(Int(image.size.height))pt tall, over the "
                        + "\(Int(DwmMenuBarLabel.maxLabelHeight))pt macOS draws, so it would be clipped",
                )
                let width = Int((image.size.width + statusItemPadding).rounded())
                // Every tag is always shown, so the width is driven by the tag names, not by state.
                // A loose bound: it is here to notice unintended growth, not as a design target.
                XCTAssertLessThan(width, 450, "\(style.rawValue) is \(width)pt wide in scenario \(title)")
                lines.append(title.padding(toLength: 34, withPad: " ", startingAt: 0)
                    + style.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)
                    + "\(width)pt")
                if let outDir { save(image, to: "\(outDir)/repo-\(style.rawValue)-\(title.prefix(1)).png") }
            }
        }
        if let outDir {
            try lines.joined(separator: "\n").write(toFile: "\(outDir)/repo-widths.txt", atomically: true, encoding: .utf8)
        }
    }

    @MainActor
    private func viewFor(_ style: MenuBarStyle, _ model: TrayMenuModel) -> some View {
        DwmMenuBarLabel(boxed: style == .dwmTagsBoxed, color: .white).environmentObject(model)
    }

    @MainActor
    private func monitor(
        selected: Set<String>,
        occupied: Set<String>,
        fullscreen: Set<String> = [],
        layout: TomLayout,
        focused: Bool,
    ) -> MonitorViewModel {
        let names = ["base", "web", "dev", "doc", "img", "vid", "mus", "eml", "foo"]
        return MonitorViewModel(
            tags: names.map {
                TagViewModel(
                    name: $0,
                    suffix: "",
                    isSelected: selected.contains($0),
                    isOccupied: occupied.contains($0),
                    hasFullscreenWindows: fullscreen.contains($0),
                )
            },
            layout: layout,
            isFocused: focused,
        )
    }

    private func trayTextFor(_ monitors: [MonitorViewModel], mode: String?) -> String {
        let prefix = mode?.first.map { "(\(String($0).uppercased())) " } ?? ""
        return prefix + monitors.map { monitor in
            let names = monitor.shownTags.map { $0.isSelected ? "[\($0.name)]" : $0.name }
            let star = (monitor.isFocused && monitors.count > 1) ? "*" : ""
            return star + names.joined(separator: " ") + " " + monitor.layout.symbol
        }.joined(separator: " \u{2502} ")
    }

    private func save(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
