import Foundation
import SwiftData

struct Quote: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

@Model
final class Book: Codable {
    var id: UUID
    var title: String
    var author: String
    var rating: Int // 1...5
    var quotes: [Quote]
    var notes: String?
    var tags: [String]
    var sortIndex: Int
    var dateAdded: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        rating: Int = 3,
        quotes: [Quote] = [],
        notes: String? = nil,
        tags: [String] = [],
        sortIndex: Int = 0,
        dateAdded: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rating = Self.clampedRating(rating)
        self.quotes = quotes
        self.notes = notes
        self.tags = Self.normalizeTags(tags)
        self.sortIndex = sortIndex
        self.dateAdded = dateAdded
        self.updatedAt = updatedAt
    }

    static func clampedRating(_ n: Int) -> Int {
        max(1, min(5, n))
    }

    func addQuote(_ text: String) {
        let q = Quote(text: text)
        quotes.append(q)
        updatedAt = Date()
    }

    func removeQuote(id: UUID) {
        quotes.removeAll { $0.id == id }
        updatedAt = Date()
    }

    func toggleTag(_ rawTag: String) {
        let normalized = Self.normalizeTag(rawTag)
        if let idx = tags.firstIndex(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            tags.remove(at: idx)
        } else {
            tags.append(normalized)
        }
        updatedAt = Date()
    }

    static func normalizeTags(_ rawTags: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in rawTags {
            let t = normalizeTag(raw)
            let key = t.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                out.append(t)
            }
        }
        return out
    }

    static func normalizeTag(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "#tag" }
        if !t.hasPrefix("#") { t = "#" + t }
        return t
    }

    // Codable conformance so Book can be encoded/decoded when needed
    enum CodingKeys: String, CodingKey {
        case id, title, author, rating, quotes, notes, tags, sortIndex, dateAdded, updatedAt
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let author = try container.decode(String.self, forKey: .author)
        let rating = try container.decodeIfPresent(Int.self, forKey: .rating) ?? 3
        let quotes = try container.decodeIfPresent([Quote].self, forKey: .quotes) ?? []
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        let sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        let dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        self.init(
            id: id,
            title: title,
            author: author,
            rating: rating,
            quotes: quotes,
            notes: notes,
            tags: tags,
            sortIndex: sortIndex,
            dateAdded: dateAdded,
            updatedAt: updatedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(rating, forKey: .rating)
        try container.encode(quotes, forKey: .quotes)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)
        try container.encode(sortIndex, forKey: .sortIndex)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
