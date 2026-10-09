import NotyCore
import Observation
import SwiftUI
import os

private let log = Logger(subsystem: "io.github.paluello.noty", category: "library")

enum SortOrder: String, CaseIterable, Identifiable {
    case modified, created, name

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .modified: "Date Modified"
        case .created: "Date Created"
        case .name: "Name"
        }
    }
}

/// Observable front of `Library` for the UI. Every change bumps `revision`,
/// so views that read the library refresh.
@MainActor @Observable
final class LibraryStore {
    let library: Library
    private(set) var revision = 0
    var errorMessage: String?

    init() {
        // The app's Documents folder is visible in the Files app (DAT-5, ADR-0005).
        library = Library(root: URL.documentsDirectory)
        do {
            try library.prepare()
        } catch {
            log.error("Failed to prepare library: \(error)")
        }
        library.purgeExpiredTrash()
    }

    var root: URL { library.root }

    // MARK: - Reading

    func items(in folder: URL, sortedBy order: SortOrder) -> [LibraryEntry] {
        _ = revision
        let items = (try? library.contents(of: folder)) ?? []
        let folders = items.filter { if case .folder = $0 { true } else { false } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let notebooks = items.filter { if case .notebook = $0 { true } else { false } }
            .sorted { lhs, rhs in
                switch order {
                case .name: lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                case .modified: lhs.modifiedAt > rhs.modifiedAt
                case .created: Self.createdAt(lhs) > Self.createdAt(rhs)
                }
            }
        return folders + notebooks
    }

    private static func createdAt(_ item: LibraryEntry) -> Date {
        if case .notebook(_, let manifest) = item { manifest.createdAt } else { .distantPast }
    }

    func itemCount(in folder: URL) -> Int {
        _ = revision
        return (try? library.contents(of: folder).count) ?? 0
    }

    func folderTree() -> FolderNode {
        _ = revision
        return library.folderTree()
    }

    func trashedItems() -> [TrashedItem] {
        _ = revision
        return library.trashedItems()
    }

    func displayName(of folder: URL) -> String {
        folder.standardizedFileURL == root.standardizedFileURL
            ? String(localized: "Library")
            : folder.lastPathComponent
    }

    // MARK: - Changing

    @discardableResult
    private func perform<T>(_ action: () throws -> T) -> T? {
        defer { revision += 1 }
        do {
            return try action()
        } catch {
            log.error("Library operation failed: \(error)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func createFolder(named name: String, in parent: URL) -> URL? {
        perform { try library.createFolder(named: name, in: parent) }
    }

    func createNotebook(title: String, in parent: URL, paper: PaperStyle, orientation: PageOrientation, cover: CoverDraft) -> NotebookPackage? {
        perform {
            let package = try library.createNotebook(title: title, in: parent, paper: paper, orientation: orientation, cover: .color(index: 0))
            try applyCover(cover, to: package)
            return package
        }
    }

    func rename(_ item: LibraryEntry, to name: String) {
        perform { try library.rename(item, to: name) }
    }

    func move(_ item: LibraryEntry, to folder: URL) {
        perform { try library.move(item, to: folder) }
    }

    func move(url: URL, to folder: URL) {
        guard let item = try? library.contents(of: url.deletingLastPathComponent()).first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { return }
        move(item, to: folder)
    }

    func duplicate(_ item: LibraryEntry) {
        perform { try library.duplicate(item) }
    }

    func moveToTrash(_ item: LibraryEntry) {
        perform { try library.moveToTrash(item) }
    }

    func restore(_ trashed: TrashedItem) {
        perform { try library.restore(trashed) }
    }

    func deleteForever(_ trashed: TrashedItem) {
        perform { try library.deleteForever(trashed) }
    }

    func emptyTrash() {
        perform { try library.emptyTrash() }
    }

    func setCover(_ cover: CoverDraft, of url: URL) {
        perform { try applyCover(cover, to: NotebookPackage(url: url)) }
    }

    /// Call after a notebook was edited, so covers and page counts refresh.
    func notebookDidChange() {
        revision += 1
    }

    private func applyCover(_ draft: CoverDraft, to package: NotebookPackage) throws {
        var manifest = try package.readManifest()
        switch draft {
        case .color(let index):
            manifest.cover = .color(index: index)
        case .image(let data):
            manifest.cover = try package.writeCoverImage(data, fileExtension: "jpg")
        case .existing(let cover):
            manifest.cover = cover
        }
        manifest.modifiedAt = .now
        try package.writeManifest(manifest)
        package.removeUnusedCoverImages(keeping: manifest.cover)
    }
}
