import SwiftData

enum PreviewContainer {
    @MainActor
    static func make() -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: Book.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )

            for (index, book) in Book.sampleData.enumerated() {
                let previewBook = Book(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    rating: book.rating,
                    quotes: book.quotes,
                    notes: book.notes,
                    tags: book.tags,
                    sortIndex: index,
                    dateAdded: book.dateAdded,
                    updatedAt: book.updatedAt
                )
                container.mainContext.insert(previewBook)
            }

            try container.mainContext.save()
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
