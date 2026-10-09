import Foundation
import NotyCore

/// "Export All" (DAT-4): one zip with the folder structure, every notebook as
/// its original `.noty` package and as a PDF next to it.
public enum LibraryExporter {
    public enum ExportError: Error {
        case zipFailed
    }

    /// Builds the archive in a temporary folder and returns its URL.
    /// Runs off the main thread: it can take a while for big libraries.
    public static func exportAll(_ library: Library, date: Date = .now) throws -> URL {
        let fm = FileManager.default
        let stamp = date.formatted(.iso8601.year().month().day())
        let work = fm.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let folder = work.appending(path: "Noty \(stamp)", directoryHint: .isDirectory)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        try copyContents(of: library.root, in: library, to: folder)

        let zipURL = work.appending(path: "Noty \(stamp).zip")
        try zip(folder, to: zipURL)
        return zipURL
    }

    private static func copyContents(of source: URL, in library: Library, to destination: URL) throws {
        let fm = FileManager.default
        for entry in try library.contents(of: source) {
            switch entry {
            case .folder(let url):
                let target = destination.appending(path: url.lastPathComponent, directoryHint: .isDirectory)
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
                try copyContents(of: url, in: library, to: target)

            case .notebook(let url, _):
                let name = url.deletingPathExtension().lastPathComponent
                try fm.copyItem(at: url, to: destination.appending(path: url.lastPathComponent))
                try PageRenderer.exportPDF(of: NotebookPackage(url: url), to: destination.appending(path: "\(name).pdf"))
            }
        }
    }

    /// Zips a folder with the system's own archiver: coordinated reading "for
    /// uploading" hands back a zip of the directory.
    private static func zip(_ folder: URL, to zipURL: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { temporaryZip in
            do {
                try FileManager.default.moveItem(at: temporaryZip, to: zipURL)
            } catch {
                copyError = error
            }
        }
        if let error = coordinationError ?? copyError {
            throw error
        }
        guard FileManager.default.fileExists(atPath: zipURL.path(percentEncoded: false)) else {
            throw ExportError.zipFailed
        }
    }
}
