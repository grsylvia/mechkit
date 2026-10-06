import Foundation
import simd

@main
struct EditingChecks {
    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }

    static func expectRejected(_ message: String, _ operation: () throws -> Void) {
        do {
            try operation()
            fatalError(message)
        } catch {}
    }

    static func main() throws {
        var part = AssemblyRecord.sample.parts[0]
        part.orientationLocalToAssembly = QuaternionRecord(x: 0, y: 0, z: sqrt(0.5), w: sqrt(0.5))
        var draft = PartDraft(part: part)
        draft.name = "  Bracket  "
        draft.dimensions.x = "2.4e-1"
        draft.position.y = "-0.25"
        let edited = try draft.applying(to: part)
        expect(edited.name == "Bracket", "Names trim surrounding whitespace")
        expect(edited.dimensionsMeters.x == 0.24, "Scientific notation uses meters")
        expect(edited.positionMeters.y == -0.25, "Negative positions remain valid")
        expect(edited.id == part.id, "Editing preserves identity")
        expect(
            edited.orientationLocalToAssembly == part.orientationLocalToAssembly,
            "Editing preserves rotation")
        let values = try PartRenderValues(part: edited)
        expect(
            abs(values.orientation.act(SIMD3<Float>(1, 0, 0)).y - 1) < 0.00001,
            "Rotation maps local X to assembly Y")
        expect(abs(values.dimensionsMeters.x - 0.24) < 0.00001, "Renderer dimensions use meters")
        expect(values.positionMeters.y == -0.25, "Renderer positions use assembly coordinates")

        for invalid in ["0", "-1", "NaN", "inf", "-inf", "", "not a number", "1e300", "1e-100"] {
            var candidate = draft
            candidate.dimensions.z = invalid
            expectRejected("Invalid dimension must not commit: \(invalid)") {
                _ = try candidate.applying(to: part)
            }
        }
        for invalid in ["NaN", "inf", "-inf", "", "1e300", "1e-100"] {
            var candidate = draft
            candidate.position.x = invalid
            expectRejected("Invalid position must not commit: \(invalid)") {
                _ = try candidate.applying(to: part)
            }
        }
        var unnamed = draft
        unnamed.name = " \n "
        expectRejected("Empty names must not commit") { _ = try unnamed.applying(to: part) }

        var enormous = part
        enormous.dimensionsMeters.x = 2.5e38
        enormous.positionMeters.x = 2.5e38
        enormous.orientationLocalToAssembly = .identity
        try enormous.validate()  // A finite design record can exceed renderer precision.
        expectRejected("Transformed corners must remain finite") {
            _ = try PartRenderValues(part: enormous)
        }
        print(
            "Editing checks passed: draft validation, meters, identity, rotation, and render limits."
        )
    }
}
