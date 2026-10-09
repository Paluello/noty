import Foundation
import Testing
@testable import NotyCore

@Suite struct LibraryTests {
    let library: Library

    init() throws {
        library = Library(root: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        try library.prepare()
    }

    private func names(in folder: URL) throws -> [String] {
        try library.contents(of: folder).map(\.name).sorted()
    }

    @Test func createsFoldersAndNotebooksWithUniqueNames() throws {
        let studio = try library.createFolder(named: "Studio", in: library.root)
        try library.createFolder(named: "Studio", in: library.root)
        try library.createNotebook(title: "Analisi", in: studio, paper: .grid)
        try library.createNotebook(title: "Analisi", in: studio, paper: .grid)

        #expect(try names(in: library.root) == ["Studio", "Studio 2"])
        #expect(try names(in: studio) == ["Analisi", "Analisi 2"])
    }

    @Test func sanitizesNames() throws {
        let url = try library.createFolder(named: "  ../a/b:c ", in: library.root)
        #expect(url.lastPathComponent == "-a-b-c")
    }

    @Test func renamesNotebookFolderAndTitle() throws {
        let package = try library.createNotebook(title: "Fisca", in: library.root, paper: .lined)
        let item = LibraryEntry.notebook(package.url, try package.readManifest())

        let renamed = try library.rename(item, to: "Fisica")

        #expect(renamed.lastPathComponent == "Fisica.noty")
        #expect(try NotebookPackage(url: renamed).readManifest().title == "Fisica")
    }

    @Test func movesItemsButNotAFolderIntoItself() throws {
        let a = try library.createFolder(named: "A", in: library.root)
        let b = try library.createFolder(named: "B", in: a)
        let package = try library.createNotebook(title: "Note", in: library.root, paper: .blank)

        let moved = try library.move(.notebook(package.url, try package.readManifest()), to: b)
        #expect(try names(in: b) == ["Note"])
        #expect(moved.deletingLastPathComponent().lastPathComponent == "B")

        #expect(throws: (any Error).self) {
            try library.move(.folder(a), to: b)
        }
    }

    @Test func duplicateGetsNewIdentity() throws {
        let package = try library.createNotebook(title: "Inglese", in: library.root, paper: .dotted)
        let original = try package.readManifest()

        let copyURL = try library.duplicate(.notebook(package.url, original))
        let copy = try NotebookPackage(url: copyURL).readManifest()

        #expect(copy.id != original.id)
        #expect(copy.pageIDs == original.pageIDs)
        #expect(copy.title != original.title)
    }

    @Test func trashRestoresToOriginalFolder() throws {
        let folder = try library.createFolder(named: "Studio", in: library.root)
        let package = try library.createNotebook(title: "Chimica", in: folder, paper: .grid)

        try library.moveToTrash(.notebook(package.url, try package.readManifest()))
        #expect(try names(in: folder).isEmpty)

        let trashed = try #require(library.trashedItems().first)
        #expect(trashed.item.name == "Chimica")

        try library.restore(trashed)
        #expect(try names(in: folder) == ["Chimica"])
        #expect(library.trashedItems().isEmpty)
    }

    @Test func purgesOnlyExpiredTrash() throws {
        let package = try library.createNotebook(title: "Vecchio", in: library.root, paper: .blank)
        try library.moveToTrash(.notebook(package.url, try package.readManifest()))

        library.purgeExpiredTrash(now: .now.addingTimeInterval(60))
        #expect(library.trashedItems().count == 1)

        library.purgeExpiredTrash(now: .now.addingTimeInterval(Library.trashRetention + 60))
        #expect(library.trashedItems().isEmpty)
    }

    @Test func folderTreeAndAncestry() throws {
        let a = try library.createFolder(named: "A", in: library.root)
        let b = try library.createFolder(named: "B", in: a)
        try library.createNotebook(title: "Note", in: b, paper: .blank)

        let tree = library.folderTree()
        #expect(tree.children.map(\.name) == ["A"])
        #expect(tree.children[0].children.map(\.name) == ["B"])
        #expect(tree.children[0].children[0].childrenOrNil == nil)

        #expect(library.ancestry(of: b).map(\.lastPathComponent) == [library.root.lastPathComponent, "A", "B"])
    }
}
