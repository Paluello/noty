import Foundation

public enum NotebookPackageError: Error, Equatable {
    case alreadyExists(URL)
    case unsupportedFormatVersion(Int)
}

/// A `.noty` notebook folder on disk (ADR-0004):
///
///     Name.noty/
///     ├── notebook.json
///     └── pages/<uuid>.drawing
///
/// Every page is its own file and every write is atomic, so a failure can
/// only ever affect a single page.
public struct NotebookPackage: Sendable {
    public static let fileExtension = "noty"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    var manifestURL: URL { url.appending(path: "notebook.json") }
    var pagesURL: URL { url.appending(path: "pages", directoryHint: .isDirectory) }
    var assetsURL: URL { url.appending(path: "assets", directoryHint: .isDirectory) }

    /// PDF copy of the whole notebook, readable without Noty (ADR-0004).
    public var snapshotURL: URL { url.appending(path: "snapshot.pdf") }

    func pageURL(_ id: UUID) -> URL {
        pagesURL.appending(path: "\(id.uuidString).drawing")
    }

    func elementsURL(_ id: UUID) -> URL {
        pagesURL.appending(path: "\(id.uuidString).json")
    }

    /// Creates a new notebook package at `url` and writes its manifest.
    @discardableResult
    public static func create(at url: URL, manifest: NotebookManifest) throws -> NotebookPackage {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw NotebookPackageError.alreadyExists(url)
        }
        let package = NotebookPackage(url: url)
        try fm.createDirectory(at: package.pagesURL, withIntermediateDirectories: true)
        try package.writeManifest(manifest)
        return package
    }

    public func readManifest() throws -> NotebookManifest {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try Self.decoder.decode(NotebookManifest.self, from: data)
        guard manifest.formatVersion <= NotebookManifest.currentFormatVersion else {
            throw NotebookPackageError.unsupportedFormatVersion(manifest.formatVersion)
        }
        return manifest
    }

    public func writeManifest(_ manifest: NotebookManifest) throws {
        try Self.encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    /// Serialized `PKDrawing` of a page, or `nil` if the page was never drawn on.
    public func readPage(_ id: UUID) throws -> Data? {
        let pageURL = pageURL(id)
        guard FileManager.default.fileExists(atPath: pageURL.path(percentEncoded: false)) else {
            return nil
        }
        return try Data(contentsOf: pageURL)
    }

    public func writePage(_ id: UUID, data: Data) throws {
        try data.write(to: pageURL(id), options: .atomic)
    }

    /// Copies a page's drawing and elements to a new page id (used to duplicate pages).
    public func copyPage(_ source: UUID, to destination: UUID) throws {
        if let data = try readPage(source) {
            try writePage(destination, data: data)
        }
        let elements = try readElements(source)
        if !elements.isEmpty {
            try writeElements(elements, page: destination)
        }
    }

    // MARK: - Text boxes and images (ADR-0014)

    public func readElements(_ page: UUID) throws -> [PageElement] {
        let url = elementsURL(page)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        return try JSONDecoder().decode([PageElement].self, from: Data(contentsOf: url))
    }

    /// Saves the page's elements; an empty list removes the file.
    public func writeElements(_ elements: [PageElement], page: UUID) throws {
        let url = elementsURL(page)
        if elements.isEmpty {
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(elements).write(to: url, options: .atomic)
    }

    /// Stores an image inserted on a page and returns its file name in `assets/`.
    public func writeAsset(_ data: Data, fileExtension: String) throws -> String {
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        let fileName = "image-\(UUID().uuidString).\(fileExtension.lowercased())"
        try data.write(to: assetsURL.appending(path: fileName), options: .atomic)
        return fileName
    }

    public func assetURL(_ fileName: String) -> URL {
        assetsURL.appending(path: fileName)
    }

    /// Makes sure every file of the notebook is on this device before opening
    /// it: in iCloud Drive or other cloud folders, files may be placeholders.
    /// A coordinated read waits for the download (ADR-0018).
    public func prepareForReading() throws {
        var coordinationError: NSError?
        var readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { _ in
            do {
                _ = try FileManager.default.contentsOfDirectory(at: pagesURL, includingPropertiesForKeys: nil)
            } catch {
                readError = error
            }
        }
        if let error = coordinationError ?? readError {
            throw error
        }
    }

    // MARK: - Cover image (ORG-9)

    /// Stores an image as the cover and returns the matching `Cover` value.
    public func writeCoverImage(_ data: Data, fileExtension: String) throws -> Cover {
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        // A new name each time, so views showing the old cover notice the change.
        let fileName = "cover-\(UUID().uuidString.prefix(8)).\(fileExtension.lowercased())"
        try data.write(to: assetsURL.appending(path: fileName), options: .atomic)
        return .image(fileName: fileName)
    }

    public func coverImageURL(_ fileName: String) -> URL {
        assetsURL.appending(path: fileName)
    }

    /// Removes cover images that the manifest no longer uses.
    public func removeUnusedCoverImages(keeping cover: Cover) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: assetsURL.path(percentEncoded: false))) ?? []
        for file in files where file.hasPrefix("cover-") && cover != .image(fileName: file) {
            try? FileManager.default.removeItem(at: assetsURL.appending(path: file))
        }
    }

    public func deletePage(_ id: UUID) throws {
        for url in [pageURL(id), elementsURL(id)] where FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
