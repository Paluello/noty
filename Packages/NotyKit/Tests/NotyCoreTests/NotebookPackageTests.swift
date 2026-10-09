import Foundation
import Testing
@testable import NotyCore

@Suite struct NotebookPackageTests {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @Test func manifestRoundTrips() throws {
        // Dates are stored as ISO 8601, with one-second precision.
        let created = Date(timeIntervalSince1970: 1_760_000_000)
        let manifest = NotebookManifest(title: "Analisi 1", cover: .color(index: 3), paper: .grid, createdAt: created)
        let package = try NotebookPackage.create(at: root.appending(path: "Analisi 1.noty"), manifest: manifest)

        #expect(try package.readManifest() == manifest)
    }

    @Test func createRefusesToOverwrite() throws {
        let url = root.appending(path: "Fisica.noty")
        try NotebookPackage.create(at: url, manifest: NotebookManifest(title: "Fisica", paper: .lined))

        #expect(throws: NotebookPackageError.alreadyExists(url)) {
            try NotebookPackage.create(at: url, manifest: NotebookManifest(title: "Fisica", paper: .lined))
        }
    }

    @Test func pagesAreStoredIndependently() throws {
        let manifest = NotebookManifest(title: "Inglese", paper: .dotted, pageIDs: [UUID(), UUID()])
        let package = try NotebookPackage.create(at: root.appending(path: "Inglese.noty"), manifest: manifest)
        let first = manifest.pageIDs[0], second = manifest.pageIDs[1]

        #expect(try package.readPage(first) == nil)

        try package.writePage(first, data: Data([1, 2, 3]))
        try package.writePage(second, data: Data([4]))
        try package.writePage(first, data: Data([9]))

        #expect(try package.readPage(first) == Data([9]))
        #expect(try package.readPage(second) == Data([4]))

        try package.deletePage(second)
        #expect(try package.readPage(second) == nil)
    }

    @Test func rejectsNewerFormatVersions() throws {
        var manifest = NotebookManifest(title: "Futuro", paper: .blank)
        manifest.formatVersion = NotebookManifest.currentFormatVersion + 1
        let package = try NotebookPackage.create(at: root.appending(path: "Futuro.noty"), manifest: manifest)

        #expect(throws: NotebookPackageError.unsupportedFormatVersion(manifest.formatVersion)) {
            try package.readManifest()
        }
    }
}
