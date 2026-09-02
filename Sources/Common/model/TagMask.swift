/// A set of tags, one bit per tag. Bit i corresponds to the i-th entry of the `tags` config option.
public struct TagMask: OptionSet, Sendable, Hashable, Equatable, CustomStringConvertible {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The number of tags that fit into the mask
    public static let capacity = 32

    public init(index: Int) {
        check(index >= 0 && index < TagMask.capacity, "Tag index \(index) is out of range")
        self.init(rawValue: 1 << UInt32(index))
    }

    public static let none = TagMask([])
    public static func all(count: Int) -> TagMask {
        check(count > 0 && count <= TagMask.capacity, "Tag count \(count) is out of range")
        return TagMask(rawValue: count == TagMask.capacity ? .max : (1 << UInt32(count)) - 1)
    }

    public var isEmpty: Bool { rawValue == 0 }
    public func intersects(_ other: TagMask) -> Bool { rawValue & other.rawValue != 0 }

    /// Indices of the set bits, ascending
    public var indices: [Int] {
        (0 ..< TagMask.capacity).filter { rawValue & (1 << UInt32($0)) != 0 }
    }

    public var description: String { "TagMask(\(indices.map(String.init).joined(separator: ",")))" }
}
