import Foundation
import NotyCore
import UIKit
import Vision

/// Recognizes the text on each page, handwriting included, on the device,
/// and keeps the notebook's `text-index.json` up to date (ORG-8).
public enum TextIndexer {
    /// Width of the page image given to Vision: enough detail for handwriting.
    static let imageWidth: CGFloat = 1240

    /// Re-reads only the pages changed since the last run. Locked notebooks
    /// get no index at all (ADR-0012). Slow: call it off the main thread.
    public static func update(_ package: NotebookPackage) async throws {
        let manifest = try package.readManifest()
        guard !manifest.isLocked else {
            package.deleteTextIndex()
            return
        }
        var index = package.readTextIndex()
        var changed = false
        for id in index.pages.keys where !manifest.pageIDs.contains(id) {
            index.pages[id] = nil
            changed = true
        }
        for id in manifest.pageIDs {
            let modified = package.pageModifiedAt(id)
            if modified == .distantPast {
                // Blank page.
                if index.pages.removeValue(forKey: id) != nil { changed = true }
                continue
            }
            // Dates are saved with one-second precision.
            if let entry = index.pages[id], abs(entry.pageModifiedAt.timeIntervalSince(modified)) < 1 {
                continue
            }
            let image = PageRenderer.thumbnail(of: id, in: package, manifest: manifest, width: imageWidth, displayScale: 1)
            let text = try await recognizeText(in: image)
            index.pages[id] = TextIndex.Entry(text: text, pageModifiedAt: modified)
            changed = true
        }
        if changed {
            try package.writeTextIndex(index)
        }
    }

    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [Locale.Language(identifier: "it-IT"), Locale.Language(identifier: "en-US")]
        let observations = try await request.perform(on: cgImage)
        return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
