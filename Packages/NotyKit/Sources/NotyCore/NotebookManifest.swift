import Foundation

/// Background pattern of every page in a notebook, chosen at creation (PAG-2).
public enum PaperStyle: String, Codable, CaseIterable, Sendable {
    case blank
    case lined
    case grid
    case dotted
}

public enum PageOrientation: String, Codable, Sendable {
    case portrait
    case landscape
}

/// Pages are always A4 (ADR-0006), in PDF points.
public enum PageGeometry {
    public static let a4Width: Double = 595
    public static let a4Height: Double = 842

    public static func size(for orientation: PageOrientation) -> (width: Double, height: Double) {
        switch orientation {
        case .portrait: (a4Width, a4Height)
        case .landscape: (a4Height, a4Width)
        }
    }
}

/// Notebook cover (ORG-9): one of the built-in colors, or an image stored in `assets/`.
public enum Cover: Codable, Hashable, Sendable {
    case color(index: Int)
    case image(fileName: String)

    /// Number of built-in cover colors; the actual colors live in the UI layer.
    public static let colorCount = 12

    public static func randomColor() -> Cover {
        .color(index: Int.random(in: 0..<colorCount))
    }
}

/// Contents of `notebook.json` (ADR-0004).
public struct NotebookManifest: Codable, Hashable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var id: UUID
    public var title: String
    public var cover: Cover
    public var paper: PaperStyle
    public var orientation: PageOrientation
    public var pageIDs: [UUID]
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        cover: Cover = .randomColor(),
        paper: PaperStyle,
        orientation: PageOrientation = .portrait,
        pageIDs: [UUID] = [UUID()],
        createdAt: Date = .now
    ) {
        self.formatVersion = Self.currentFormatVersion
        self.id = id
        self.title = title
        self.cover = cover
        self.paper = paper
        self.orientation = orientation
        self.pageIDs = pageIDs
        self.createdAt = createdAt
        self.modifiedAt = createdAt
    }
}
