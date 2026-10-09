import NotyCanvas
import NotyCore
import SwiftUI

@main
struct NotyApp: App {
    var body: some Scene {
        WindowGroup {
            SpikeView()
        }
    }
}

/// Milestone 0 spike: opens a 50-page A4 notebook to validate scrolling,
/// zooming and canvas recycling (ADR-0006). Replaced by the library in v0.1.
struct SpikeView: View {
    @State private var model = EditorModel()
    @State private var package: NotebookPackage?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if let package {
                EditorToolbar(model: model)
                Divider()
                NotebookCanvas(package: package, model: model)
                    .ignoresSafeArea(edges: .bottom)
            } else if let error {
                ContentUnavailableView("Unable to open the notebook", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView()
            }
        }
        .task { openSpikeNotebook() }
    }

    private func openSpikeNotebook() {
        do {
            let documents = URL.documentsDirectory
            let url = documents.appending(path: "Spike.\(NotebookPackage.fileExtension)")
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                package = NotebookPackage(url: url)
            } else {
                let manifest = NotebookManifest(
                    title: "Spike",
                    paper: .lined,
                    pageIDs: (0..<50).map { _ in UUID() }
                )
                package = try NotebookPackage.create(at: url, manifest: manifest)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
