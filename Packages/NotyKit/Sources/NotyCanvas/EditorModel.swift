import Observation
import PencilKit
import UIKit

public enum ToolKind: String, CaseIterable, Identifiable, Sendable {
    case pen, pencil, highlighter, eraser, lasso

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .pen: "pencil.tip"
        case .pencil: "pencil"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }
}

public enum EraserMode: String, CaseIterable, Sendable {
    /// Removes whole strokes.
    case stroke
    /// Removes only the touched part of a stroke.
    case partial
}

/// The standard 8-color palette (STR-5).
public enum Palette {
    public static let standard: [UIColor] = [
        .black,
        UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1), // gray
        UIColor(red: 0.04, green: 0.37, blue: 0.85, alpha: 1), // blue
        UIColor(red: 0.85, green: 0.16, blue: 0.20, alpha: 1), // red
        UIColor(red: 0.10, green: 0.60, blue: 0.30, alpha: 1), // green
        UIColor(red: 0.98, green: 0.62, blue: 0.08, alpha: 1), // orange
        UIColor(red: 0.55, green: 0.25, blue: 0.80, alpha: 1), // purple
        UIColor(red: 0.98, green: 0.85, blue: 0.10, alpha: 1), // yellow
    ]
}

/// Editor state shared between the SwiftUI toolbar and the UIKit canvas.
@MainActor @Observable
public final class EditorModel {
    public var tool: ToolKind = .pen
    public var colorIndex = 0
    public var palette = Palette.standard
    public var eraserMode: EraserMode = .partial
    public var widths: [ToolKind: CGFloat] = [.pen: 2.5, .pencil: 3, .highlighter: 18]

    public internal(set) var pageCount = 0
    public internal(set) var currentPage = 1

    weak var canvasController: NotebookCanvasViewController?

    public init() {}

    public var color: UIColor { palette[colorIndex] }

    public func undo() { canvasController?.undo() }
    public func redo() { canvasController?.redo() }
    public func addPage() { canvasController?.appendPage(scrollToIt: true) }

    var pkTool: PKTool {
        switch tool {
        case .pen: PKInkingTool(.pen, color: color, width: widths[.pen] ?? 2.5)
        case .pencil: PKInkingTool(.pencil, color: color, width: widths[.pencil] ?? 3)
        case .highlighter: PKInkingTool(.marker, color: color, width: widths[.highlighter] ?? 18)
        case .eraser: PKEraserTool(eraserMode == .stroke ? .vector : .bitmap)
        case .lasso: PKLassoTool()
        }
    }
}
