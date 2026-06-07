import SwiftUI

/// Pastel rounded card used in the masonry grid for an internal project.
struct ProjectCardView: View {
    let project: Project
    /// Deterministic-but-varied cover height for the Pinterest feel.
    var coverHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            info
        }
        .background(StitchTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var cover: some View {
        Group {
            if let urlString = project.coverUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    case .failure:
                        StitchImagePlaceholder(seed: project.id)
                    case .empty:
                        StitchImagePlaceholder(seed: project.id)
                    @unknown default:
                        StitchImagePlaceholder(seed: project.id)
                    }
                }
            } else {
                StitchImagePlaceholder(seed: project.id)
            }
        }
        .frame(height: coverHeight)
        .frame(maxWidth: .infinity)
        .clipped()
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
            AsyncImage(url: URL(string: pin.imageUrl)) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                case .failure, .empty:
                    StitchImagePlaceholder(seed: pin.id)
                @unknown default:
                    StitchImagePlaceholder(seed: pin.id)
                }
            }
            .frame(height: coverHeight)
            .frame(maxWidth: .infinity)
            .clipped()

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
                    Text(pin.source)
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
