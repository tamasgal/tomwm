import Foundation
import AppKit

public protocol TomAny {}

extension TomAny {
    @discardableResult
    @inlinable
    public func also(_ block: (Self) -> Void) -> Self {
        block(self)
        return self
    }

    @inlinable public func takeIf(_ predicate: (Self) -> Bool) -> Self? { predicate(self) ? self : nil }

    var noopKeyPath: () {
        get { () }
        set {} // swiftlint:disable:this unused_setter_value
    }
}

extension Int: TomAny {}
extension String: TomAny {}
extension Character: TomAny {}
extension Regex: TomAny {}
extension Array: TomAny {}
extension URL: TomAny {}
extension CGFloat: TomAny {}
extension AXUIElement: TomAny {}
extension CGPoint: TomAny {}
