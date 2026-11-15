import NotyCore
import Observation
import PencilKit
import UIKit

public enum ToolKind: String, CaseIterable, Identifiable, Sendable {
    case pen, pencil, highlighter, eraser, lasso
    /// Text boxes and images: the ink lets touches through (ADR-0014).
    case text

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .pen: "pencil.tip"
        case .pencil: "pencil"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        case .text: "textformat"
        }
    }

    /// Tools that draw with a color and a width.
    public var isInking: Bool {
        switch self {
        case .pen, .pencil, .highlighter: true
        case .eraser, .lasso, .text: false
        }
    }
}

public enum EraserMode: String, CaseIterable, Sendable {
    /// Removes only the touched part of a stroke.
    case partial
    /// Removes whole strokes.
    case stroke
}

/// What a double tap or a squeeze of Apple Pencil does (STR-11).
public enum PencilAction: String, CaseIterable, Identifiable, Sendable {
    /// Follow the choice in the iPad's Settings › Apple Pencil.
    case system
    case switchEraser
    case previousTool
    case undo
    case toggleRuler
    case none

    public var id: String { rawValue }
}

/// The standard 8-color palette (STR-5).
public enum Palette {
    public static let size = 8

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

/// Editor state shared between the SwiftUI chrome and the UIKit canvas.
@MainActor @Observable
public final class EditorModel {
    public var tool: ToolKind = .pen {
        didSet {
            if oldValue != tool {
                previousTool = oldValue
            }
        }
    }
    public private(set) var previousTool: ToolKind = .eraser
    public var colorIndex = 0
    public var palette = Palette.standard
    public var eraserMode: EraserMode = .partial

    /// Three preferred widths per inking tool (STR-6).
    public var widthPresets: [ToolKind: [CGFloat]] = [
        .pen: [1.5, 2.5, 5],
        .pencil: [2, 3.5, 7],
        .highlighter: [10, 18, 30],
    ]
    public var widthIndex: [ToolKind: Int] = [.pen: 1, .pencil: 1, .highlighter: 1]

    /// When `false`, only Apple Pencil draws and fingers scroll and zoom (ADR-0008).
    public var fingerDrawing = false
    /// Writing near the bottom of the last page adds a new page.
    public var autoNewPage = true
    /// Shows PencilKit's ruler on the current page (STR-4).
    public var isRulerActive = false
    /// Hold the Pencil still at the end of a stroke to straighten it (STR-7).
    public var shapeRecognition = true
    /// While a recording plays: ink written after this moment is dimmed (AUD-2).
    public var playbackDate: Date?
    /// Called with a stroke's time when it is tapped during playback.
    public var onSeek: ((Date) -> Void)?
    /// Page to show when the notebook opens, e.g. from a search result.
    public var initialPage: Int?
    public internal(set) var paper = PaperStyle.lined
    public internal(set) var paperColor = PaperColor.white
    public var pencilTapAction = PencilAction.system
    public var pencilSqueezeAction = PencilAction.system

    public internal(set) var pageIDs: [UUID] = []
    public internal(set) var currentPage = 1
    public internal(set) var revision = 0

    weak var canvasController: NotebookCanvasViewController?

    public init() {}

    public var pageCount: Int { pageIDs.count }
    public var color: UIColor { palette[min(colorIndex, palette.count - 1)] }

    public func width(for tool: ToolKind) -> CGFloat {
        let presets = widthPresets[tool] ?? [3]
        return presets[min(widthIndex[tool] ?? 0, presets.count - 1)]
    }

    // MARK: - Commands

    public func undo() { canvasController?.undo() }
    public func redo() { canvasController?.redo() }
    public func save() { canvasController?.saveNow() }
    public func scrollToPage(_ index: Int) { canvasController?.scrollToPage(index, animated: true) }

    public func addPageAtEnd() { canvasController?.insertPage(at: pageCount, scrollToIt: true) }
    public func insertPage(after index: Int) { canvasController?.insertPage(at: index + 1, scrollToIt: false) }
    public func duplicatePage(at index: Int) { canvasController?.duplicatePage(at: index) }
    public func deletePage(at index: Int) { canvasController?.deletePage(at: index) }
    public func movePage(from source: Int, to destination: Int) { canvasController?.movePage(from: source, to: destination) }

    /// Puts an image on the current page and switches to the Text tool to place it.
    public func insertImage(_ data: Data) {
        canvasController?.insertImage(data)
        tool = .text
    }

    /// Changes the paper of the whole notebook (PAG-5).
    public func setPaper(_ style: PaperStyle, color: PaperColor) {
        canvasController?.setPaper(style, color: color)
    }

    /// Runs the action chosen for a Pencil double tap or squeeze.
    public func perform(_ action: PencilAction) {
        switch action {
        case .system, .none:
            break
        case .switchEraser:
            tool = tool == .eraser ? (previousTool == .eraser ? .pen : previousTool) : .eraser
        case .previousTool:
            tool = previousTool
        case .undo:
            undo()
        case .toggleRuler:
            isRulerActive.toggle()
        }
    }

    func handlePencilTap() {
        perform(pencilTapAction == .system ? Self.systemAction(UIPencilInteraction.preferredTapAction) : pencilTapAction)
    }

    func handlePencilSqueeze() {
        perform(pencilSqueezeAction == .system ? Self.systemAction(UIPencilInteraction.preferredSqueezeAction) : pencilSqueezeAction)
    }

    /// Maps the iPad's Apple Pencil setting to a Noty action.
    private static func systemAction(_ preferred: UIPencilPreferredAction) -> PencilAction {
        switch preferred {
        case .switchEraser: .switchEraser
        case .switchPrevious: .previousTool
        case .ignore: .none
        default: .previousTool
        }
    }

    /// Changes only when the canvas needs a new `PKTool`: setting the tool
    /// again while the Pencil is down would interrupt the stroke.
    var toolKey: String {
        "\(tool.rawValue)|\(color.hex)|\(width(for: tool))|\(eraserMode.rawValue)"
    }

    var pkTool: PKTool {
        switch tool {
        case .pen: PKInkingTool(.pen, color: color, width: width(for: .pen))
        case .pencil: PKInkingTool(.pencil, color: color, width: width(for: .pencil))
        case .highlighter: PKInkingTool(.marker, color: color, width: width(for: .highlighter))
        case .eraser: PKEraserTool(eraserMode == .stroke ? .vector : .bitmap)
        case .lasso: PKLassoTool()
        // Unused while the canvas lets touches through to text boxes.
        case .text: PKInkingTool(.pen, color: color, width: width(for: .pen))
        }
    }

    var drawingPolicy: PKCanvasViewDrawingPolicy {
        #if targetEnvironment(simulator)
        // There is no Pencil in the simulator: let the mouse draw.
        .anyInput
        #else
        fingerDrawing ? .anyInput : .pencilOnly
        #endif
    }
}
