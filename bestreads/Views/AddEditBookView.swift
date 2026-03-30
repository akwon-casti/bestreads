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
    @State private var tags: [String] = []
    @State private var newTagText = ""
    @State private var newQuoteText = ""
    @State private var quotes: [Quote] = []

    // keyboard tracking state for adaptive height
    @State private var keyboardHeight: CGFloat = 0

    // Undo support
    @State private var lastRemovedTag: String? = nil
    @State private var lastRemovedQuote: Quote? = nil
    @State private var showUndoBanner: Bool = false
    @State private var undoWorkItem: DispatchWorkItem? = nil

    init(store: BookStore, mode: AddEditMode, book: Book? = nil, onDone: @escaping () -> Void) {
        self.store = store
        self.mode = mode
        self.bookToEdit = book
        self.onDone = onDone
        // _state initializers will run in body onAppear to prefill
    }

    var quoteAreaMaxHeight: CGFloat {
        // Use a fraction of the screen height, but reduce when keyboard is visible
        let base = UIScreen.main.bounds.height * 0.35
        // Ensure a sensible min/max
        return max(120, min(360, base - keyboardHeight))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Book")) {
                        TextField("Title", text: $title)
                        TextField("Author", text: $author)
                        Picker("Rating", selection: $rating) {
                          ForEach(1...5, id: \.self) { i in
                              Text("\(i)")
                          }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(header: Text("Notes")) {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }

                    Section(header: Text("Tags")) {
                        // Suggested tags from store (horizontal tappable chips)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(store.availableTags(), id: \.self) { tag in
                                    let selected = tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
                                    Button(action: {
                                        toggleTag(tag)
                                    }) {
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(selected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // Current selected tags (horizontal)
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 6) {
                                            Text(tag)
                                                .font(.caption)
                                                .padding(6)
                                                .background(Color.secondary.opacity(0.12))
                                                .cornerRadius(6)
                                            Button(action: { removeTag(tag) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                            }
                        }

                        // Add custom tag input + fuzzy suggestions
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Add tag (e.g. #nonfiction)", text: $newTagText, onCommit: addCustomTag)
                                Button(action: addCustomTag) {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            // Fuzzy suggestions: show when typing
                            if !newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let suggestions = suggestedTags(for: newTagText)
                                if !suggestions.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(suggestions, id: \.self) { s in
                                                Button(action: {
                                                    // add/ toggle suggestion
                                                    toggleTag(s)
                                                    newTagText = ""
                                                }) {
                                                    Text(s)
                                                        .font(.caption)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(Color.gray.opacity(0.15))
                                                        .cornerRadius(8)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
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
                                // Scrollable area for quotes with auto-scroll to newest and swipe-to-delete on each quote
                                ScrollViewReader { proxy in
                                    ScrollView(.vertical) {
                                        LazyVStack(spacing: 8) {
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
                                                    .opacity(0.9)
                                                }
                                                .padding(.horizontal, 4)
                                                .id(q.id)
                                                .swipeActions(edge: .trailing) {
                                                    Button(role: .destructive) {
                                                        removeQuote(id: q.id)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .frame(maxHeight: quoteAreaMaxHeight)
                                    .onChange(of: quotes.count) { _, _ in
                                        // scroll to the latest quote when a new one is added
                                        if let lastID = quotes.last?.id {
                                            withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Undo banner overlay
                if showUndoBanner {
                    VStack {
                        Spacer()
                        HStack {
                            if let t = lastRemovedTag {
                                Text("Removed \(t)")
                            } else if let q = lastRemovedQuote {
                                Text("Removed quote")
                            }
                            Spacer()
                            Button("Undo") {
                                performUndo()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showUndoBanner)
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
            // Observe keyboard frame changes to adapt the quote area height
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notif in
                guard let info = notif.userInfo,
                      let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                // keyboard height is the portion overlapping the screen bottom
                let height = max(0, UIScreen.main.bounds.height - frame.origin.y)
                keyboardHeight = height
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        }
    }

    // tag helpers
    private func toggleTag(_ raw: String) {
        let t = Book.normalizeTag(raw)
        if let idx = tags.firstIndex(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
            // remove with undo
            let removed = tags.remove(at: idx)
            scheduleUndoForTag(removed)
        } else {
            tags.append(t)
        }
    }

    private func addCustomTag() {
        let raw = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let t = Book.normalizeTag(raw)
        if !tags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
            tags.append(t)
        }
        newTagText = ""
    }

    private func removeTag(_ raw: String) {
        let normalized = Book.normalizeTag(raw)
        if let idx = tags.firstIndex(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            let removed = tags.remove(at: idx)
            scheduleUndoForTag(removed)
        }
    }

    private func scheduleUndoForTag(_ tag: String) {
        lastRemovedTag = tag
        lastRemovedQuote = nil
        showUndoBanner = true
        undoWorkItem?.cancel()
        let wi = DispatchWorkItem { clearUndo() }
        undoWorkItem = wi
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: wi)
    }

    private func scheduleUndoForQuote(_ quote: Quote) {
        lastRemovedQuote = quote
        lastRemovedTag = nil
        showUndoBanner = true
        undoWorkItem?.cancel()
        let wi = DispatchWorkItem { clearUndo() }
        undoWorkItem = wi
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: wi)
    }

    private func performUndo() {
        // restore tag or quote
        if let t = lastRemovedTag {
            if !tags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                tags.append(t)
            }
        } else if let q = lastRemovedQuote {
            // restore quote at end
            quotes.append(q)
        }
        clearUndo()
    }

    private func clearUndo() {
        lastRemovedTag = nil
        lastRemovedQuote = nil
        showUndoBanner = false
        undoWorkItem = nil
    }

    private func addQuote() {
        let trimmed = newQuoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        quotes.append(Quote(text: trimmed))
        newQuoteText = ""
    }

    private func removeQuote(id: UUID) {
        if let q = quotes.first(where: { $0.id == id }) {
            quotes.removeAll { $0.id == id }
            scheduleUndoForQuote(q)
        }
    }

    // simple fuzzy suggestion: returns tags from store that match the term by contains or subsequence
    private func suggestedTags(for term: String) -> [String] {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return [] }
        let candidates = store.availableTags()
        func isSubsequence(_ needle: String, _ hay: String) -> Bool {
            if needle.isEmpty { return true }
            var i = needle.startIndex
            for c in hay {
                if c == needle[i] {
                    i = needle.index(after: i)
                    if i == needle.endIndex { return true }
                }
            }
            return false
        }
        var matches: [String] = []
        for cand in candidates {
            let lower = cand.lowercased()
            if lower.contains(t) { matches.append(cand); continue }
            // remove leading # for subsequence match convenience
            let plain = lower.hasPrefix("#") ? String(lower.dropFirst()) : lower
            if isSubsequence(t, plain) { matches.append(cand); continue }
        }
        return matches
    }

    private func prefillIfNeeded() {
        guard let b = bookToEdit, mode == .edit else { return }
        // used for safe optional unwrapping
        title = b.title
        author = b.author
        rating = b.rating
        notes = b.notes ?? ""
        tags = b.tags
        quotes = b.quotes
    }

    private func save() {
        let saveTags = tags

        if mode == .add {
            let book = Book(title: title, author: author, rating: rating, quotes: quotes, notes: notes.isEmpty ? nil : notes, tags: tags)
            store.add(book)
        } else if mode == .edit, let existing = bookToEdit {
            var updated = existing
            updated.title = title
            updated.author = author
            updated.rating = Book.clampedRating(rating)
            updated.notes = notes.isEmpty ? nil : notes
            updated.tags = Book.normalizeTags(saveTags)
            updated.quotes = quotes
            updated.updatedAt = Date()
            store.update(updated)
        }

        onDone()
    }
}
