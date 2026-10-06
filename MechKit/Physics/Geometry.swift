/// Solid geometry in a right-handed local frame, with its origin at the block center.
struct Geometry: Equatable {
    enum Shape {
        case solidRectangularBlock
    }

    let shape: Shape = .solidRectangularBlock
    /// Full side lengths along local X, Y, and Z, in meters.
    let dimensionsMeters: SIMD3<Double>

    init(rectangularBlockDimensionsMeters: SIMD3<Double>) throws {
        let dimensions = rectangularBlockDimensionsMeters
        guard dimensions.x.isFinite, dimensions.y.isFinite, dimensions.z.isFinite,
              dimensions.x > 0, dimensions.y > 0, dimensions.z > 0 else {
            throw PhysicsError.invalidDimensions
        }
        dimensionsMeters = dimensions
    }
}
