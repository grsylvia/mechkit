import Foundation

/// Display precision never changes persisted or calculated Double values.
enum MaterialNumberFormat {
    static let preferenceKey = "materialSignificantFigures"
    static let defaultSignificantFigures = 3
    static let allowedSignificantFigures = 1...15

    static func significantFigures(_ preference: Int) -> Int {
        allowedSignificantFigures.contains(preference) ? preference : defaultSignificantFigures
    }

    static func string(_ value: Double, significantFigures preference: Int) -> String {
        guard value.isFinite else { return "—" }
        let digits = significantFigures(preference)
        let style = FloatingPointFormatStyle<Double>.number
            .precision(.significantDigits(digits...digits))
            .grouping(.never)
            .locale(Locale(identifier: "en_US_POSIX"))
        let magnitude = abs(value)
        // Include values that round across the next power of ten, such as 999.9 at 3 figures.
        let scientificThreshold = pow(10, Double(digits)) - 0.5
        if magnitude >= scientificThreshold || (magnitude > 0 && magnitude < 0.001) {
            return value.formatted(style.notation(.scientific))
        }
        return value.formatted(style)
    }

    static func densityText(_ text: String, isEditing: Bool, significantFigures: Int) -> String {
        guard !isEditing, let value = Double(text), value.isFinite else { return text }
        return string(value, significantFigures: significantFigures)
    }
}
