import SwiftUI
import SwiftData

struct BookDetailView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(book.title)
                            .font(.title)
                            .bold()
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StarRatingView(rating: book.rating)
                }

                if let notes = book.notes {
                    Text(notes)
                        .padding(.top, 8)
                }

                if !book.tags.isEmpty {
                    HStack {
                        ForEach(book.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                }

                if !book.quotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quotes")
                            .font(.headline)
                        ForEach(book.quotes) { q in
                            Text("\"\(q.text)\"")
                                .italic()
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit") { showingEdit = true }
                    Button("Delete", role: .destructive) { showingDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddEditBookView(mode: .edit, book: book) {
                showingEdit = false
            }
        }
        .confirmationDialog("Delete this book?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(book)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct BookDetailView_Previews: PreviewProvider {
    static var previews: some View {
        BookDetailView(book: Book.sampleData[0])
            .modelContainer(PreviewContainer.make())
    }
}
