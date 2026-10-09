import Foundation
import Testing
@testable import NotyCanvas
@testable import NotyCore

@Suite struct LibraryExporterTests {
    @Test func exportsAZipWithEveryNotebook() throws {
        let library = Library(root: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        try library.prepare()
        let folder = try library.createFolder(named: "Studio", in: library.root)
        let notebook = try library.createNotebook(title: "Analisi", in: folder, paper: .grid)
        try library.createNotebook(title: "Diario", in: library.root, paper: .blank)
        try library.moveToTrash(.notebook(notebook.url, try notebook.readManifest()))
        try library.createNotebook(title: "Fisica", in: folder, paper: .lined)

        let zip = try LibraryExporter.exportAll(library, date: Date(timeIntervalSince1970: 1_760_000_000))

        #expect(zip.lastPathComponent == "Noty 2025-10-09.zip")
        let data = try Data(contentsOf: zip)
        // A zip starts with "PK" and lists its entries' names in plain text.
        #expect(data.prefix(2) == Data("PK".utf8))
        let listing = String(decoding: data, as: UTF8.self)
        #expect(listing.contains("Studio/Fisica.pdf"))
        #expect(listing.contains("Studio/Fisica.noty/notebook.json"))
        #expect(listing.contains("Diario.pdf"))
        #expect(!listing.contains("Analisi"), "Trashed notebooks are not exported")
    }
}
