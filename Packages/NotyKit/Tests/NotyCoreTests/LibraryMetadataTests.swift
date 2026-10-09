import Foundation
import Testing
@testable import NotyCore

@Suite struct LibraryMetadataTests {
    let library: Library

    init() throws {
        library = Library(root: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        try library.prepare()
    }

    @Test func favoritesAndRecentsSurviveMovingAndRenaming() throws {
        let folder = try library.createFolder(named: "Studio", in: library.root)
        let package = try library.createNotebook(title: "Chimica", in: library.root, paper: .grid)
        let manifest = try package.readManifest()

        var metadata = LibraryMetadata()
        metadata.toggleFavorite(manifest.id)
        metadata.markOpened(manifest.id, at: Date(timeIntervalSince1970: 1_760_000_000))
        try metadata.save(to: library)

        let moved = try library.move(.notebook(package.url, manifest), to: folder)
        try library.rename(.notebook(moved, try NotebookPackage(url: moved).readManifest()), to: "Chimica organica")

        let loaded = LibraryMetadata.load(from: library)
        #expect(loaded == metadata)
        #expect(library.notebooks(withIDs: loaded.favorites).map(\.name) == ["Chimica organica"])
    }

    @Test func recentsAreOrderedAndCapped() {
        var metadata = LibraryMetadata()
        let ids = (0..<25).map { _ in UUID() }
        for id in ids {
            metadata.markOpened(id)
        }
        metadata.markOpened(ids[10])

        #expect(metadata.recents.count == LibraryMetadata.recentLimit)
        #expect(metadata.recents.first?.id == ids[10])
        #expect(metadata.recents[1].id == ids[24])
    }

    @Test func toggleFavoriteAddsAndRemoves() {
        var metadata = LibraryMetadata()
        let id = UUID()
        metadata.toggleFavorite(id)
        #expect(metadata.isFavorite(id))
        metadata.toggleFavorite(id)
        #expect(!metadata.isFavorite(id))
    }

    @Test func searchFindsNestedItemsIgnoringCaseAndAccents() throws {
        let uni = try library.createFolder(named: "Università", in: library.root)
        let analisi = try library.createFolder(named: "Analisi", in: uni)
        try library.createNotebook(title: "Esercizi di analisi", in: analisi, paper: .grid)
        try library.createNotebook(title: "Fisica", in: uni, paper: .lined)

        #expect(Set(library.search("ANALISI").map(\.name)) == ["Analisi", "Esercizi di analisi"])
        #expect(library.search("universita").map(\.name) == ["Università"])
        #expect(library.search("  ").isEmpty)
        #expect(library.allEntries().count == 4)
    }

    @Test func metadataFileIsHiddenFromTheLibrary() throws {
        try LibraryMetadata().save(to: library)
        #expect(try library.contents(of: library.root).isEmpty)
    }
}
