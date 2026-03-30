import Foundation
import Combine

@MainActor
final class BookStore: ObservableObject {
    @Published private(set) var books: [Book] = []

    private let saveKey = "bestreads.books.v1" // legacy UserDefaults key (used for migration)
    private let fileName = "books.json"
    private var saveTask: Task<Void, Never>? = nil

    init() {
        load()
    }

    private var fileURL: URL? {
        do {
            let fm = FileManager.default
            let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return docs.appendingPathComponent(fileName)
        } catch {
            print("Failed to locate documents directory: \(error)")
            return nil
        }
    }

    private func load() {
        // 1) Try migration from UserDefaults (legacy) if present and file not present
        if let udData = UserDefaults.standard.data(forKey: saveKey), let url = fileURL, !FileManager.default.fileExists(atPath: url.path) {
            do {
                let decoded = try JSONDecoder().decode([Book].self, from: udData)
                self.books = decoded
                // write to file for future loads
                try JSONEncoder().encode(decoded).write(to: url, options: .atomic)
                // remove legacy key
                UserDefaults.standard.removeObject(forKey: saveKey)
                return
            } catch {
                print("Migration from UserDefaults failed: \(error)")
                // fall through to try file-based load
            }
        }

        // 2) Try load from file
        if let url = fileURL, FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode([Book].self, from: data)
                self.books = decoded
            } catch {
                print("Failed to decode books from file: \(error)")
                self.books = []
            }
        } else {
            // start with an empty library
            self.books = []
        }

        // If still empty, seed debug sample data so scrolling and UI can be tested quickly.
        #if DEBUG
        if self.books.isEmpty {
            self.books = (1...20).map { i in
                Book(title: "Sample Book \(i)", author: "Author \(i)", rating: Int.random(in: 1...5), quotes: [Quote(text: "A memorable line from book \(i)" )], notes: "Notes for book \(i)", tags: ["#sample"])
            }
        }
        #endif
    }

    private func scheduleSave() {
        // cancel previous and debounce quick changes
        saveTask?.cancel()
        // use Task (runs on the actor) instead of Task.detached to avoid capturing the @MainActor self
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200 * 1_000_000) // 200ms
            await MainActor.run {
                self?.performSave()
            }
        }
    }

    private func performSave() {
        guard let url = fileURL else {
            print("No file URL for saving books")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self.books)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save books to file: \(error)")
        }
    }

    func add(_ book: Book) {
        var b = book
        // ensure timestamps are set
        b.updatedAt = Date()
        // keep dateAdded from initializer unless explicitly provided
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
        // collect tags from all books, deduplicated and sorted by frequency (most used first)
        var freq: [String: Int] = [:]
        for book in books {
            for raw in book.tags {
                let tag = Book.normalizeTag(raw)
                let key = tag.lowercased()
                freq[key, default: 0] += 1
            }
        }

        // create array of unique normalized tags preserving first-seen order
        var unique: [String] = []
        var seen = Set<String>()
        for book in books {
            for raw in book.tags {
                let tag = Book.normalizeTag(raw)
                let key = tag.lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    unique.append(tag)
                }
            }
        }

        // sort by frequency desc, then alphabetically
        unique.sort { a, b in
            let ka = a.lowercased()
            let kb = b.lowercased()
            let fa = freq[ka] ?? 0
            let fb = freq[kb] ?? 0
            if fa != fb { return fa > fb }
            return ka < kb
        }
        return unique
    }
}
