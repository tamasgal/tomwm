public enum CardinalDirection: String, CaseIterable, Equatable, Sendable {
    case left, down, up, right

    public var orientation: Orientation { self == .up || self == .down ? .v : .h }
    public var isPositive: Bool { self == .down || self == .right }
    public var focusOffset: Int { isPositive ? 1 : -1 }
}
