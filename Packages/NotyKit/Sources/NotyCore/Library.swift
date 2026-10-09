import Foundation

/// An entry in a library folder.
public enum LibraryEntry: Identifiable, Hashable, Sendable {
    case folder(URL)
    case notebook(URL, NotebookManifest)

    public var id: URL { url }

    public var url: URL {
        switch self {
        case .folder(let url), .notebook(let url, _): url
        }
    }

    public var name: String {
        switch self {
        case .folder(let url): url.lastPathComponent
        case .notebook(_, let manifest): manifest.title
        }
    }

    public var modifiedAt: Date {
        switch self {
        case .folder(let url): (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        case .notebook(_, let manifest): manifest.modifiedAt
        }
    }
}

/// A folder in the library tree, for the sidebar and the "Move" picker.
public struct FolderNode: Identifiable, Hashable, Sendable {
    public let url: URL
    public let children: [FolderNode]

    public var id: URL { url }
    public var name: String { url.lastPathComponent }
    /// `nil` when there are no subfolders, so `OutlineGroup` shows no disclosure arrow.
    public var childrenOrNil: [FolderNode]? { children.isEmpty ? nil : children }
}

/// Something in the trash, with where it came from (ORG-6).
public struct TrashedItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let item: LibraryEntry
    public let originalFolder: URL
    public let deletedAt: Date
}

/// The library: real folders containing `.noty` packages (ADR-0005).
///
/// The file system is the source of truth; this type only performs operations
/// on it. Deleted items go to a hidden `.Trash` folder for 30 days.
public struct Library: Sendable {
    public static let trashRetention: TimeInterval = 30 * 24 * 60 * 60

    public let root: URL

    public init(root: URL) {
        self.root = Self.normalized(root)
    }

    /// One spelling per folder (standardized, with a trailing slash), so URLs
    /// coming from different places compare equal.
    public static func normalized(_ url: URL) -> URL {
        URL(filePath: url.standardizedFileURL.path(percentEncoded: false), directoryHint: .isDirectory)
    }

    var trashURL: URL { root.appending(path: ".Trash", directoryHint: .isDirectory) }

    private var fm: FileManager { .default }

