//
//  BookSampleData.swift
//  bestreads
//
//  Created by Angela Kwon on 4/2/26.
//

import Foundation

enum BookSampleData {
    static let books: [Book] = [
        Book(
            title: "Piranesi",
            author: "Susanna Clarke",
            rating: 5,
            quotes: [Quote(text: "The Beauty of the House is immeasurable; its Kindness infinite.")],
            notes: "Atmospheric and disorienting in the best way.",
            tags: ["#fantasy", "#favorite"]
        ),
        Book(
            title: "The Left Hand of Darkness",
            author: "Ursula K. Le Guin",
            rating: 5,
            quotes: [Quote(text: "Light is the left hand of darkness.")],
            notes: "Sharp political and cultural worldbuilding.",
            tags: ["#sciencefiction", "#classic"]
        ),
        Book(
            title: "Braiding Sweetgrass",
            author: "Robin Wall Kimmerer",
            rating: 4,
            quotes: [Quote(text: "All flourishing is mutual.")],
            notes: "Reflective and generous without losing specificity.",
            tags: ["#nonfiction"]
        )
    ]
}

extension Book {
    static let sampleData = BookSampleData.books
}
