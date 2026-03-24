import SwiftUI

enum AddEditMode {
    case add
    case edit
}

struct AddEditBookView: View {
    @ObservedObject var store: BookStore
    var mode: AddEditMode
    var bookToEdit: Book?
    var onDone: () -> Void

    @State private var title = ""
    @State private var author = ""
    @State private var rating = 3
    @State private var notes = ""
    @State private var tagsText = ""
    @State private var newQuoteText = ""
    @State private var quotes: [Quote] = []

    init(store: BookStore, mode: AddEditMode, book: Book? = nil, onDone: @escaping () -> Void) {
        self.store = store
        self.mode = mode
        self.bookToEdit = book
        self.onDone = onDone
        // _state initializers will run in body onAppear to prefill
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Book")) {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    Picker("Rating", selection: $rating) {
//                        ForEach(1...5, id: \.
//self) { i in
//                            Text("\(i)")
//                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section(header: Text("Tags (comma separated)")) {
                    TextField("#nonfiction, #immigrant", text: $tagsText)
                }

                Section(header: Text("Quotes")) {
                    VStack(spacing: 8) {
                        HStack {
                            TextField("Type a quote", text: $newQuoteText)
                            Button(action: addQuote) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(newQuoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if quotes.isEmpty {
                            Text("No quotes yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(quotes) { q in
                                HStack {
                                    Text("\"\(q.text)\"")
                                        .lineLimit(2)
                                    Spacer()
                                    Button(role: .destructive) {
                                        removeQuote(id: q.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode == .add ? "Add Book" : "Edit Book")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
            }
            .onAppear {
                prefillIfNeeded()
            }
        }
    }

    private func addQuote() {
        let trimmed = newQuoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        quotes.append(Quote(text: trimmed))
        newQuoteText = ""
    }

    private func removeQuote(id: UUID) {
        quotes.removeAll { $0.id == id }
    }

    private func prefillIfNeeded() {
        guard let b = bookToEdit, mode == .edit else { return }
        title = b.title
        author = b.author
        rating = b.rating
        notes = b.notes ?? ""
        tagsText = b.tags.joined(separator: ", ")
        quotes = b.quotes
    }

    private func save() {
        let tags = tagsText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        if mode == .add {
            let book = Book(title: title, author: author, rating: rating, quotes: quotes, notes: notes.isEmpty ? nil : notes, tags: tags)
            store.add(book)
        } else if mode == .edit, let existing = bookToEdit {
            var updated = existing
            updated.title = title
            updated.author = author
            updated.rating = Book.clampedRating(rating)
            updated.notes = notes.isEmpty ? nil : notes
            updated.tags = Book.normalizeTags(tags)
            updated.quotes = quotes
            updated.updatedAt = Date()
            store.update(updated)
        }

        onDone()
    }
}

struct AddEditBookView_Previews: PreviewProvider {
    static var previews: some View {
        AddEditBookView(store: BookStore(), mode: .add) {}
    }
}
