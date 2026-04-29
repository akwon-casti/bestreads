import SwiftUI
import SwiftData

enum AddEditMode {
    case add
    case edit
}

struct AddEditBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Book.sortIndex)]) private var books: [Book]
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

    init(mode: AddEditMode, book: Book? = nil, onDone: @escaping () -> Void) {
        self.mode = mode
        self.bookToEdit = book
        self.onDone = onDone
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
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableTags(), id: \.self) { tag in
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

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Add tag (e.g. #nonfiction)", text: $newTagText, onCommit: addCustomTag)
                                Button(action: addCustomTag) {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            if !newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let suggestions = suggestedTags(for: newTagText)
                                if !suggestions.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(suggestions, id: \.self) { s in
                                                Button(action: {
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
                                        if let lastID = quotes.last?.id {
                                            withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if showUndoBanner {
                    VStack {
                        Spacer()
                        HStack {
                            if let t = lastRemovedTag {
                                Text("Removed \(t)")
                            } else if lastRemovedQuote != nil {
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
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notif in
                guard let info = notif.userInfo,
                      let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let height = max(0, UIScreen.main.bounds.height - frame.origin.y)
                keyboardHeight = height
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        }
    }

    private func toggleTag(_ raw: String) {
        let t = Book.normalizeTag(raw)
        if let idx = tags.firstIndex(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
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
        if let t = lastRemovedTag {
            if !tags.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                tags.append(t)
            }
        } else if let q = lastRemovedQuote {
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

    private func suggestedTags(for term: String) -> [String] {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return [] }
        let candidates = availableTags()
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
        title = b.title
        author = b.author
        rating = b.rating
        notes = b.notes ?? ""
        tags = b.tags
        quotes = b.quotes
    }

    private func save() {
        let normalizedTags = Book.normalizeTags(tags)

        if mode == .add {
            let nextSortIndex = (books.map(\.sortIndex).max() ?? -1) + 1
            let book = Book(
                title: title,
                author: author,
                rating: rating,
                quotes: quotes,
                notes: notes.isEmpty ? nil : notes,
                tags: normalizedTags,
                sortIndex: nextSortIndex
            )
            modelContext.insert(book)
        } else if mode == .edit, let existing = bookToEdit {
            existing.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.rating = Book.clampedRating(rating)
            existing.notes = notes.isEmpty ? nil : notes
            existing.tags = normalizedTags
            existing.quotes = quotes
            existing.updatedAt = Date()
        }

        try? modelContext.save()
        onDone()
    }
}
