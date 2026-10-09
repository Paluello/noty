import NotyCanvas
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
    private(set) var library: Library
    private(set) var revision = 0
    private(set) var metadata: LibraryMetadata
    /// Notebooks open in an editor, in any window: each is edited in one place only.
    var openNotebooks: Set<URL> = []
    var errorMessage: String?

    init() {
        // The app's Documents folder is visible in the Files app (DAT-5, ADR-0005),
        // unless the user picked another folder: iCloud Drive, a NAS… (ADR-0018).
        let library = Library(root: Self.resolveChosenFolder() ?? URL.documentsDirectory)
        do {
            try library.prepare()
        } catch {
            log.error("Failed to prepare library: \(error)")
        }
        library.purgeExpiredTrash()
        self.library = library
        metadata = LibraryMetadata.load(from: library)
    }

    var root: URL { library.root }

    // MARK: - Library location (ADR-0018)

    /// True when the library lives in a folder the user chose.
    var usesChosenFolder: Bool {
        library.root != Library.normalized(URL.documentsDirectory)
    }

    var locationName: String {
        usesChosenFolder ? library.root.lastPathComponent : String(localized: "On this iPad")
    }

    private static func resolveChosenFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: SettingsKey.libraryBookmark) else { return nil }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale),
              url.startAccessingSecurityScopedResource()
        else {
            log.error("The chosen library folder is not reachable; using the iPad's storage")
            return nil
        }
        if isStale, let fresh = try? url.bookmarkData() {
            UserDefaults.standard.set(fresh, forKey: SettingsKey.libraryBookmark)
        }
        return url
    }

    /// Moves the library to a folder picked in Files, optionally copying the current notebooks there.
    func useFolder(_ url: URL, copyingCurrentLibrary: Bool) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = String(localized: "Noty can't use this folder.")
            return
        }
        perform {
            let bookmark = try url.bookmarkData()
            let destination = Library(root: url)
            try destination.prepare()
            if copyingCurrentLibrary {
                let fm = FileManager.default
                let items = try fm.contentsOfDirectory(at: library.root, includingPropertiesForKeys: nil)
                for item in items where !item.lastPathComponent.hasPrefix(".") || item.lastPathComponent == LibraryMetadata.fileName {
                    let target = destination.root.appending(path: item.lastPathComponent)
                    if !fm.fileExists(atPath: target.path(percentEncoded: false)) {
                        try fm.copyItem(at: item, to: target)
                    }
                }
            }
            UserDefaults.standard.set(bookmark, forKey: SettingsKey.libraryBookmark)
            switchTo(destination)
        }
    }

    /// Back to the library inside the app (On My iPad › Noty).
    func useDeviceStorage() {
        if usesChosenFolder {
            library.root.stopAccessingSecurityScopedResource()
        }
        UserDefaults.standard.removeObject(forKey: SettingsKey.libraryBookmark)
        perform {
            let local = Library(root: URL.documentsDirectory)
            try local.prepare()
            switchTo(local)
        }
    }

    private func switchTo(_ newLibrary: Library) {
        library = newLibrary
        metadata = LibraryMetadata.load(from: newLibrary)
        openNotebooks = []
    }

    /// Picks up changes made elsewhere (Files app, other devices).
    func refresh() {
        revision += 1
    }

    // MARK: - Locking (DAT-7)

    func isLocked(_ url: URL) -> Bool {
        (try? NotebookPackage(url: url).readManifest().isLocked) ?? false
    }

    func setLocked(_ entry: LibraryEntry, _ isLocked: Bool) {
        guard case .notebook(let url, _) = entry else { return }
        perform {
            let package = NotebookPackage(url: url)
            var manifest = try package.readManifest()
            manifest.isLocked = isLocked
            try package.writeManifest(manifest)
            // No readable PDF copy of a locked notebook (ADR-0012).
            if isLocked {
                try? FileManager.default.removeItem(at: package.snapshotURL)
                package.deleteTextIndex()
            }
        }
    }

    // MARK: - Reading

    func items(in folder: URL, sortedBy order: SortOrder) -> [LibraryEntry] {
        _ = revision
        return sorted((try? library.contents(of: folder)) ?? [], by: order)
    }

    func favorites(sortedBy order: SortOrder) -> [LibraryEntry] {
        _ = revision
        return sorted(library.notebooks(withIDs: metadata.favorites), by: order)
    }

    /// Most recently opened first.
    func recents() -> [LibraryEntry] {
        _ = revision
        return library.notebooks(withIDs: metadata.recents.map(\.id))
    }

    func search(_ query: String, sortedBy order: SortOrder) -> [LibraryEntry] {
        _ = revision
        return sorted(library.search(query), by: order)
    }

    /// Notebooks whose handwriting matches, with the matching pages (ORG-8).
    func searchHandwriting(_ query: String) -> [(entry: LibraryEntry, pages: [Int])] {
        _ = revision
        return library.searchHandwriting(query)
    }

    /// Reads the handwriting of pages changed since the last time, one notebook
    /// at a time, so search finds it. Cheap when nothing changed.
    func indexHandwritingInBackground() async {
        let library = library
        await Task.detached(priority: .background) {
            for entry in library.allEntries() {
                guard case .notebook(let url, let manifest) = entry, !manifest.isLocked else { continue }
                try? await TextIndexer.update(NotebookPackage(url: url))
            }
        }.value
        revision += 1
    }

    func isFavorite(_ entry: LibraryEntry) -> Bool {
        if case .notebook(_, let manifest) = entry { metadata.isFavorite(manifest.id) } else { false }
    }

    /// The folder an entry is in, for search results and favorites ("in Università").
    func location(of entry: LibraryEntry) -> String {
        displayName(of: entry.url.deletingLastPathComponent())
    }

    private func sorted(_ items: [LibraryEntry], by order: SortOrder) -> [LibraryEntry] {
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

    func createNotebook(title: String, in parent: URL, paper: PaperStyle, paperColor: PaperColor, orientation: PageOrientation, cover: CoverDraft) -> NotebookPackage? {
        perform {
            let package = try library.createNotebook(title: title, in: parent, paper: paper, paperColor: paperColor, orientation: orientation, cover: .color(index: 0))
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

    func toggleFavorite(_ entry: LibraryEntry) {
        guard case .notebook(_, let manifest) = entry else { return }
        metadata.toggleFavorite(manifest.id)
        saveMetadata()
    }

    func markOpened(_ url: URL) {
        guard let manifest = try? NotebookPackage(url: url).readManifest() else { return }
        metadata.markOpened(manifest.id)
        saveMetadata()
    }

    private func saveMetadata() {
        perform { try metadata.save(to: library) }
    }

    /// Builds the "Export All" archive off the main thread (DAT-4).
    func exportAll() async -> URL? {
        let library = library
        do {
            return try await Task.detached(priority: .userInitiated) {
                try LibraryExporter.exportAll(library)
            }.value
        } catch {
            log.error("Export failed: \(error)")
            errorMessage = error.localizedDescription
            return nil
        }
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
