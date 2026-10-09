import Testing
@testable import NotyCanvas

@MainActor @Suite struct EditorModelTests {
    @Test func switchEraserGoesBackToThePreviousTool() {
        let model = EditorModel()
        model.tool = .highlighter

        model.perform(.switchEraser)
        #expect(model.tool == .eraser)

        model.perform(.switchEraser)
        #expect(model.tool == .highlighter)
    }

    @Test func previousToolSwapsTheLastTwoTools() {
        let model = EditorModel()
        model.tool = .pencil
        model.tool = .lasso

        model.perform(.previousTool)
        #expect(model.tool == .pencil)
        model.perform(.previousTool)
        #expect(model.tool == .lasso)
    }

    @Test func toggleRulerAndNone() {
        let model = EditorModel()
        model.perform(.toggleRuler)
        #expect(model.isRulerActive)
        model.perform(.none)
        #expect(model.isRulerActive)
        #expect(model.tool == .pen)
    }
}
