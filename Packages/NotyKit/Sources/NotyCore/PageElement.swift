import CoreGraphics
import Foundation

/// A text box or an image placed on a page, under the ink (ADR-0014).
/// Saved in `pages/<page id>.json`; frames are in page points.
public struct PageElement: Codable, Hashable, Identifiable, Sendable {
    public enum Content: Codable, Hashable, Sendable {
        case text(string: String, fontSize: Double, colorHex: String)
        /// A file in the notebook's `assets/` folder.
        case image(fileName: String)
    }

    public var id: UUID
    public var content: Content
    public var frame: CGRect

    public init(id: UUID = UUID(), content: Content, frame: CGRect) {
        self.id = id
        self.content = content
        self.frame = frame
    }

    public var isEmptyText: Bool {
        if case .text(let string, _, _) = content {
            string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            false
        }
    }
}
