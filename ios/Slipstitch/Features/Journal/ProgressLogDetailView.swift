import SwiftUI

/// Full-screen view of a single progress entry: large photo (when present),
/// the full note, metrics, and the exact date.
struct ProgressLogDetailView: View {
    let log: ProgressLog
    /// Project title, shown as context under the date.
    var projectTitle: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
                if let photo = log.photo, let url = URL(string: photo.url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .empty:
                            ZStack {
                                StitchImagePlaceholder(seed: photo.id)
                                ProgressView().tint(StitchTheme.Color.accent)
                            }
                            .frame(height: 280)
                        default:
                            StitchImagePlaceholder(seed: photo.id)
                                .frame(height: 280)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
                }

                if hasMetrics {
                    HStack(spacing: StitchTheme.Spacing.sm) {
                        if let rows = log.rowCount, rows != 0 {
                            StitchTag(text: "+\(rows) rows", color: StitchTheme.Color.mint)
                        }
                        if let hours = log.hoursSpent, hours > 0 {
                            StitchTag(text: hoursLabel(hours), color: StitchTheme.Color.lavender)
                        }
                    }
                }

                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(StitchTheme.Font.body)
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
                    Text(log.createdAt.formatted(date: .long, time: .shortened))
                        .font(StitchTheme.Font.caption)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                    if let projectTitle, !projectTitle.isEmpty {
                        Text(projectTitle)
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(StitchTheme.Spacing.md)
        }
        .background(StitchTheme.Color.background)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasMetrics: Bool {
        (log.rowCount ?? 0) != 0 || (log.hoursSpent ?? 0) > 0
    }

    private func hoursLabel(_ hours: Double) -> String {
        let trimmed = hours.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(hours))
            : String(format: "%.1f", hours)
        return "\(trimmed) hrs"
    }
}
