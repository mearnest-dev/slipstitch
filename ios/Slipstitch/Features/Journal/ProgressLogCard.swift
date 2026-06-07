import SwiftUI

/// One entry in a project's progress timeline. Shows the optional photo,
/// note, row-count / hours chips, and a relative date.
struct ProgressLogCard: View {
    let log: ProgressLog

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: StitchTheme.Spacing.sm) {
                if let photo = log.photo, let url = URL(string: photo.url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            StitchImagePlaceholder(seed: photo.id)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.sm, style: .continuous))
                }

                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(StitchTheme.Font.body)
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
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

                Text(Self.relativeFormatter.localizedString(for: log.createdAt, relativeTo: Date()))
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
        }
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
