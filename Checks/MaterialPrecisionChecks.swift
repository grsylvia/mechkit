import Foundation
import SwiftUI

@main
struct MaterialPrecisionChecks {
    static func main() throws {
        func formatted(_ value: Double, _ digits: Int = 3) -> String {
            MaterialNumberFormat.string(value, significantFigures: digits)
        }
        precondition(MaterialNumberFormat.defaultSignificantFigures == 3)
        precondition(formatted(12.3456) == "12.3")
        precondition(formatted(12) == "12.0")
        precondition(formatted(0.012) == "0.0120")
        precondition(formatted(0) == "0.00")
        precondition(formatted(-12.3456) == "-12.3")
        precondition(formatted(123_456_789) == "1.23E8")
        precondition(formatted(0.000012345) == "1.23E-5")
        precondition(formatted(999.9) == "1.00E3")
        precondition(formatted(12.3456, 5) == "12.346")
        precondition(formatted(12.3456, 1) == "1E1")
        precondition(formatted(.leastNonzeroMagnitude) == "5.00E-324")
        precondition(formatted(.greatestFiniteMagnitude) == "1.80E308")
        precondition(formatted(.nan) == "—" && formatted(.infinity) == "—")
        for invalid in [Int.min, -1, 0, 16, Int.max] {
            precondition(MaterialNumberFormat.significantFigures(invalid) == 3)
            precondition(formatted(12.3456, invalid) == "12.3")
        }

        let suite = "mechkit.precision-checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preference = AppStorage(
            wrappedValue: MaterialNumberFormat.defaultSignificantFigures,
            MaterialNumberFormat.preferenceKey, store: defaults)
        precondition(preference.wrappedValue == 3)
        preference.wrappedValue = 7
        precondition(defaults.integer(forKey: MaterialNumberFormat.preferenceKey) == 7)
        let reopenedPreference = AppStorage(
            wrappedValue: MaterialNumberFormat.defaultSignificantFigures,
            MaterialNumberFormat.preferenceKey, store: defaults)
        precondition(reopenedPreference.wrappedValue == 7)
        preference.wrappedValue = -1
        precondition(MaterialNumberFormat.significantFigures(preference.wrappedValue) == 3)

        var part = AssemblyRecord.sample.parts[0]
        part.material = MaterialRecord(
            name: "Synthetic precision fixture", densityKgPerCubicMeter: 1234.56789012345,
            source: "MaterialPrecisionChecks analytical fixture")
        let before = try AssemblyRecord(parts: [part]).jsonData()
        let beforeMass = try part.massProperties
        var draft = PartDraft(part: part)
        let rawDensity = draft.material.densityKgPerCubicMeter
        for digits in MaterialNumberFormat.allowedSignificantFigures {
            _ = MaterialNumberFormat.densityText(
                rawDensity, isEditing: false, significantFigures: digits)
            precondition(
                MaterialNumberFormat.densityText(
                    rawDensity, isEditing: true, significantFigures: digits) == rawDensity)
            precondition(draft.material.densityKgPerCubicMeter == rawDensity)
        }
        for invalid in ["", "bad", "NaN", "inf"] {
            precondition(
                MaterialNumberFormat.densityText(
                    invalid, isEditing: false, significantFigures: 3) == invalid)
        }
        let after = try AssemblyRecord(parts: [part]).jsonData()
        precondition(before == after)
        draft.name = "Renamed without rounding density"
        let edited = try draft.applying(to: part)
        precondition(edited.material == part.material)
        let editedMass = try edited.massProperties
        precondition(editedMass == beforeMass)
        let document = AssemblyDocument(assembly: AssemblyRecord(parts: [edited]))
        let reopened = try AssemblyDocument(file: document.makeFileWrapper())
        precondition(reopened.assembly.parts[0].material == part.material)
        let reopenedMass = try reopened.assembly.parts[0].massProperties
        precondition(reopenedMass == beforeMass)
        print(
            "Material precision checks passed: defaults, persistence, rounding, scientific notation, trailing zeros, editing and unchanged document/physics values."
        )
    }
}
