//
//  ContentView.swift
//  bestreads
//
//  Created by Angela Kwon on 3/16/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Book.sortIndex)]) private var books: [Book]
    @State private var showingAdd = false

    enum SortOption: String, CaseIterable {
        case manual = "Custom"
        case dateDesc = "Date (newest)"
        case dateAsc = "Date (oldest)"
        case ratingDesc = "Rating (high)"
        case ratingAsc = "Rating (low)"
    }

    @State private var sortOption: SortOption = .manual
    @State private var selectedTag: String? = nil
    @State private var minRating: Int = 1

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter controls
                HStack(spacing: 12) {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { opt in
                            Button(opt.rawValue) { sortOption = opt }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }

                    Menu {
                        Button("All") { selectedTag = nil }
                        ForEach(availableTags(), id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                        }
                    } label: {
                        Label(selectedTag ?? "Tag", systemImage: "tag")
                    }

                    Menu {
                        Button("Any") { minRating = 1 }
                        ForEach((1...5).reversed(), id: \.self) { r in
                            Button("\(r)+") { minRating = r }
                        }
                    } label: {
                        Label("Min: \(minRating)", systemImage: "star.fill")
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    if books.isEmpty {
                        Text("No books yet. Tap + to add one.")
                            .foregroundStyle(.secondary)
                    } else {
                        let filtered = filteredBooks()
                        ForEach(filtered) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                BookRowView(book: book)
                            }
                        }
                        .onDelete { indexSet in
                            deleteBooks(at: indexSet, from: filtered)
                        }
                        .onMove { from, to in
                            moveBooks(from: from, to: to)
                        }
                    }
                }
            }
            .navigationTitle("Best Reads")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if sortOption == .manual && !isFiltered() {
                        EditButton()
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Populate Sample Data") { populateSampleData() }
                        Button("Export BookSampleData.swift") { exportSampleSwiftFile() }
                        Button("Clear All Books", role: .destructive) { clearAllBooks() }
                    } label: {
                        Image(systemName: "ladybug")
                    }
                }
                #endif
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditBookView(mode: .add) {
                    showingAdd = false
                }
            }
        }
    }

    // Helpers
    private func isFiltered() -> Bool {
        return selectedTag != nil || minRating > 1
    }

    private func availableTags() -> [String] {
        var freq: [String: Int] = [:]
        var unique: [String] = []
        var seen = Set<String>()

        for book in books {
            for raw in book.tags {
                let tag = Book.normalizeTag(raw)
                let key = tag.lowercased()
                freq[key, default: 0] += 1
                if !seen.contains(key) {
                    seen.insert(key)
                    unique.append(tag)
                }
            }
        }

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

    private func filteredBooks() -> [Book] {
        var out = books

        if let tag = selectedTag {
            out = out.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }
        out = out.filter { $0.rating >= minRating }

        switch sortOption {
        case .manual:
            out.sort { $0.sortIndex < $1.sortIndex }
        case .dateDesc:
            out.sort { $0.dateAdded > $1.dateAdded }
        case .dateAsc:
            out.sort { $0.dateAdded < $1.dateAdded }
        case .ratingDesc:
            out.sort { $0.rating > $1.rating }
        case .ratingAsc:
            out.sort { $0.rating < $1.rating }
        }

        return out
    }

    private func deleteBooks(at offsets: IndexSet, from source: [Book]) {
        for index in offsets {
            modelContext.delete(source[index])
        }
        normalizeSortIndexes()
        do {
            try modelContext.save()
            print("[bestreads] Saved modelContext after delete. Current books count: \(books.count)")
        } catch {
            print("[bestreads] Failed to save modelContext after delete: \(error)")
        }
    }

    private func moveBooks(from source: IndexSet, to destination: Int) {
        guard sortOption == .manual, !isFiltered() else { return }
        var reordered = books
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, book) in reordered.enumerated() {
            book.sortIndex = index
            book.updatedAt = Date()
        }

        do {
            try modelContext.save()
            print("[bestreads] Saved modelContext after move. Current books count: \(books.count)")
        } catch {
            print("[bestreads] Failed to save modelContext after move: \(error)")
        }
    }

    private func normalizeSortIndexes() {
        let ordered = books.sorted { $0.sortIndex < $1.sortIndex }
        for (index, book) in ordered.enumerated() where book.sortIndex != index {
            book.sortIndex = index
        }
    }

#if DEBUG
    // Debug helpers: populate sample data, export a Swift sample file, and clear all books
    private func populateSampleData() {
        let samples = [
            Book(title: "Piranesi", author: "Susanna Clarke", rating: 5, quotes: [Quote(text: "The Beauty of the House is immeasurable; its Kindness infinite.")], notes: "Atmospheric and disorienting in the best way.", tags: ["#fantasy", "#favorite"]),
            Book(title: "The Left Hand of Darkness", author: "Ursula K. Le Guin", rating: 5, quotes: [Quote(text: "Light is the left hand of darkness.")], notes: "Sharp political and cultural worldbuilding.", tags: ["#sciencefiction", "#classic"]),
            Book(title: "Braiding Sweetgrass", author: "Robin Wall Kimmerer", rating: 4, quotes: [Quote(text: "All flourishing is mutual.")], notes: "Reflective and generous without losing specificity.", tags: ["#nonfiction"])
        ]

        // Insert with sequential sortIndex
        var baseIndex = (books.map { $0.sortIndex }.max() ?? -1) + 1
        for s in samples {
            s.sortIndex = baseIndex
            baseIndex += 1
            modelContext.insert(s)
        }
        do {
            try modelContext.save()
            print("[bestreads][DEBUG] Inserted sample books. Count now: \(books.count)")
        } catch {
            print("[bestreads][DEBUG] Failed to insert sample books: \(error)")
        }
    }

    private func exportSampleSwiftFile() {
        let swiftFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("BookSampleData.swift")
        var out = "// Generated BookSampleData.swift\n// exported from bestreads simulator\n\nimport Foundation\n\nenum BookSampleData {\n    static let books: [Book] = [\n"

        for book in books {
            let title = book.title
            let author = book.author
            let notes = book.notes ?? ""
            // Use String(reflecting:) to get a safe, escaped Swift literal for strings
            let tagsString = book.tags.map { String(reflecting: $0) }.joined(separator: ", ")
            let quotesString = book.quotes.map { "Quote(text: \(String(reflecting: $0.text)))" }.joined(separator: ", ")

            out += "        Book(\n"
            out += "            title: \"\(title)\",\n"
            out += "            author: \"\(author)\",\n"
            out += "            rating: \(book.rating),\n"
            out += "            quotes: [\(quotesString)],\n"
            out += "            notes: \"\(notes)\",\n"
            out += "            tags: [\(tagsString)]\n"
            out += "        ),\n"
        }

        out += "    ]\n}\n"

        do {
            try out.write(to: swiftFileURL, atomically: true, encoding: .utf8)
            print("[bestreads][DEBUG] Exported BookSampleData.swift to: \(swiftFileURL.path)")
        } catch {
            print("[bestreads][DEBUG] Failed to export sample Swift file: \(error)")
        }
    }

    private func clearAllBooks() {
        for b in books {
            modelContext.delete(b)
        }
        do {
            try modelContext.save()
            print("[bestreads][DEBUG] Cleared all books. Count now: \(books.count)")
        } catch {
            print("[bestreads][DEBUG] Failed to clear books: \(error)")
        }
    }
#endif
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.make())
}
