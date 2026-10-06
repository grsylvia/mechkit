import Foundation

/// Persistent design data: meters, a right-handed assembly frame, and +Z up.
/// Local block dimensions are full extents about the part origin.
struct AssemblyRecord: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion = currentSchemaVersion
    var parts: [PartRecord] = []

    static var sample: Self {
        Self(parts: [
            PartRecord(
                name: "Sample block",
                dimensionsMeters: Vector3Record(x: 0.12, y: 0.08, z: 0.04),
                positionMeters: Vector3Record(x: 0, y: 0, z: 0.02)
            )
        ])
    }

    init(parts: [PartRecord] = []) {
        self.parts = parts
    }

    init(jsonData: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: jsonData)
        try validate()
    }

    func jsonData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw AssemblyRecordError.unsupportedVersion(schemaVersion)
        }
        var ids = Set<UUID>()
        for part in parts {
            guard ids.insert(part.id).inserted else {
                throw AssemblyRecordError.invalidPart("Part identifiers must be unique.")
            }
            try part.validate()
        }
    }
}

struct PartRecord: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var dimensionsMeters: Vector3Record
    var positionMeters = Vector3Record.zero
    /// Unit quaternion (x, y, z, w), rotating local coordinates into the assembly frame.
    var orientationLocalToAssembly = QuaternionRecord.identity
    /// Unassigned parts have no mass result; density is never inferred.
    var material: MaterialRecord? = nil

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AssemblyRecordError.invalidPart("A part must have a name.")
        }
        guard dimensionsMeters.isFinite,
            dimensionsMeters.x > 0, dimensionsMeters.y > 0, dimensionsMeters.z > 0
        else {
            throw AssemblyRecordError.invalidPart(
                "Block dimensions must be finite and greater than zero meters.")
        }
        guard positionMeters.isFinite else {
            throw AssemblyRecordError.invalidPart("Part positions must be finite values in meters.")
        }
        if material != nil { _ = try massProperties }
        let q = orientationLocalToAssembly
        guard q.isFinite else {
            throw AssemblyRecordError.invalidPart(
                "Part orientation must contain finite quaternion components.")
        }
        let normSquared = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w
        guard abs(normSquared - 1) <= 1e-10 else {
            throw AssemblyRecordError.invalidPart("Part orientation must be a unit quaternion.")
        }
    }
}

extension PartRecord {
    /// Uniform solid-block properties about the local center of mass.
    var massProperties: MassProperties? {
        get throws {
            guard let material else { return nil }
            return try Component.calculateMassProperties(
                geometry: Geometry(
                    rectangularBlockDimensionsMeters: SIMD3(
                        dimensionsMeters.x, dimensionsMeters.y, dimensionsMeters.z)),
                material: material.physicsMaterial())
        }
    }
}

struct MaterialRecord: Codable, Equatable, Sendable {
    var name: String
    var densityKgPerCubicMeter: Double
    var source: String

    func physicsMaterial() throws -> Material {
        try Material(name: name, densityKgPerCubicMeter: densityKgPerCubicMeter, source: source)
    }
}

struct Vector3Record: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double
    static let zero = Self(x: 0, y: 0, z: 0)
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

struct QuaternionRecord: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double
    var w: Double
    static let identity = Self(x: 0, y: 0, z: 0, w: 1)
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite && w.isFinite }
}

enum AssemblyRecordError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidPart(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return
                "This assembly uses unsupported file version \(version). Expected version \(AssemblyRecord.currentSchemaVersion)."
        case .invalidPart(let message):
            return message
        }
    }
}
