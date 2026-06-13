import SwiftUI

/// A user's recent public activity: new projects, progress, comments, likes,
/// and follows, newest first with infinite scroll. Embedded in profile pages
/// (not independently scrollable — it lives inside the profile's ScrollView).
struct ActivityListView: View {
    let userId: String

    @StateObject private var model: ActivityViewModel

    init(userId: String) {
        self.userId = userId
        _model = StateObject(wrappedValue: ActivityViewModel(userId: userId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isLoading && model.items.isEmpty {
                ProgressView()
                    .tint(StitchTheme.Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StitchTheme.Spacing.xl)
            } else if let error = model.errorMessage, model.items.isEmpty {
                Text(error)
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StitchTheme.Spacing.lg)
            } else if model.items.isEmpty {
                Text("No activity yet.")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StitchTheme.Spacing.lg)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(model.items) { item in
                        ActivityRow(item: item)
                            .onAppear { model.itemAppeared(item) }
                        Divider().overlay(StitchTheme.Color.divider)
                    }
                    if model.isLoadingMore {
                        ProgressView()
                            .tint(StitchTheme.Color.accent)
                            .padding(.vertical, StitchTheme.Spacing.md)
                    }
                }
            }
        }
        .task { await model.loadIfNeeded() }
    }
}

// MARK: - Row

private struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: StitchTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(StitchTheme.Color.accent)
                .frame(width: 26)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                title
                if let body = item.body, !body.isEmpty {
                    Text("“\(body)”")
                        .font(StitchTheme.Font.caption)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                        .lineLimit(2)
                }
                Text(item.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }

            Spacer(minLength: 0)

            thumbnail
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
        .padding(.vertical, StitchTheme.Spacing.sm)
        .background(destinationLink)
    }

    @ViewBuilder
    private var title: some View {
        switch item.type {
        case "project":
            text("Started a new project: \(item.project?.title ?? "a make")")
        case "progress":
            text("Logged progress on \(item.project?.title ?? "a project")")
        case "comment":
            text("Commented on \(item.project?.title ?? "a project")")
        case "like":
            text("Liked \(item.project?.title ?? "a project")")
        case "follow":
            text("Started following \(item.user.map { "@\($0.username)" } ?? "someone")")
        default:
            text(item.type)
        }
    }

    private func text(_ s: String) -> some View {
        Text(s)
            .font(StitchTheme.Font.body)
            .foregroundStyle(StitchTheme.Color.textPrimary)
            .multilineTextAlignment(.leading)
    }

    private var icon: String {
        switch item.type {
        case "project": return "plus.square.on.square"
        case "progress": return "chart.line.uptrend.xyaxis"
        case "comment": return "bubble.left"
        case "like": return "heart"
        case "follow": return "person.badge.plus"
        default: return "sparkles"
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let cover = item.project?.coverUrl, let url = URL(string: cover) {
            AsyncImage(url: url) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    StitchTheme.Color.pastel(for: item.project?.id ?? item.id)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.sm, style: .continuous))
        } else if let avatar = item.user?.avatarUrl, let url = URL(string: avatar) {
            AsyncImage(url: url) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    StitchTheme.Color.pastel(for: item.user?.id ?? item.id)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        }
    }

    /// Invisible NavigationLink behind the row: project events open the
    /// project, follow events open the followed user's profile.
    @ViewBuilder
    private var destinationLink: some View {
        if let project = item.project {
            NavigationLink {
                ProjectLoaderView(projectId: project.id)
            } label: { Color.clear }
            .opacity(0)
        } else if let user = item.user {
            NavigationLink {
                UserProfileView(userId: user.id)
            } label: { Color.clear }
            .opacity(0)
        }
    }
}

// MARK: - View model

@MainActor
final class ActivityViewModel: ObservableObject {
    @Published private(set) var items: [ActivityItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?

    private let userId: String
    private var nextCursor: String?
    private var hasLoaded = false
    private let service = ProfileService()

    init(userId: String) {
        self.userId = userId
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        do {
            let page = try await service.activity(for: userId)
            items = page.items
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func itemAppeared(_ item: ActivityItem) {
        guard item.id == items.last?.id, let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            do {
                let page = try await service.activity(for: userId, before: cursor)
                let existing = Set(items.map(\.id))
                items.append(contentsOf: page.items.filter { !existing.contains($0.id) })
                nextCursor = page.nextCursor
            } catch {
                // Keep what we have.
            }
            isLoadingMore = false
        }
    }
}
