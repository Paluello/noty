import CoreGraphics
import Foundation
import Testing
@testable import NotyCore

@Suite struct FormatCompatibilityTests {
    let package: NotebookPackage

    init() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).noty")
        package = try NotebookPackage.create(at: url, manifest: NotebookManifest(title: "Test", paper: .lined, pageIDs: [UUID()]))
    }

    @Test func readsNotebooksFromVersion02() throws {
        // A notebook.json written by Noty 0.1/0.2, without paperColor and isLocked.
        let json = """
        {
          "cover" : { "color" : { "index" : 2 } },
          "createdAt" : "2026-10-09T10:00:00Z",
          "formatVersion" : 1,
          "id" : "6F1C3A52-0E9A-4C2B-9A3E-1E2B3C4D5E6F",
          "modifiedAt" : "2026-10-09T11:00:00Z",
          "orientation" : "portrait",
          "pageIDs" : [ "A1B2C3D4-0E9A-4C2B-9A3E-1E2B3C4D5E6F" ],
          "paper" : "grid",
          "title" : "Vecchio"
        }
        """
        try Data(json.utf8).write(to: package.manifestURL)
        let manifest = try package.readManifest()
        #expect(manifest.title == "Vecchio")
        #expect(manifest.paperColor == .white)
        #expect(manifest.isLocked == false)
    }

    @Test func newFieldsRoundTrip() throws {
        var manifest = try package.readManifest()
        manifest.paperColor = .ivory
        manifest.isLocked = true
        try package.writeManifest(manifest)
        #expect(try package.readManifest() == manifest)
    }

    @Test func elementsRoundTripAndFollowPageCopies() throws {
        let page = try package.readManifest().pageIDs[0]
        #expect(try package.readElements(page).isEmpty)

        let image = try package.writeAsset(Data([1, 2, 3]), fileExtension: "JPG")
        let elements = [
            PageElement(content: .text(string: "Ciao", fontSize: 18, colorHex: "#000000"), frame: CGRect(x: 10, y: 20, width: 200, height: 40)),
            PageElement(content: .image(fileName: image), frame: CGRect(x: 50, y: 100, width: 300, height: 200)),
        ]
        try package.writeElements(elements, page: page)
        #expect(try package.readElements(page) == elements)
        #expect(FileManager.default.fileExists(atPath: package.assetURL(image).path(percentEncoded: false)))

        let copy = UUID()
        try package.copyPage(page, to: copy)
        #expect(try package.readElements(copy) == elements)

        try package.writeElements([], page: page)
        #expect(try package.readElements(page).isEmpty)

        try package.deletePage(copy)
        #expect(try package.readElements(copy).isEmpty)
    }

    @Test func emptyTextIsDetected() {
        #expect(PageElement(content: .text(string: "  \n", fontSize: 18, colorHex: "#000000"), frame: .zero).isEmptyText)
        #expect(!PageElement(content: .image(fileName: "a.jpg"), frame: .zero).isEmptyText)
    }
}
