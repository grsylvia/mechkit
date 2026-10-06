import Foundation
import simd

@main
struct RotationChecks {
    static func quaternion(_ value: QuaternionRecord) -> simd_quatd {
        simd_quatd(vector: SIMD4(value.x, value.y, value.z, value.w))
    }

    static func close(_ actual: SIMD3<Double>, _ expected: SIMD3<Double>, tolerance: Double = 1e-10)
    {
        precondition(
            simd_length(actual - expected) <= tolerance,
            "Rotation disagrees with expected axis mapping")
    }

    static func sameRotation(
        _ first: QuaternionRecord, _ second: QuaternionRecord, tolerance: Double = 1e-10
    ) {
        for axis in [SIMD3<Double>(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)] {
            close(quaternion(first).act(axis), quaternion(second).act(axis), tolerance: tolerance)
        }
    }

    static func main() throws {
        let x = try PartRotation.orientation(fromDegrees: Vector3Record(x: 90, y: 0, z: 0))
        close(quaternion(x).act(SIMD3(0, 1, 0)), SIMD3(0, 0, 1))
        let y = try PartRotation.orientation(fromDegrees: Vector3Record(x: 0, y: 90, z: 0))
        close(quaternion(y).act(SIMD3(0, 0, 1)), SIMD3(1, 0, 0))
        let z = try PartRotation.orientation(fromDegrees: Vector3Record(x: 0, y: 0, z: 90))
        close(quaternion(z).act(SIMD3(1, 0, 0)), SIMD3(0, 1, 0))
        let xyz = try PartRotation.orientation(fromDegrees: Vector3Record(x: 90, y: 90, z: 90))
        close(quaternion(xyz).act(SIMD3(1, 0, 0)), SIMD3(0, 0, -1))
        close(quaternion(xyz).act(SIMD3(0, 1, 0)), SIMD3(0, 1, 0))
        close(quaternion(xyz).act(SIMD3(0, 0, 1)), SIMD3(1, 0, 0))
        let wrapped = try PartRotation.orientation(
            fromDegrees: Vector3Record(x: 360, y: -720, z: 450))
        sameRotation(wrapped, z)

        for roll: Double in [0, 37, -120] {
            for pitch: Double in [-90, -60, 0, 60, 90, 120, 270] {
                for yaw: Double in [0, 90, -44, 180] {
                    let original = try PartRotation.orientation(
                        fromDegrees: Vector3Record(x: roll, y: pitch, z: yaw))
                    let angles = PartRotation.degrees(from: original)
                    precondition(
                        angles.isFinite && angles.y >= -90.0000001 && angles.y <= 90.0000001)
                    let rebuilt = try PartRotation.orientation(fromDegrees: angles)
                    sameRotation(original, rebuilt)
                    if abs(abs(pitch) - 90) < 1e-12 { precondition(angles.x == 0) }
                }
            }
        }
        for pitch: Double in [-89.9999999, 89.9999999] {
            let original = try PartRotation.orientation(
                fromDegrees: Vector3Record(x: 37, y: pitch, z: -44))
            let rebuilt = try PartRotation.orientation(
                fromDegrees: PartRotation.degrees(from: original))
            sameRotation(original, rebuilt, tolerance: 1e-7)
        }

        var part = AssemblyRecord.sample.parts[0]
        part.material = MaterialRecord(
            name: "Synthetic fixture", densityKgPerCubicMeter: 500,
            source: "RotationChecks analytical fixture")
        let originalMass = try part.massProperties
        var draft = PartDraft(part: part)
        draft.rotationDegrees.z = "90"
        let edited = try draft.applying(to: part)
        precondition(edited.id == part.id && edited.positionMeters == part.positionMeters)
        precondition(
            edited.dimensionsMeters == part.dimensionsMeters && edited.material == part.material)
        let editedMass = try edited.massProperties
        precondition(editedMass == originalMass)
        sameRotation(edited.orientationLocalToAssembly, z)
        let rendered = try PartRenderValues(part: edited)
        precondition(
            simd_length(rendered.orientation.act(SIMD3<Float>(1, 0, 0)) - SIMD3(0, 1, 0)) < 1e-5)

        var otherEdit = PartDraft(part: edited)
        otherEdit.name = "Rotated block"
        let renamed = try otherEdit.applying(to: edited)
        precondition(renamed.orientationLocalToAssembly == edited.orientationLocalToAssembly)
        let document = AssemblyDocument(assembly: AssemblyRecord(parts: [renamed]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).mechkit")
        defer { try? FileManager.default.removeItem(at: url) }
        try document.makeFileWrapper().write(to: url, options: .atomic, originalContentsURL: nil)
        let reopened = try AssemblyDocument(file: FileWrapper(url: url))
        precondition(reopened.assembly == document.assembly)
        sameRotation(reopened.assembly.parts[0].orientationLocalToAssembly, z)

        for invalid in ["NaN", "inf", "-inf", "", "bad"] {
            var bad = PartDraft(part: edited)
            bad.rotationDegrees.x = invalid
            do {
                _ = try bad.applying(to: edited)
                preconditionFailure("Invalid rotation was accepted")
            } catch {}
        }
        print(
            "Rotation checks passed: Z-up axis signs, XYZ order, angle wrapping, singularities, unchanged local mass, rendering and save/reopen."
        )
    }
}
