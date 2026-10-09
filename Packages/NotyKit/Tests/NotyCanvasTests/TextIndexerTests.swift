import CoreGraphics
import Foundation
import Testing
@testable import NotyCanvas
@testable import NotyCore

@Suite struct TextIndexerTests {
    @Test func indexesTextOnPagesAndSkipsUnchangedOnes() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).noty")
        let manifest = NotebookManifest(title: "Fisica", paper: .lined, pageIDs: [UUID(), UUID()])
        let package = try NotebookPackage.create(at: url, manifest: manifest)
        let element = PageElement(
            content: .text(string: "Teorema di Pitagora", fontSize: 32, colorHex: "#000000"),
            frame: CGRect(x: 60, y: 100, width: 460, height: 60)
        )
        try package.writeElements([element], page: manifest.pageIDs[1])

        try await TextIndexer.update(package)
        let index = package.readTextIndex()
        #expect(index.pages[manifest.pageIDs[0]] == nil, "Blank pages are not indexed")
        #expect(index.pages(matching: "pitagora", order: manifest.pageIDs) == [1])

        // A second run with no changes keeps the same file.
        let before = try Data(contentsOf: url.appending(path: "text-index.json"))
        try await TextIndexer.update(package)
        #expect(try Data(contentsOf: url.appending(path: "text-index.json")) == before)
    }

    @Test func lockedNotebooksHaveNoIndex() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).noty")
        var manifest = NotebookManifest(title: "Diario", paper: .blank)
        let package = try NotebookPackage.create(at: url, manifest: manifest)
        try package.writeTextIndex(TextIndex())
        manifest.isLocked = true
        try package.writeManifest(manifest)

        try await TextIndexer.update(package)
        #expect(!FileManager.default.fileExists(atPath: url.appending(path: "text-index.json").path(percentEncoded: false)))
    }
}
