import SwiftUI

/// A fixed-size, always-clipped cover image. The image is an overlay on a
/// fixed-size rectangle, so a `scaledToFill` photo of any aspect ratio is
/// clipped to the frame and can NEVER overflow into adjacent masonry columns.
struct CardCoverImage: View {
    let url: URL?
    let height: CGFloat
    let seed: String

    var body: some View {
        Rectangle()
            .fill(StitchTheme.Color.surfaceAlt)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFill()
                        default:
                            StitchImagePlaceholder(seed: seed)
                        }
                    }
                } else {
                    StitchImagePlaceholder(seed: seed)
                }
            }
            .clipped()
    }
}

/// Pastel rounded card used in the masonry grid for an internal project.
struct ProjectCardView: View {
    let project: Project
    var coverHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardCoverImage(url: project.coverUrl.flatMap(URL.init(string:)),
                           height: coverHeight, seed: project.id)
            info
        }
        .background(StitchTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
            Text(project.title)
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: StitchTheme.Spacing.xs) {
                Text(project.owner.displayName)
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: StitchTheme.Spacing.xs)

                Image(systemName: project.liked ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(StitchTheme.Color.accent)
                Text("\(project.likeCount)")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
        }
        .padding(StitchTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pastel card for an external pin (image + optional title).
struct ExternalPinCardView: View {
    let pin: ExternalPin
    var coverHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardCoverImage(url: URL(string: pin.imageUrl), height: coverHeight, seed: pin.id)

            VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
                if let title = pin.title, !title.isEmpty {
                    Text(title)
                        .font(StitchTheme.Font.headline)
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: StitchTheme.Spacing.xs) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(pin.source.capitalized)
                        .font(StitchTheme.Font.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(StitchTheme.Color.textSecondary)
            }
            .padding(StitchTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(StitchTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
