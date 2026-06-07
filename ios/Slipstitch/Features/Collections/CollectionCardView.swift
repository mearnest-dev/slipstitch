import SwiftUI

/// Grid card for a single collection: cover image, name, item count, and a
/// private/public indicator. Used in the Collections grid.
struct CollectionCardView: View {
    let collection: Collection

    var body: some View {
        StitchCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                cover
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
                    Text(collection.name)
                        .font(StitchTheme.Font.headline)
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: StitchTheme.Spacing.xs) {
                        Image(systemName: collection.isPublic ? "globe" : "lock.fill")
                            .font(.caption2)
                        Text(savesLabel)
                    }
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                }
                .padding(StitchTheme.Spacing.md)
            }
        }
    }

    private var savesLabel: String {
        let n = collection.itemCount
        return "\(n) save\(n == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var cover: some View {
        if let urlString = collection.coverUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .empty:
                    ZStack {
                        StitchImagePlaceholder(seed: collection.id)
                        ProgressView().tint(StitchTheme.Color.accent)
                    }
                case .failure:
                    StitchImagePlaceholder(seed: collection.id)
                @unknown default:
                    StitchImagePlaceholder(seed: collection.id)
                }
            }
        } else {
            StitchImagePlaceholder(seed: collection.id)
        }
    }
}
