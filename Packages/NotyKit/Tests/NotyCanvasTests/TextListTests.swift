import Testing
import UIKit
@testable import NotyCanvas

@MainActor @Suite struct TextListTests {
    @Test func recognizesListMarkers() {
        #expect(ListMarker(line: "• Latte") == ListMarker(style: .bulleted, number: 0))
        #expect(ListMarker(line: "12. Uova") == ListMarker(style: .numbered, number: 12))
        #expect(ListMarker(line: "12 Uova") == nil)
        #expect(ListMarker(line: "Pane") == nil)
        #expect(ListMarker(style: .numbered, number: 2).next.prefix == "3. ")
    }

    @Test func togglesBulletsOnEveryLine() {
        let view = TextElementView(id: UUID(), frame: CGRect(x: 0, y: 0, width: 300, height: 44), text: "Latte\nUova", fontSize: 18, color: .black)
        var saved = ""
        view.onTextChange = { saved = $0 }

        view.toggleList(.bulleted)
        #expect(saved == "• Latte\n• Uova")

        view.toggleList(.numbered)
        #expect(saved == "1. Latte\n2. Uova")

        view.toggleList(.numbered)
        #expect(saved == "Latte\nUova")
    }

    @Test func textSizesAreDistinct() {
        #expect(Set(EditorModel.textSizes).count == EditorModel.textSizes.count)
        #expect(EditorModel.textSizes == EditorModel.textSizes.sorted())
    }
}
