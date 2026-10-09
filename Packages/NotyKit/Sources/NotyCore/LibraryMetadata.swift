import Foundation

/// Favorites and recently opened notebooks (ORG-5), saved in the hidden
/// `.noty-library.json` at the library root (ADR-0005).
///
/// Notebooks are referenced by their manifest id, so favorites and recents
/// survive renaming and moving.
public struct LibraryMetadata: Codable, Equatable, Sendable {
    public static let fileName = ".noty-library.json"
    public static let recentLimit = 20

    public struct Recent: Codable, Equatable, Sendable {
        public var id: UUID
        public var openedAt: Date
    }

    public var favorites: [UUID] = []
    public var recents: [Recent] = []

    public init() {}

    public func isFavorite(_ id: UUID) -> Bool {
        favorites.contains(id)
    }

    public mutating func toggleFavorite(_ id: UUID) {
        if let index = favorites.firstIndex(of: id) {
            favorites.remove(at: index)
        } else {
            favorites.append(id)
        }
    }

    /// Moves `id` to the top of the recents, keeping at most 20.
    public mutating func markOpened(_ id: UUID, at date: Date = .now) {
        recents.removeAll { $0.id == id }
        recents.insert(Recent(id: id, openedAt: date), at: 0)
        if recents.count > Self.recentLimit {
            recents.removeLast(recents.count - Self.recentLimit)
        }
    }

    // MARK: - Storage

    public static func load(from library: Library) -> LibraryMetadata {
        let url = library.root.appending(path: fileName)
        guard let data = try? Data(contentsOf: url) else { return LibraryMetadata() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(LibraryMetadata.self, from: data)) ?? LibraryMetadata()
    }

    public func save(to library: Library) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: library.root.appending(path: Self.fileName), options: .atomic)
    }
}
