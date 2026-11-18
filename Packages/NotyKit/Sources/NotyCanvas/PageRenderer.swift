import NotyCore
import PencilKit
import UIKit

/// Renders pages to images (thumbnails) and to PDF (DAT-3, ADR-0004 snapshot).
public enum PageRenderer {
    /// Ink is always rendered as on paper, never with dark-mode colors.
    private static let lightTraits = UITraitCollection(userInterfaceStyle: .light)

    private static func pageRect(_ manifest: NotebookManifest) -> CGRect {
        let size = PageGeometry.size(for: manifest.orientation)
        return CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }

    private static func drawing(_ pageID: UUID, in package: NotebookPackage) -> PKDrawing {
        guard let data = try? package.readPage(pageID), let drawing = try? PKDrawing(data: data) else {
            return PKDrawing()
        }
        return drawing
    }

    private static func drawPage(_ pageID: UUID, of package: NotebookPackage, manifest: NotebookManifest, in context: CGContext, inkScale: CGFloat, lineScale: CGFloat = 1) {
        let rect = pageRect(manifest)
        context.setFillColor(manifest.paperColor.uiColor.cgColor)
        context.fill(rect)
        PaperRenderer.draw(manifest.paper, in: rect, context: context, lineScale: lineScale, spacing: manifest.paperSpacing.map { CGFloat($0) })
        drawElements(of: pageID, in: package, context: context)
        let drawing = drawing(pageID, in: package)
        guard !drawing.strokes.isEmpty else { return }
        lightTraits.performAsCurrent {
            drawing.image(from: rect, scale: inkScale).draw(in: rect)
        }
    }

    /// Text boxes and images, under the ink like on screen (ADR-0014).
    private static func drawElements(of pageID: UUID, in package: NotebookPackage, context: CGContext) {
        let elements = (try? package.readElements(pageID)) ?? []
        guard !elements.isEmpty else { return }
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        for element in elements {
            switch element.content {
            case .image(let fileName):
                UIImage(contentsOfFile: package.assetURL(fileName).path(percentEncoded: false))?.draw(in: element.frame)
            case .text(let string, let fontSize, let colorHex):
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .foregroundColor: UIColor(hex: colorHex),
                ]
                NSAttributedString(string: string, attributes: attributes)
                    .draw(in: element.frame.inset(by: TextElementView.textInsets))
            }
        }
    }

    /// A page image `width` points wide.
    public static func thumbnail(of pageID: UUID, in package: NotebookPackage, manifest: NotebookManifest, width: CGFloat, displayScale: CGFloat = 2) -> UIImage {
        let rect = pageRect(manifest)
        let scale = width / rect.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = displayScale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: rect.height * scale), format: format)
        return renderer.image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            drawPage(pageID, of: package, manifest: manifest, in: context.cgContext, inkScale: scale * displayScale, lineScale: PaperRenderer.lineScale(forDrawingScale: scale))
        }
    }

    /// Writes the whole notebook as an A4 PDF to `url`.
    public static func exportPDF(of package: NotebookPackage, to url: URL) throws {
        let manifest = try package.readManifest()
        let rect = pageRect(manifest)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: manifest.title,
            kCGPDFContextCreator as String: "Noty",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: rect, format: format)
        try renderer.writePDF(to: url) { context in
            for pageID in manifest.pageIDs {
                context.beginPage()
                drawPage(pageID, of: package, manifest: manifest, in: context.cgContext, inkScale: 3)
            }
        }
    }

    /// Exports to a temporary file named after the notebook, ready to share.
    public static func exportPDFForSharing(of package: NotebookPackage) throws -> URL {
        let title = (try? package.readManifest().title) ?? "Noty"
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(title).pdf")
        try exportPDF(of: package, to: url)
        return url
    }
}
