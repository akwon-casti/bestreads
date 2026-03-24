import Foundation

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

struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var author: String
    var rating: Int // 1...5
    var quotes: [Quote]
    var notes: String?
    var tags: [String]
    var dateAdded: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, author: String, rating: Int = 3, quotes: [Quote] = [], notes: String? = nil, tags: [String] = [], dateAdded: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rating = Self.clampedRating(rating)
        self.quotes = quotes
        self.notes = notes
        self.tags = Self.normalizeTags(tags)
        self.dateAdded = dateAdded
        self.updatedAt = updatedAt
    }

    static func clampedRating(_ n: Int) -> Int {
        max(1, min(5, n))
    }

    mutating func addQuote(_ text: String) {
        let q = Quote(text: text)
        quotes.append(q)
        updatedAt = Date()
    }

    mutating func removeQuote(id: UUID) {
        quotes.removeAll { $0.id == id }
        updatedAt = Date()
    }

    mutating func toggleTag(_ rawTag: String) {
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
}
