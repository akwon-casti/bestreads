import SwiftUI

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(book.title)
                    .font(.headline)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StarRatingView(rating: book.rating)
        }
        .padding(.vertical, 6)
    }
}

struct BookRowView_Previews: PreviewProvider {
    static var previews: some View {
        BookRowView(book: Book(title: "Example", author: "Author", rating: 4, quotes: [], notes: "Notes", tags: ["#nonfiction"]))
            .previewLayout(.sizeThatFits)
    }
}
