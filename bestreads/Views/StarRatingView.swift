import SwiftUI

struct StarRatingView: View {
    let rating: Int
    var maxRating = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .foregroundStyle(i <= rating ? .yellow : .secondary)
            }
        }
    }
}

struct StarRatingView_Previews: PreviewProvider {
    static var previews: some View {
        StarRatingView(rating: 3)
            .previewLayout(.sizeThatFits)
    }
}
