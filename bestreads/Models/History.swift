//  Created by Angela Kwon on 3/30/26.

import Foundation
import SwiftData

@Model
final class History: Identifiable {
    var id: UUID
    var date: Date
    var title: String
    var author: String
    var rating: Int
    var quotes: [Quote]
    var notes: String?
    var tags: [String]
    var dateAdded: Date
    //@Relationship(deleteRule: .cascade, inverse: \Book.??)

    var updatedAt: Date
    
    init(id: UUID = UUID(), date: Date = Date(), title: String, author: String, rating: Int = 3, quotes: [Quote] = [], notes: String? = nil, tags: [String] = [], dateAdded: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.date = date
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

    static func normalizeTags(_ rawTags: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in rawTags {
            let tag = normalizeTag(raw)
            let key = tag.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                out.append(tag)
            }
        }
        return out
    }

    static func normalizeTag(_ raw: String) -> String {
        var tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if tag.isEmpty { return "#tag" }
        if !tag.hasPrefix("#") { tag = "#" + tag }
        return tag
    }
}
