import AppKit

extension Comparable {
    public func until(excl bound: Self) -> Range<Self>? { self < bound ? self ..< bound : nil }
}
