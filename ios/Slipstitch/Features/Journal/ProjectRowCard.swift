import SwiftUI

/// A cozy card summarizing one project in the Journal grid/list:
/// cover image, title, status tag, and a tiny progress hint (log count).
struct ProjectRowCard: View {
    let project: Project

    var body: some View {
        StitchCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                cover
                VStack(alignment: .leading, spacing: StitchTheme.Spacing.sm) {
                    Text(project.title)
                        .font(StitchTheme.Font.headline)
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: StitchTheme.Spacing.sm) {
                        StitchTag(text: project.status.label, color: project.status.tagColor)
                        Spacer(minLength: 0)
                        logHint
                    }
                }
                .padding(StitchTheme.Spacing.md)
            }
        }
    }

    private var cover: some View {
        ZStack {
            if let urlString = project.coverUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        StitchImagePlaceholder(seed: project.id)
                    }
                }
            } else {
                StitchImagePlaceholder(seed: project.id)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var logHint: some View {
        HStack(spacing: StitchTheme.Spacing.xs) {
            Image(systemName: "square.stack.3d.up")
                .font(.caption2)
            Text("\(project.logCount)")
                .font(StitchTheme.Font.caption)
        }
        .foregroundStyle(StitchTheme.Color.textSecondary)
    }
}
