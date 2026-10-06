import Foundation

enum PhysicsError: Error, Equatable, LocalizedError {
    case invalidDimensions
    case invalidMaterialName
    case invalidDensity
    case invalidMaterialSource
    case invalidPosition
    case invalidOrientation
    case invalidCenterOfMass
    case invalidInertiaTensor
    case unrepresentableMassProperties

    var errorDescription: String? {
        switch self {
        case .invalidDimensions:
            "Block dimensions must be finite and greater than zero in meters."
        case .invalidMaterialName:
            "A material record must have a nonempty name."
        case .invalidDensity:
            "Material density must be finite and greater than zero in kg/m³."
        case .invalidMaterialSource:
            "A material record must include nonempty source information."
        case .invalidPosition:
            "Placement position must be finite in meters."
        case .invalidOrientation:
            "Placement orientation must be a finite, nonzero quaternion."
        case .invalidCenterOfMass:
            "Local center of mass must be finite in meters."
        case .invalidInertiaTensor:
            "Principal moments of inertia must satisfy the physical triangle inequality."
        case .unrepresentableMassProperties:
            "Block volume, mass, and moments of inertia must be finite and greater than zero."
        }
    }
}
