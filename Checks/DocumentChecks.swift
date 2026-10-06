import Foundation

@main
struct DocumentChecks {
    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }

    static func expectError(_ description: String, _ body: () throws -> Void) {
        do {
            try body()
            fatalError("Expected an error: \(description)")
        } catch {
            expect(!error.localizedDescription.isEmpty, "Errors must explain the failure")
        }
    }

    static func main() throws {
        let first = AssemblyDocument()
        var second = AssemblyDocument()
        expect(
            first.assembly.parts[0].id != second.assembly.parts[0].id,
            "New documents need independent part identities")
        second.assembly.parts[0].name = "Independent assembly"
        expect(
            first.assembly.parts[0].name == "Sample block",
            "Editing one value document cannot change another")

        var edited = first
        edited.assembly.parts[0].name = "Saved block"
        edited.assembly.parts[0].positionMeters.x = 0.15
        edited.assembly.parts[0].positionMeters.y = -0.07
        edited.assembly.parts[0].orientationLocalToAssembly = QuaternionRecord(
            x: 0, y: 0, z: sqrt(0.5), w: sqrt(0.5))
        edited.assembly.parts.append(
            PartRecord(
                name: "Second block", dimensionsMeters: Vector3Record(x: 0.03, y: 0.04, z: 0.05)))

        let wrapper = try edited.makeFileWrapper()
        let reopened = try AssemblyDocument(file: wrapper)
        expect(
            reopened.assembly == edited.assembly,
            "Document FileWrapper must preserve every assembly field")
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("mechkit-documents-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Assembly.mechkit")
        try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        let diskDocument = try AssemblyDocument(file: FileWrapper(url: url))
        expect(diskDocument.assembly == edited.assembly, "Save and reopen must preserve edits")

        expectError("directory instead of regular file") {
            _ = try AssemblyDocument(file: FileWrapper(directoryWithFileWrappers: [:]))
        }
        expectError("malformed JSON") {
            _ = try AssemblyDocument(file: FileWrapper(regularFileWithContents: Data("{".utf8)))
        }
        expectError("missing fields") {
            _ = try AssemblyDocument(file: FileWrapper(regularFileWithContents: Data("{}".utf8)))
        }
        var future = edited
        future.assembly.schemaVersion += 1
        expectError("invalid save schema") { _ = try future.makeFileWrapper() }
        let futureData = try JSONEncoder().encode(future.assembly)
        expectError("unsupported read schema") {
            _ = try AssemblyDocument(file: FileWrapper(regularFileWithContents: futureData))
        }
        var duplicates = edited
        duplicates.assembly.parts.append(duplicates.assembly.parts[0])
        let duplicateData = try JSONEncoder().encode(duplicates.assembly)
        expectError("duplicate identifiers on read") {
            _ = try AssemblyDocument(file: FileWrapper(regularFileWithContents: duplicateData))
        }
        expectError("duplicate identifiers on save") { _ = try duplicates.makeFileWrapper() }
        var invalid = edited
        invalid.assembly.parts[0].dimensionsMeters.x = 0
        expectError("invalid geometry on save") { _ = try invalid.makeFileWrapper() }
        let invalidData = try JSONEncoder().encode(invalid.assembly)
        expectError("invalid geometry on read") {
            _ = try AssemblyDocument(file: FileWrapper(regularFileWithContents: invalidData))
        }
        invalid.assembly.parts[0].positionMeters.x = .infinity
        expectError("non-finite save position") { _ = try invalid.makeFileWrapper() }
        let empty = AssemblyDocument(assembly: AssemblyRecord())
        expect(
            try AssemblyDocument(file: empty.makeFileWrapper()).assembly.parts.isEmpty,
            "Empty assemblies can be saved and reopened")
        print(
            "Document checks passed: independent values, save/reopen, wrappers, schema and input errors."
        )
    }
}
