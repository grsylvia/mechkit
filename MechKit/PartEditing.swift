import Foundation
import simd

/// Text remains a draft until the whole edit passes validation.
struct PartDraft: Equatable {
    var name: String
    var dimensions: VectorDraft
    var position: VectorDraft

    init(part: PartRecord) {
        name = part.name
        dimensions = VectorDraft(part.dimensionsMeters)
        position = VectorDraft(part.positionMeters)
    }

    func applying(to part: PartRecord) throws -> PartRecord {
        var result = part
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.dimensionsMeters = try dimensions.value(label: "Dimensions")
        result.positionMeters = try position.value(label: "Position")
        try result.validate()
        _ = try PartRenderValues(part: result)
        return result
    }
}

struct VectorDraft: Equatable {
    var x: String
    var y: String
    var z: String

    init(_ value: Vector3Record) {
        x = String(value.x)
        y = String(value.y)
        z = String(value.z)
    }

    func value(label: String) throws -> Vector3Record {
        guard let x = Double(x), let y = Double(y), let z = Double(z),
            x.isFinite, y.isFinite, z.isFinite
        else {
            throw PartEditingError.invalid("\(label) must contain finite numbers in meters.")
        }
        return Vector3Record(x: x, y: y, z: z)
    }
}

/// Converts persistent Double geometry only at the RealityKit boundary.
struct PartRenderValues {
    let dimensionsMeters: SIMD3<Float>
    let positionMeters: SIMD3<Float>
    let orientation: simd_quatf

    init(part: PartRecord) throws {
        try part.validate()
        dimensionsMeters = SIMD3(
            Float(part.dimensionsMeters.x), Float(part.dimensionsMeters.y),
            Float(part.dimensionsMeters.z))
        positionMeters = SIMD3(
            Float(part.positionMeters.x), Float(part.positionMeters.y),
            Float(part.positionMeters.z))
        let dimensions = [dimensionsMeters.x, dimensionsMeters.y, dimensionsMeters.z]
        let positions = [positionMeters.x, positionMeters.y, positionMeters.z]
        guard dimensions.allSatisfy({ $0.isFinite && $0 >= Float.leastNormalMagnitude }),
            positions.allSatisfy({ $0.isFinite }),
            zip(positions, [part.positionMeters.x, part.positionMeters.y, part.positionMeters.z])
                .allSatisfy({ $0.0 != 0 || $0.1 == 0 })
        else {
            throw PartEditingError.invalid(
                "“\(part.name)” is outside the 3D renderer’s numeric range. Use smaller positions or dimensions, or larger dimensions."
            )
        }
        let q = part.orientationLocalToAssembly
        orientation =
            simd_quatf(vector: SIMD4(Float(q.x), Float(q.y), Float(q.z), Float(q.w)))
            .normalized
        // Every transformed corner must remain finite in the renderer's Float frame.
        for x: Float in [-0.5, 0.5] {
            for y: Float in [-0.5, 0.5] {
                for z: Float in [-0.5, 0.5] {
                    let corner =
                        positionMeters
                        + orientation.act(
                            dimensionsMeters * SIMD3(x, y, z))
                    guard corner.x.isFinite, corner.y.isFinite, corner.z.isFinite else {
                        throw PartEditingError.invalid(
                            "“\(part.name)” extends beyond the 3D renderer’s numeric range.")
                    }
                }
            }
        }
    }
}

enum PartEditingError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}
