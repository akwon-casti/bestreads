import Foundation
import Combine

@MainActor
final class BookStore: ObservableObject {
    @Published private(set) var books: [Book] = []

    private let saveKey = "bestreads.books.v1"
    private var saveTask: Task<Void, Never>? = nil

    init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            do {
                let decoded = try JSONDecoder().decode([Book].self, from: data)
                self.books = decoded
            } catch {
                print("Failed to decode books: \(error)")
                self.books = []
            }
        } else {
            // start with an empty library
            self.books = []
        }
    }

    private func scheduleSave() {
        // cancel previous and debounce quick changes
        saveTask?.cancel()
        saveTask = Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: 200 * 1_000_000) // 200ms
            await MainActor.run {
                self?.performSave()
            }
        }
    }

    private func performSave() {
        do {
            let data = try JSONEncoder().encode(self.books)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Failed to save books: \(error)")
        }
    }

    func add(_ book: Book) {
        var b = book
        b.updatedAt = Date()
        books.insert(b, at: 0)
        scheduleSave()
    }

    func update(_ book: Book) {
        guard let idx = books.firstIndex(where: { $0.id == book.id }) else { return }
        var b = book
        b.updatedAt = Date()
        books[idx] = b
        scheduleSave()
    }

    func delete(id: UUID) {
        books.removeAll { $0.id == id }
        scheduleSave()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        books.move(fromOffsets: fromOffsets, toOffset: toOffset)
        scheduleSave()
    }

    func availableTags() -> [String] {
        // collect tags from all books, deduplicated
        var set = Set<String>()
        var out: [String] = []
        for book in books {
            for tag in book.tags {
                let key = tag.lowercased()
                if !set.contains(key) {
                    set.insert(key)
                    out.append(tag)
                }
            }
        }
        return out
    }
}
