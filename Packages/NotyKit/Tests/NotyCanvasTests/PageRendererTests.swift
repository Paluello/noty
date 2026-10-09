import Foundation
import PDFKit
import PencilKit
import Testing
@testable import NotyCanvas
@testable import NotyCore

@Suite struct PageRendererTests {
    let package: NotebookPackage
    let manifest: NotebookManifest

    init() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).noty")
        manifest = NotebookManifest(title: "Fisica", paper: .grid, pageIDs: [UUID(), UUID(), UUID()])
        package = try NotebookPackage.create(at: url, manifest: manifest)

        // One stroke on the first page.
        let points = (0..<20).map { index in
            PKStrokePoint(location: CGPoint(x: 100 + index * 10, y: 200), timeOffset: Double(index) * 0.01, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: .now))
        try package.writePage(manifest.pageIDs[0], data: PKDrawing(strokes: [stroke]).dataRepresentation())
    }

    @Test func exportsOneA4PagePerNotebookPage() throws {
        let url = try PageRenderer.exportPDFForSharing(of: package)
        let document = try #require(PDFDocument(url: url))

        #expect(url.lastPathComponent == "Fisica.pdf")
        #expect(document.pageCount == 3)
        let bounds = try #require(document.page(at: 0)).bounds(for: .mediaBox)
        #expect(bounds.width == 595 && bounds.height == 842)
        #expect(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String == "Fisica")
    }

    @Test func thumbnailHasPageProportions() {
        let image = PageRenderer.thumbnail(of: manifest.pageIDs[0], in: package, manifest: manifest, width: 170)
        #expect(image.size.width == 170)
        #expect(abs(image.size.height - 170 * 842 / 595) < 1)
    }
}
