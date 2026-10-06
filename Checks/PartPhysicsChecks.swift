import Foundation

@main
struct PartPhysicsChecks {
    static func close(_ actual: Double, _ expected: Double) {
        precondition(abs(actual - expected) < max(abs(expected) * 1e-12, 1e-14))
    }

    static func rejects(_ operation: () throws -> Void) {
        do {
            try operation()
            preconditionFailure("Invalid material or derived properties were accepted")
        } catch {}
    }

    static func main() throws {
        let original = AssemblyRecord.sample.parts[0]
        let unassigned = try original.massProperties
        precondition(unassigned == nil)
        var draft = PartDraft(part: original)
        draft.dimensions = VectorDraft(Vector3Record(x: 0.2, y: 0.3, z: 0.4))
        draft.material.isAssigned = true
        draft.material.name = " Synthetic fixture "
        draft.material.densityKgPerCubicMeter = "500"
        draft.material.source = " PartPhysicsChecks analytical fixture "
        let assigned = try draft.applying(to: original)
        precondition(assigned.id == original.id)
        precondition(assigned.material?.name == "Synthetic fixture")
        precondition(assigned.material?.source == "PartPhysicsChecks analytical fixture")
        let properties = try assigned.massProperties!
        close(properties.volumeCubicMeters, 0.024)
        close(properties.massKilograms, 12)
        let inertia = properties.inertiaTensorAboutCenterOfMassLocal
        close(inertia.xxKgMetersSquared, 0.25)
        close(inertia.yyKgMetersSquared, 0.20)
        close(inertia.zzKgMetersSquared, 0.13)

        var densityEdit = PartDraft(part: assigned)
        densityEdit.material.densityKgPerCubicMeter = "1000"
        let denser = try densityEdit.applying(to: assigned)
        let denserProperties = try denser.massProperties!
        close(denserProperties.massKilograms, 24)
        close(denserProperties.inertiaTensorAboutCenterOfMassLocal.xxKgMetersSquared, 0.5)
        var sizeEdit = PartDraft(part: assigned)
        sizeEdit.dimensions = VectorDraft(Vector3Record(x: 0.4, y: 0.6, z: 0.8))
        let larger = try sizeEdit.applying(to: assigned)
        let largerProperties = try larger.massProperties!
        close(largerProperties.massKilograms, 96)
        close(largerProperties.inertiaTensorAboutCenterOfMassLocal.xxKgMetersSquared, 8)
        var moved = assigned
        moved.positionMeters = Vector3Record(x: 1, y: -2, z: 3)
        moved.orientationLocalToAssembly = QuaternionRecord(x: 0, y: 0, z: sqrt(0.5), w: sqrt(0.5))
        let movedProperties = try moved.massProperties
        precondition(movedProperties == properties)

        var second = original
        second.id = UUID()
        let document = AssemblyDocument(assembly: AssemblyRecord(parts: [moved, second]))
        let wrapper = try document.makeFileWrapper()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).mechkit")
        defer { try? FileManager.default.removeItem(at: url) }
        try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        let reopened = try AssemblyDocument(file: FileWrapper(url: url))
        precondition(reopened.assembly == document.assembly)
        let reopenedProperties = try reopened.assembly.parts[0].massProperties
        precondition(reopenedProperties == properties)
        precondition(reopened.assembly.parts[1].material == nil)

        for invalid in ["", "NaN", "inf", "-inf", "0", "-1", "5e-324"] {
            var overflowing = PartDraft(part: assigned)
            overflowing.dimensions = VectorDraft(Vector3Record(x: 1000, y: 1000, z: 1000))
            overflowing.material.densityKgPerCubicMeter = "1e300"
            rejects { _ = try overflowing.applying(to: assigned) }
            var bad = PartDraft(part: assigned)
            bad.material.densityKgPerCubicMeter = invalid
            rejects { _ = try bad.applying(to: assigned) }
        }
        var bad = PartDraft(part: assigned)
        bad.material.name = " "
        rejects { _ = try bad.applying(to: assigned) }
        bad = PartDraft(part: assigned)
        bad.material.source = " "
        rejects { _ = try bad.applying(to: assigned) }
        var invalidSaved = assigned
        invalidSaved.material?.densityKgPerCubicMeter = -1
        let invalidJSON = try JSONEncoder().encode(AssemblyRecord(parts: [invalidSaved]))
        rejects { _ = try AssemblyRecord(jsonData: invalidJSON) }
        rejects { _ = try AssemblyRecord(parts: [invalidSaved]).jsonData() }

        var removal = PartDraft(part: assigned)
        removal.material.isAssigned = false
        let removed = try removal.applying(to: assigned)
        precondition(removed.id == assigned.id && removed.material == nil)
        let removedProperties = try removed.massProperties
        precondition(removedProperties == nil)
        precondition(original.material == nil && assigned.material?.densityKgPerCubicMeter == 500)
        print(
            "Part physics checks passed: analytical values, edits, unset material, pose independence, save/reopen and invalid data."
        )
    }
}
