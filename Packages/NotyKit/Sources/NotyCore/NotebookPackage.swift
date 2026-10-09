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

    /// Copies a page's drawing to a new page id (used to duplicate pages).
    public func copyPage(_ source: UUID, to destination: UUID) throws {
        if let data = try readPage(source) {
            try writePage(destination, data: data)
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
        let pageURL = pageURL(id)
        if FileManager.default.fileExists(atPath: pageURL.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: pageURL)
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
