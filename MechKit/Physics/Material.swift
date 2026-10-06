import Foundation

/// An explicitly supplied uniform-density material record. No production presets are assigned.
struct Material: Equatable {
    let name: String
    let densityKgPerCubicMeter: Double
    /// Citation, supplier record, or other provenance supplied with the density.
    let source: String

    init(name: String, densityKgPerCubicMeter: Double, source: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw PhysicsError.invalidMaterialName }
        guard densityKgPerCubicMeter.isFinite, densityKgPerCubicMeter > 0 else {
            throw PhysicsError.invalidDensity
        }
        guard !source.isEmpty else { throw PhysicsError.invalidMaterialSource }
        self.name = name
        self.densityKgPerCubicMeter = densityKgPerCubicMeter
        self.source = source
    }
}
