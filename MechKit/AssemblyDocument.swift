import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let mechkitAssembly = UTType(
        exportedAs: "com.gsylvia.mechkit.assembly", conformingTo: .json)
}

/// Value semantics let DocumentGroup track edits, autosave, and register undo through its binding.
struct AssemblyDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.mechkitAssembly] }
    var assembly: AssemblyRecord

    init(assembly: AssemblyRecord = .sample) {
        self.assembly = assembly
    }

    init(configuration: ReadConfiguration) throws {
        try self.init(file: configuration.file)
    }

    init(file: FileWrapper) throws {
        guard file.isRegularFile, let data = file.regularFileContents else {
            throw AssemblyDocumentError.notRegularFile
        }
        do {
            assembly = try AssemblyRecord(jsonData: data)
        } catch is DecodingError {
            throw AssemblyDocumentError.invalidJSON
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try makeFileWrapper()
    }

    func makeFileWrapper() throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try assembly.jsonData())
    }
}

enum AssemblyDocumentError: LocalizedError {
    case notRegularFile
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .notRegularFile:
            "This assembly is not a regular file. Choose a .mechkit assembly file."
        case .invalidJSON:
            "This assembly contains malformed JSON or missing or invalid fields."
        }
    }
}
