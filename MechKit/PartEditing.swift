import Foundation
import simd

/// Text remains a draft until the whole edit passes validation.
struct PartDraft: Equatable {
    var name: String
    var dimensions: VectorDraft
    var position: VectorDraft
    var rotationDegrees: VectorDraft
    var material: MaterialDraft

    init(part: PartRecord) {
        name = part.name
        dimensions = VectorDraft(part.dimensionsMeters)
        position = VectorDraft(part.positionMeters)
        rotationDegrees = VectorDraft(PartRotation.degrees(from: part.orientationLocalToAssembly))
        material = MaterialDraft(part.material)
    }

    func applying(to part: PartRecord) throws -> PartRecord {
        var result = part
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.dimensionsMeters = try dimensions.value(label: "Dimensions")
        result.positionMeters = try position.value(label: "Position")
        // Preserve the exact stored quaternion when only other properties are edited.
        if rotationDegrees
            != VectorDraft(PartRotation.degrees(from: part.orientationLocalToAssembly))
        {
            result.orientationLocalToAssembly = try PartRotation.orientation(
                fromDegrees: rotationDegrees.value(label: "Rotation", unit: "degrees"))
        }
        result.material = try material.value()
        try result.validate()
        _ = try PartRenderValues(part: result)
        return result
    }
}

struct MaterialDraft: Equatable {
    var isAssigned: Bool
    var name: String
    var densityKgPerCubicMeter: String
    var source: String

    init(_ material: MaterialRecord?) {
        isAssigned = material != nil
        name = material?.name ?? ""
        densityKgPerCubicMeter = material.map { String($0.densityKgPerCubicMeter) } ?? ""
        source = material?.source ?? ""
    }

    func value() throws -> MaterialRecord? {
        guard isAssigned else { return nil }
        guard let density = Double(densityKgPerCubicMeter) else {
            throw PhysicsError.invalidDensity
        }
        let material = try Material(name: name, densityKgPerCubicMeter: density, source: source)
        return MaterialRecord(
            name: material.name, densityKgPerCubicMeter: material.densityKgPerCubicMeter,
            source: material.source)
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

    func value(label: String, unit: String = "meters") throws -> Vector3Record {
        guard let x = Double(x), let y = Double(y), let z = Double(z),
            x.isFinite, y.isFinite, z.isFinite
        else {
            throw PartEditingError.invalid("\(label) must contain finite numbers in \(unit).")
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

/// Right-handed rotations about fixed assembly X, then Y, then Z: R = Rz * Ry * Rx.
/// Degrees are an editing representation; unit quaternions remain the saved representation.
enum PartRotation {
    static func orientation(fromDegrees degrees: Vector3Record) throws -> QuaternionRecord {
        guard degrees.isFinite else {
            throw PartEditingError.invalid("Rotation must contain finite numbers in degrees.")
        }
        func radians(_ degrees: Double) -> Double {
            degrees.truncatingRemainder(dividingBy: 360) * (.pi / 180)
        }
        let x = simd_quatd(angle: radians(degrees.x), axis: SIMD3(1, 0, 0))
        let y = simd_quatd(angle: radians(degrees.y), axis: SIMD3(0, 1, 0))
        let z = simd_quatd(angle: radians(degrees.z), axis: SIMD3(0, 0, 1))
        let vector = (z * y * x).normalized.vector
        return QuaternionRecord(x: vector.x, y: vector.y, z: vector.z, w: vector.w)
    }

    static func degrees(from orientation: QuaternionRecord) -> Vector3Record {
        let q = simd_quatd(
            vector: SIMD4(orientation.x, orientation.y, orientation.z, orientation.w)
        )
        .normalized
        let matrix = simd_double3x3(q)
        let cosinePitch = hypot(matrix[0][0], matrix[0][1])
        let pitch = atan2(-matrix[0][2], cosinePitch)
        let roll: Double
        let yaw: Double
        if cosinePitch > 1e-12 {
            roll = atan2(matrix[1][2], matrix[2][2])
            yaw = atan2(matrix[0][1], matrix[0][0])
        } else {
            // At ±90° pitch, roll and yaw are coupled. Choose roll = 0 canonically.
            roll = 0
            yaw = atan2(-matrix[1][0], matrix[1][1])
        }
        return Vector3Record(x: roll * (180 / .pi), y: pitch * (180 / .pi), z: yaw * (180 / .pi))
    }
}
