//
//  ContentView.swift
//  bestreads
//
//  Created by Angela Kwon on 3/16/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = BookStore()
    @State private var showingAdd = false

    enum SortOption: String, CaseIterable {
        case dateDesc = "Date (newest)"
        case dateAsc = "Date (oldest)"
        case ratingDesc = "Rating (high)"
        case ratingAsc = "Rating (low)"
    }

    @State private var sortOption: SortOption = .dateDesc
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
                        ForEach(store.availableTags(), id: \.self) { tag in
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
                    if store.books.isEmpty {
                        Text("No books yet. Tap + to add one.")
                            .foregroundStyle(.secondary)
                    } else {
                        // Build filtered + sorted list
                        let filtered = filteredBooks()
                        if isFiltered() {
                            // filtered: show items but do not allow reordering
                            ForEach(filtered) { book in
                                NavigationLink(destination: BookDetailView(book: book, store: store)) {
                                    BookRowView(book: book)
                                }
                            }
                            .onDelete { idxSet in
                                for idx in idxSet {
                                    let id = filtered[idx].id
                                    store.delete(id: id)
                                }
                            }
                        } else {
                            // unfiltered: operate directly on store.books so onMove works
                            ForEach(store.books) { book in
                                NavigationLink(destination: BookDetailView(book: book, store: store)) {
                                    BookRowView(book: book)
                                }
                            }
                            .onDelete { idxSet in
                                for idx in idxSet {
                                    let id = store.books[idx].id
                                    store.delete(id: id)
                                }
                            }
                            .onMove { from, to in
                                store.move(fromOffsets: from, toOffset: to)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Best Reads")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Only show edit button when not filtered (reordering makes sense)
                    if !isFiltered() { EditButton() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditBookView(store: store, mode: .add) {
                    showingAdd = false
                }
            }
        }
    }

    // Helpers
    private func isFiltered() -> Bool {
        return selectedTag != nil || minRating > 1
    }

    private func filteredBooks() -> [Book] {
        var out = store.books
        // filter by tag
        if let tag = selectedTag {
            out = out.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }
        // filter by min rating
        out = out.filter { $0.rating >= minRating }

        // sort
        switch sortOption {
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
}

#Preview {
    ContentView()
}
