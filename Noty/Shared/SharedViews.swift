import NotyCanvas
import NotyCore
import SwiftUI

extension EnvironmentValues {
    /// Opens a notebook in the editor.
    @Entry var openNotebook: (URL) -> Void = { _ in }
    /// Opens a notebook in its own window (UI-4).
    @Entry var openNotebookInNewWindow: (URL) -> Void = { _ in }
    /// Opens a notebook at a page, from a handwriting search result (ORG-8).
    @Entry var openNotebookAtPage: (URL, Int) -> Void = { _, _ in }
    /// Shows the Settings sheet.
    @Entry var showSettings: () -> Void = {}
}

/// A small live preview of a paper style, drawn with the same code as the pages.
struct PaperPreview: View {
    let style: PaperStyle
    var orientation: PageOrientation = .portrait
    var color: PaperColor = .white

    var body: some View {
        let size = PageGeometry.size(for: orientation)
        Canvas { context, canvasSize in
            let scale = canvasSize.width / size.width
            context.scaleBy(x: scale, y: scale)
            context.withCGContext { cg in
                cg.setFillColor(color.uiColor.cgColor)
                cg.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
                PaperRenderer.draw(
                    style,
                    in: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                    context: cg,
                    lineScale: PaperRenderer.lineScale(forDrawingScale: scale)
                )
            }
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 6))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        .environment(\.colorScheme, .light)
    }
}

extension PaperStyle {
    var title: LocalizedStringKey {
        switch self {
        case .blank: "Blank"
        case .lined: "Lined"
        case .grid: "Grid"
        case .dotted: "Dotted"
        }
    }
}

/// System share sheet, for exported PDFs (DAT-3).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Something to share, so it can drive `.sheet(item:)`.
struct SharedFile: Identifiable {
    let url: URL
    /// For notebooks: the page to open at.
    var page: Int?
    var id: URL { url }
}

/// Soft color field behind the library, so the glass has something to refract.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let opacity = colorScheme == .dark ? 0.35 : 0.22
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                CoverPalette.color(5).opacity(opacity), CoverPalette.color(8).opacity(opacity * 0.6), CoverPalette.color(9).opacity(opacity),
                CoverPalette.color(4).opacity(opacity * 0.5), .clear, CoverPalette.color(1).opacity(opacity * 0.5),
                CoverPalette.color(6).opacity(opacity * 0.6), CoverPalette.color(2).opacity(opacity * 0.4), CoverPalette.color(0).opacity(opacity * 0.6),
            ]
        )
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea()
    }
}
