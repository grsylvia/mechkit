import Foundation

/// One individual rigid part. Geometry and material edits preserve identity.
/// Rendering and simulation can consume this same data without defining separate physics state.
final class Component: Identifiable {
    let id = UUID()
    private(set) var geometry: Geometry
    private(set) var material: Material
    var placement: Placement

    init(geometry: Geometry, material: Material, placement: Placement = Placement()) throws {
        _ = try Self.calculateMassProperties(geometry: geometry, material: material)
        self.geometry = geometry
        self.material = material
        self.placement = placement
    }

    /// Recomputed from current geometry and density; all values remain in the local frame.
    var massProperties: MassProperties {
        get throws {
            try Self.calculateMassProperties(geometry: geometry, material: material)
        }
    }

    /// Reject an unrepresentable result before changing the current valid geometry.
    func setGeometry(_ geometry: Geometry) throws {
        _ = try Self.calculateMassProperties(geometry: geometry, material: material)
        self.geometry = geometry
    }

    /// Replace the assigned record, including its density and provenance, as a single edit.
    func setMaterial(_ material: Material) throws {
        _ = try Self.calculateMassProperties(geometry: geometry, material: material)
        self.material = material
    }

    // Also used by persistent part records, without constructing a second part identity.
    static func calculateMassProperties(geometry: Geometry, material: Material) throws -> MassProperties {
        let dimensions = geometry.dimensionsMeters
        let volumeCubicMeters = positiveProduct(dimensions.x, dimensions.y, dimensions.z)
        guard volumeCubicMeters.isFinite, volumeCubicMeters > 0 else {
            throw PhysicsError.unrepresentableMassProperties
        }
        let massKilograms = positiveProduct(volumeCubicMeters, material.densityKgPerCubicMeter)
        guard massKilograms.isFinite, massKilograms > 0 else {
            throw PhysicsError.unrepresentableMassProperties
        }

        // For a uniform block centered at the local origin, Ixx = mass * (lengthY² + lengthZ²) / 12.
        // The other axes follow cyclically; symmetry makes the off-diagonal entries zero.
        let inertia = try InertiaTensor(diagonalKgMetersSquared: SIMD3(
            axialMoment(massKilograms: massKilograms, lengthA: dimensions.y, lengthB: dimensions.z),
            axialMoment(massKilograms: massKilograms, lengthA: dimensions.x, lengthB: dimensions.z),
            axialMoment(massKilograms: massKilograms, lengthA: dimensions.x, lengthB: dimensions.y)
        ))
        return try MassProperties(volumeCubicMeters: volumeCubicMeters, massKilograms: massKilograms,
                                  centerOfMassLocalMeters: .zero, inertiaTensorAboutCenterOfMassLocal: inertia)
    }

    /// Factor out the larger length before squaring, and round the complete axial moment.
    private static func axialMoment(massKilograms: Double, lengthA: Double, lengthB: Double) -> Double {
        let scale = max(lengthA, lengthB)
        let ratio = min(lengthA, lengthB) / scale
        return positiveProduct(massKilograms, scale, scale, (1 + ratio * ratio) / 12)
    }

    /// Multiply positive, finite factors without premature intermediate overflow or underflow.
    /// Keep exponents separate until conversion into the final Double range.
    private static func positiveProduct(_ factors: Double...) -> Double {
        var exponent = 0
        var significand = 1.0
        for factor in factors {
            exponent += factor.exponent
            significand *= factor.significand
        }
        return Double(sign: .plus, exponent: exponent, significand: significand)
    }
}
