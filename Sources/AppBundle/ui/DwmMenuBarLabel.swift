import Common
import Foundation
import SwiftUI

/// dwm's tag bar. Every tag is always shown, in config order, so the label never changes width as
/// windows come and go. The tags being viewed are inverted, a tag holding windows carries dwm's
/// small square in its top left corner, and the layout indicator closes the row.
///
/// Only the focused monitor is drawn. Tags are per monitor and independent, so the other monitor's
/// tags say nothing about what the keyboard would do right now.
///
/// macOS places the label image in the bar at its natural size and clips the overflow rather than
/// scaling it down, so everything here is sized to fit inside `NSStatusBar.system.thickness`.
@MainActor
struct DwmMenuBarLabel: View {
    @EnvironmentObject var viewModel: TrayMenuModel
    let boxed: Bool
    let color: Color

    /// The tallest label macOS draws without cutting it, which is the menu bar's own height rather
    /// than the 22pt NSStatusBar.system.thickness advertises. Measured with real status items: 23,
    /// 24 and 25pt labels render in full, 26pt loses both its top and bottom edge.
    static let maxLabelHeight: CGFloat = 25

    /// macOS clips the label rather than scaling it, so the type can only grow until the glyphs
    /// stop fitting. A font's line box here is its ascender-to-descender span with no leading to
    /// reclaim, so 21pt (a 24.7pt span) is the largest that fits; 22pt needs 25.9pt and is cut.
    private let fontSize: CGFloat = 21
    /// Driven by the real font metrics so the layout stays consistent if fontSize changes
    private var cellHeight: CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        return min((font.ascender - font.descender).rounded(.up), Self.maxLabelHeight)
    }
    private var cellPadding: CGFloat { fontSize * 0.22 }
    /// dwm's boxs and boxw: the occupancy marker in the top left of a tag. Sized to sit inside the
    /// cell's left padding so it never lands on an ascender.
    private var markerInset: CGFloat { fontSize * 0.04 }
    private var markerSize: CGFloat { fontSize * 0.16 }

    var body: some View {
        HStack(spacing: fontSize * 0.42) {
            if let mode = viewModel.activeModeName {
                modeBadge(mode)
            }
            if let monitor = viewModel.monitors.first(where: \.isFocused) ?? viewModel.monitors.first {
                HStack(spacing: boxed ? 2.5 : fontSize * 0.1) {
                    ForEach(monitor.tags, id: \.name) { tag in
                        tagCell(tag)
                    }
                }
                layoutIcon(monitor.layout)
            }
        }
    }

    @ViewBuilder
    private func tagCell(_ tag: TagViewModel) -> some View {
        let label = Text(tag.name)
            .font(.system(size: fontSize, weight: .semibold))
            .fontWidth(.compressed)
            .fixedSize()
            .padding(.horizontal, cellPadding)
            .frame(height: cellHeight)
        if tag.isSelected {
            ZStack {
                label.background { RoundedRectangle(cornerRadius: 4, style: .continuous) }
                label.blendMode(.destinationOut)
                // The marker and the fullscreen notch are knocked out of the inverted cell
                if tag.isOccupied { markerInCorner.blendMode(.destinationOut) }
                if tag.hasFullscreenWindows { fullscreenNotch.blendMode(.destinationOut) }
            }
            .compositingGroup()
            .foregroundStyle(color)
        } else {
            label
                .foregroundStyle(color)
                .opacity(tag.isOccupied ? 0.85 : 0.35)
                .background {
                    if boxed {
                        // Inset, because a stroke on the full cell height lands on the image edge
                        // and macOS clips it away
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(lineWidth: 1.2)
                            .foregroundStyle(color)
                            .opacity(tag.isOccupied ? 0.75 : 0.25)
                            .padding(0.75)
                    }
                }
                .overlay(alignment: .topLeading) { if tag.isOccupied { marker.foregroundStyle(color) } }
        }
    }

    private var marker: some View {
        Rectangle()
            .frame(width: markerSize, height: markerSize)
            .padding(.leading, markerInset)
            .padding(.top, markerInset)
    }

    /// The same marker for the inverted cell, where a ZStack would otherwise centre it
    private var markerInCorner: some View {
        GeometryReader { _ in marker }
    }

    private var fullscreenNotch: some View {
        GeometryReader { geo in
            Circle()
                .frame(width: markerSize * 1.3, height: markerSize * 1.3)
                .position(x: geo.size.width - markerSize * 0.7, y: markerSize * 0.7)
        }
    }

    private func layoutIcon(_ layout: TomLayout) -> some View {
        Image(systemName: layout.systemImageName)
            .font(.system(size: fontSize * 1.1))
            .foregroundStyle(color)
    }

    private func modeBadge(_ mode: String) -> some View {
        Text(mode.prefix(1).uppercased())
            .font(.system(size: fontSize, weight: .bold))
            .fixedSize()
            .foregroundStyle(color)
            .frame(width: cellHeight, height: cellHeight)
            .overlay { Circle().strokeBorder(lineWidth: 1.4).foregroundStyle(color) }
    }
}

extension TomLayout {
    /// The layout indicator for the menu bar, where the three dwm symbols are too wide to spell out
    var systemImageName: String {
        switch self {
            case .tile: "rectangle.lefthalf.inset.filled"
            case .monocle: "square.fill"
            case .floating: "square.on.square"
        }
    }
}
