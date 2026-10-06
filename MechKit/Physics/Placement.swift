import simd

/// Rigid placement from component-local coordinates into a right-handed, Z-up assembly.
struct Placement: Equatable {
    let positionMeters: SIMD3<Double>
    /// Unit quaternion mapping local vectors into assembly coordinates.
    /// Positive angles follow the right-hand rule. Quaternion components are (x, y, z, w).
    let orientationLocalToAssembly: simd_quatd

    init() {
        positionMeters = .zero
        orientationLocalToAssembly = simd_quatd(ix: 0, iy: 0, iz: 0, r: 1)
    }

    init(positionMeters: SIMD3<Double>,
         orientationLocalToAssembly: simd_quatd = simd_quatd(ix: 0, iy: 0, iz: 0, r: 1)) throws {
        guard positionMeters.x.isFinite, positionMeters.y.isFinite, positionMeters.z.isFinite else {
            throw PhysicsError.invalidPosition
        }
        let vector = orientationLocalToAssembly.vector
        guard vector.x.isFinite, vector.y.isFinite, vector.z.isFinite, vector.w.isFinite else {
            throw PhysicsError.invalidOrientation
        }
        let scale = max(abs(vector.x), abs(vector.y), abs(vector.z), abs(vector.w))
        guard scale > 0 else { throw PhysicsError.invalidOrientation }
        // Scale first so finite quaternions cannot overflow or underflow during normalization.
        let scaled = vector / scale
        self.positionMeters = positionMeters
        self.orientationLocalToAssembly = simd_quatd(vector: scaled / simd_length(scaled))
    }
}
