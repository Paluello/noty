import Foundation

/// Text recognized in each page's handwriting, for search (ORG-8).
/// Saved as `text-index.json` in the notebook; rebuilt page by page when a
/// page changes. Locked notebooks have none (ADR-0012).
public struct TextIndex: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var text: String
        /// Modification date of the page files when the text was recognized.
        public var pageModifiedAt: Date

        public init(text: String, pageModifiedAt: Date) {
            self.text = text
            self.pageModifiedAt = pageModifiedAt
        }
    }

    public var pages: [UUID: Entry] = [:]

    public init() {}

    // Saved as {"pages": {"<page id>": {...}}}, readable by other tools.
    private enum CodingKeys: String, CodingKey {
        case pages
    }

    public init(from decoder: any Decoder) throws {
        let byString = try decoder.container(keyedBy: CodingKeys.self).decode([String: Entry].self, forKey: .pages)
        pages = Dictionary(uniqueKeysWithValues: byString.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } })
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Dictionary(uniqueKeysWithValues: pages.map { ($0.key.uuidString, $0.value) }), forKey: .pages)
    }

    /// Indexes (0-based) of pages containing `query`, ignoring case and accents.
    public func pages(matching query: String, order: [UUID]) -> [Int] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return order.enumerated().compactMap { index, id in
            guard let text = pages[id]?.text,
                  text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            else { return nil }
            return index
        }
    }
}
