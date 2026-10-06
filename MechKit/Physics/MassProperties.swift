import simd

/// Symmetric inertia tensor about the center of mass, expressed in the component-local frame.
/// Entries use kg·m². Off-diagonal entries are actual tensor entries (-integral(x*y dm), etc.).
struct InertiaTensor: Equatable {
    let xxKgMetersSquared: Double
    let yyKgMetersSquared: Double
    let zzKgMetersSquared: Double
    let xyKgMetersSquared: Double = 0
    let xzKgMetersSquared: Double = 0
    let yzKgMetersSquared: Double = 0

    /// The initial axis-aligned solid block has diagonal inertia in its local frame.
    init(diagonalKgMetersSquared: SIMD3<Double>) throws {
        let diagonal = diagonalKgMetersSquared
        guard diagonal.x.isFinite, diagonal.y.isFinite, diagonal.z.isFinite,
              diagonal.x > 0, diagonal.y > 0, diagonal.z > 0 else {
            throw PhysicsError.unrepresentableMassProperties
        }
        // Physical principal moments obey the triangle inequality; allow rounding at its limit.
        let scale = max(diagonal.x, diagonal.y, diagonal.z)
        let normalized = diagonal / scale
        let tolerance = 8 * Double.ulpOfOne
        guard normalized.x <= normalized.y + normalized.z + tolerance,
              normalized.y <= normalized.x + normalized.z + tolerance,
              normalized.z <= normalized.x + normalized.y + tolerance else {
            throw PhysicsError.invalidInertiaTensor
        }
        xxKgMetersSquared = diagonal.x
        yyKgMetersSquared = diagonal.y
        zzKgMetersSquared = diagonal.z
    }

    var matrixKgMetersSquared: simd_double3x3 {
        simd_double3x3(columns: (
            SIMD3(xxKgMetersSquared, xyKgMetersSquared, xzKgMetersSquared),
            SIMD3(xyKgMetersSquared, yyKgMetersSquared, yzKgMetersSquared),
            SIMD3(xzKgMetersSquared, yzKgMetersSquared, zzKgMetersSquared)
        ))
    }
}

/// Derived properties of a uniform solid block. Placement does not change these local values.
struct MassProperties: Equatable {
    let volumeCubicMeters: Double
    let massKilograms: Double
    let centerOfMassLocalMeters: SIMD3<Double>
    let inertiaTensorAboutCenterOfMassLocal: InertiaTensor

    init(volumeCubicMeters: Double, massKilograms: Double,
         centerOfMassLocalMeters: SIMD3<Double>, inertiaTensorAboutCenterOfMassLocal: InertiaTensor) throws {
        guard volumeCubicMeters.isFinite, massKilograms.isFinite,
              volumeCubicMeters > 0, massKilograms > 0 else {
            throw PhysicsError.unrepresentableMassProperties
        }
        guard centerOfMassLocalMeters.x.isFinite, centerOfMassLocalMeters.y.isFinite,
              centerOfMassLocalMeters.z.isFinite else {
            throw PhysicsError.invalidCenterOfMass
        }
        self.volumeCubicMeters = volumeCubicMeters
        self.massKilograms = massKilograms
        self.centerOfMassLocalMeters = centerOfMassLocalMeters
        self.inertiaTensorAboutCenterOfMassLocal = inertiaTensorAboutCenterOfMassLocal
    }
}
