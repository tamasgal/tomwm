public enum TomLayout: String, Sendable, CaseIterable, Equatable {
    case tile
    case monocle
    case floating

    /// The layout indicator shown in the menu bar, as in dwm
    public var symbol: String {
        switch self {
            case .tile: "[]="
            case .monocle: "[M]"
            case .floating: "><>"
        }
    }

    public static let unionLiteral: String = allCases.map(\.rawValue).joined(separator: "|")
}
