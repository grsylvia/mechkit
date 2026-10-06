import Foundation

@main
struct AssemblyChecks {
    static func main() throws {
        let sample = AssemblyRecord.sample
        let encoded = try sample.jsonData()
        let decoded = try AssemblyRecord(jsonData: encoded)
        precondition(decoded == sample)
        let empty = try AssemblyRecord(jsonData: AssemblyRecord().jsonData())
        precondition(empty.parts.isEmpty)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try encoded.write(to: url, options: .atomic)
        let reopened = try AssemblyRecord(jsonData: Data(contentsOf: url))
        precondition(reopened == sample)

        var record = sample
        record.schemaVersion = 99
        rejects { try record.validate() }
        record = sample
        record.parts.append(record.parts[0])
        rejects { try record.validate() }
        record = sample
        record.parts[0].name = "  "
        rejects { try record.validate() }
        for invalid in [0.0, -1.0, Double.nan, Double.infinity] {
            record = sample
            record.parts[0].dimensionsMeters.x = invalid
            rejects { try record.validate() }
        }
        for invalid in [Double.nan, Double.infinity, -Double.infinity] {
            record = sample
            record.parts[0].positionMeters.z = invalid
            rejects { try record.validate() }
        }
        for invalid in [0.0, 2.0, Double.nan, Double.infinity] {
            record = sample
            record.parts[0].orientationLocalToAssembly.w = invalid
            rejects { try record.validate() }
        }
        rejects { _ = try AssemblyRecord(jsonData: Data("{}".utf8)) }
        rejects { _ = try AssemblyRecord(jsonData: Data("not json".utf8)) }
        let text = String(decoding: encoded, as: UTF8.self)
        rejects {
            _ = try AssemblyRecord(
                jsonData: Data(text.replacingOccurrences(of: "0.12", with: "-0.12").utf8))
        }
        print(
            "Assembly checks passed: JSON and disk round trips, schema, IDs, names, dimensions, positions, quaternions, malformed inputs."
        )
    }

    static func rejects(_ operation: () throws -> Void) {
        do {
            try operation()
            preconditionFailure("Invalid assembly was accepted")
        } catch {}
    }
}
