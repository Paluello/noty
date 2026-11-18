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

/// Color of the paper (PAG-3).
public enum PaperColor: String, Codable, CaseIterable, Sendable {
    case white
    case ivory
    case gray
}

/// Contents of `notebook.json` (ADR-0004).
public struct NotebookManifest: Codable, Hashable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var id: UUID
    public var title: String
    public var cover: Cover
    public var paper: PaperStyle
    /// Added in 0.3; missing in older notebooks, which are white.
    public var paperColor: PaperColor
    /// Distance between lines, squares or dots, in page points; `nil` is the
    /// default of the style. Added in 0.7.
    public var paperSpacing: Double?
    public var orientation: PageOrientation
    public var pageIDs: [UUID]
    /// Opening needs Face ID or the passcode (DAT-7, ADR-0012). Added in 0.3.
    public var isLocked: Bool
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        cover: Cover = .randomColor(),
        paper: PaperStyle,
        paperColor: PaperColor = .white,
        paperSpacing: Double? = nil,
        orientation: PageOrientation = .portrait,
        pageIDs: [UUID] = [UUID()],
        createdAt: Date = .now
    ) {
        self.formatVersion = Self.currentFormatVersion
        self.id = id
        self.title = title
        self.cover = cover
        self.paper = paper
        self.paperColor = paperColor
        self.paperSpacing = paperSpacing
        self.orientation = orientation
        self.pageIDs = pageIDs
        self.isLocked = false
        self.createdAt = createdAt
        self.modifiedAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion, id, title, cover, paper, paperColor, paperSpacing, orientation, pageIDs, isLocked, createdAt, modifiedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        cover = try container.decode(Cover.self, forKey: .cover)
        paper = try container.decode(PaperStyle.self, forKey: .paper)
        // Optional fields keep notebooks from 0.1 and 0.2 readable.
        paperColor = try container.decodeIfPresent(PaperColor.self, forKey: .paperColor) ?? .white
        paperSpacing = try container.decodeIfPresent(Double.self, forKey: .paperSpacing)
        orientation = try container.decode(PageOrientation.self, forKey: .orientation)
        pageIDs = try container.decode([UUID].self, forKey: .pageIDs)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    }
}
