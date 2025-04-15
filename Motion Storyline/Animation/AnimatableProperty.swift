import SwiftUI

/// Represents a property that can be animated with keyframes
public struct AnimatableProperty: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let type: PropertyType
    public let icon: String
    
    /// Implement hash(into:) for Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(icon)
    }
    
    /// Implement equality for Equatable conformance
    public static func == (lhs: AnimatableProperty, rhs: AnimatableProperty) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.type == rhs.type &&
               lhs.icon == rhs.icon
    }
    
    public enum PropertyType: Hashable {
        case position
        case size
        case rotation
        case color
        case opacity
        case scale
        case path
        case custom(valueType: Any.Type)
        
        /// Implement hash(into:) for Hashable conformance
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .position:
                hasher.combine(0) // Unique value for each case
            case .size:
                hasher.combine(1)
            case .rotation:
                hasher.combine(2)
            case .color:
                hasher.combine(3)
            case .opacity:
                hasher.combine(4)
            case .scale:
                hasher.combine(6)
            case .path:
                hasher.combine(7)
            case .custom(let type):
                hasher.combine(5)
                hasher.combine(ObjectIdentifier(type)) // Use ObjectIdentifier to hash the type
            }
        }
        
        /// Implement equality for Equatable conformance
        public static func == (lhs: PropertyType, rhs: PropertyType) -> Bool {
            switch (lhs, rhs) {
            case (.position, .position),
                 (.size, .size),
                 (.rotation, .rotation),
                 (.color, .color),
                 (.opacity, .opacity),
                 (.scale, .scale),
                 (.path, .path):
                return true
            case (.custom(let lhsType), .custom(let rhsType)):
                return ObjectIdentifier(lhsType) == ObjectIdentifier(rhsType)
            default:
                return false
            }
        }
    }
}