    /// Creates the root folder if needed.
    public func prepare() throws {
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // MARK: - Reading

    public func contents(of folder: URL) throws -> [LibraryEntry] {
        let urls = try fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls.compactMap(Self.item(at:))
    }

    static func item(at url: URL) -> LibraryEntry? {
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
        let url = normalized(url)
        if url.pathExtension == NotebookPackage.fileExtension {
            guard let manifest = try? NotebookPackage(url: url).readManifest() else { return nil }
            return .notebook(url, manifest)
        }
        return .folder(url)
    }

    public func folderTree() -> FolderNode {
        node(for: root)
    }

    private func node(for url: URL) -> FolderNode {
        let children = ((try? contents(of: url)) ?? [])
            .compactMap { item -> URL? in
                if case .folder(let url) = item { return url }
                return nil
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map(node(for:))
        return FolderNode(url: url, children: children)
    }

    /// Folders from the root down to `folder`, both included.
    public func ancestry(of folder: URL) -> [URL] {
        let rootPath = root.pathComponents
        let path = Self.normalized(folder).pathComponents
        guard path.starts(with: rootPath) else { return [root] }
        var result = [root]
        var current = root
        for component in path.dropFirst(rootPath.count) {
            current = current.appending(path: component, directoryHint: .isDirectory)
            result.append(current)
        }
        return result
    }

    // MARK: - Creating

    @discardableResult
    public func createFolder(named name: String, in parent: URL) throws -> URL {
        let url = uniqueURL(for: Self.sanitized(name), in: parent)
        try fm.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    @discardableResult
    public func createNotebook(
        title: String,
        in parent: URL,
        paper: PaperStyle,
        orientation: PageOrientation = .portrait,
        cover: Cover = .randomColor()
    ) throws -> NotebookPackage {
        let url = uniqueURL(for: Self.sanitized(title), extension: NotebookPackage.fileExtension, in: parent)
        let manifest = NotebookManifest(
            title: url.deletingPathExtension().lastPathComponent,
            cover: cover,
            paper: paper,
            orientation: orientation
        )
        return try NotebookPackage.create(at: url, manifest: manifest)
    }

    // MARK: - Changing

    /// Renames a folder or notebook; returns its new URL.
    @discardableResult
    public func rename(_ item: LibraryEntry, to newName: String) throws -> URL {
        let name = Self.sanitized(newName)
        let parent = item.url.deletingLastPathComponent()
        switch item {
        case .folder(let url):
            guard name != url.lastPathComponent else { return url }
            let destination = uniqueURL(for: name, in: parent)
            try fm.moveItem(at: url, to: destination)
            return destination

        case .notebook(let url, var manifest):
            var destination = url
            if name != url.deletingPathExtension().lastPathComponent {
                destination = uniqueURL(for: name, extension: NotebookPackage.fileExtension, in: parent)
                try fm.moveItem(at: url, to: destination)
            }
            manifest.title = destination.deletingPathExtension().lastPathComponent
            manifest.modifiedAt = .now
            try NotebookPackage(url: destination).writeManifest(manifest)
            return destination
        }
    }

    @discardableResult
    public func move(_ item: LibraryEntry, to folder: URL) throws -> URL {
        let source = item.url
        guard source.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL else { return source }
        // A folder cannot go inside itself.
        if case .folder = item, folder.standardizedFileURL.path().hasPrefix(source.standardizedFileURL.path()) {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let destination = uniqueURL(
            for: source.deletingPathExtension().lastPathComponent,
            extension: source.pathExtension,
            in: folder
        )
        try fm.moveItem(at: source, to: destination)
        return destination
    }

    @discardableResult
    public func duplicate(_ item: LibraryEntry) throws -> URL {
        let source = item.url
        let parent = source.deletingLastPathComponent()
        let copySuffix = String(localized: "copy", bundle: .module, comment: "Suffix added to the name of a duplicated notebook or folder")
        let baseName = "\(source.deletingPathExtension().lastPathComponent) \(copySuffix)"
        let destination = uniqueURL(for: baseName, extension: source.pathExtension, in: parent)
        try fm.copyItem(at: source, to: destination)

        // A duplicated notebook is a new notebook with its own identity.
        if case .notebook(_, var manifest) = item {
            manifest.id = UUID()
            manifest.title = destination.deletingPathExtension().lastPathComponent
            manifest.createdAt = .now
            manifest.modifiedAt = .now
            try NotebookPackage(url: destination).writeManifest(manifest)
        }
        return destination
    }

    // MARK: - Trash

    private struct TrashInfo: Codable {
        var originalRelativePath: String
        var deletedAt: Date
    }

    public func moveToTrash(_ item: LibraryEntry) throws {
        let id = UUID().uuidString
        let slot = trashURL.appending(path: id, directoryHint: .isDirectory)
        try fm.createDirectory(at: slot, withIntermediateDirectories: true)
        let info = TrashInfo(originalRelativePath: relativePath(of: item.url.deletingLastPathComponent()), deletedAt: .now)
        try JSONEncoder().encode(info).write(to: slot.appending(path: "info.json"), options: .atomic)
        try fm.moveItem(at: item.url, to: slot.appending(path: item.url.lastPathComponent))
    }

    public func trashedItems() -> [TrashedItem] {
        let slots = (try? fm.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)) ?? []
        return slots.compactMap { slot -> TrashedItem? in
            guard let data = try? Data(contentsOf: slot.appending(path: "info.json")),
                  let info = try? JSONDecoder().decode(TrashInfo.self, from: data),
                  let contentURL = try? fm.contentsOfDirectory(at: slot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                      .first(where: { $0.lastPathComponent != "info.json" }),
                  let item = Self.item(at: contentURL)
            else { return nil }
            return TrashedItem(
                id: slot.lastPathComponent,
                item: item,
                originalFolder: root.appending(path: info.originalRelativePath, directoryHint: .isDirectory),
                deletedAt: info.deletedAt
            )
        }
        .sorted { $0.deletedAt > $1.deletedAt }
    }

    /// Puts an item back where it was, or in the root if that folder is gone.
    @discardableResult
    public func restore(_ trashed: TrashedItem) throws -> URL {
        var folder = trashed.originalFolder
        if !fm.fileExists(atPath: folder.path(percentEncoded: false)) {
            folder = root
        }
        let source = trashed.item.url
        let destination = uniqueURL(
            for: source.deletingPathExtension().lastPathComponent,
            extension: source.pathExtension,
            in: folder
        )
        try fm.moveItem(at: source, to: destination)
        try fm.removeItem(at: trashURL.appending(path: trashed.id))
        return destination
    }

    public func deleteForever(_ trashed: TrashedItem) throws {
        try fm.removeItem(at: trashURL.appending(path: trashed.id))
    }

    public func emptyTrash() throws {
        for trashed in trashedItems() {
            try deleteForever(trashed)
        }
    }

    /// Permanently removes items that have been in the trash longer than 30 days.
    public func purgeExpiredTrash(now: Date = .now) {
        for trashed in trashedItems() where now.timeIntervalSince(trashed.deletedAt) > Self.trashRetention {
            try? deleteForever(trashed)
        }
    }

    // MARK: - Helpers

    private func relativePath(of folder: URL) -> String {
        ancestry(of: folder).dropFirst().map(\.lastPathComponent).joined(separator: "/")
    }

    /// `name`, or `name 2`, `name 3`… if something with that name already exists.
    func uniqueURL(for name: String, extension ext: String = "", in folder: URL) -> URL {
        func candidate(_ name: String) -> URL {
            let url = folder.appending(path: name, directoryHint: .isDirectory)
            return ext.isEmpty ? url : url.appendingPathExtension(ext)
        }
        var url = candidate(name)
        var counter = 2
        while fm.fileExists(atPath: url.path(percentEncoded: false)) {
            url = candidate("\(name) \(counter)")
            counter += 1
        }
        return url
    }

    static func sanitized(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutLeadingDots = String(cleaned.drop(while: { $0 == "." }))
        return withoutLeadingDots.isEmpty
            ? String(localized: "Untitled", bundle: .module, comment: "Default name for a notebook or folder")
            : withoutLeadingDots
    }
}
