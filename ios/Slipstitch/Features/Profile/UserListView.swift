import SwiftUI

/// Paginated list of a user's followers or following. Rows open profiles.
struct UserListView: View {
    enum Mode {
        case followers, following
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }

    let userId: String
    let mode: Mode

    @StateObject private var model: UserListViewModel

    init(userId: String, mode: Mode) {
        self.userId = userId
        self.mode = mode
        _model = StateObject(wrappedValue: UserListViewModel(userId: userId, mode: mode))
    }

    var body: some View {
        Group {
            if model.isLoading && model.users.isEmpty {
                ProgressView()
                    .tint(StitchTheme.Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage, model.users.isEmpty {
                errorState(error)
            } else if model.users.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(StitchTheme.Color.background)
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.loadIfNeeded() }
        .refreshable { await model.reload() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.users) { user in
                    NavigationLink {
                        UserProfileView(userId: user.id)
                    } label: {
                        UserRowView(user: user)
                    }
                    .buttonStyle(.plain)
                    .onAppear { model.userAppeared(user) }
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

    private var emptyState: some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("🧶").font(.system(size: 44))
            Text(mode == .followers ? "No followers yet" : "Not following anyone yet")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("Couldn't load")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await model.reload() } }
                .foregroundStyle(StitchTheme.Color.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared row

/// Compact user row: avatar, names, follower count. Used in people search and
/// follower/following lists.
struct UserRowView: View {
    let user: PublicUser

    var body: some View {
        HStack(spacing: StitchTheme.Spacing.sm) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(StitchTheme.Font.headline)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                Text("@\(user.username)")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
            Spacer()
            if let followers = user.followerCount {
                Text("\(followers) follower\(followers == 1 ? "" : "s")")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
        .padding(.vertical, StitchTheme.Spacing.sm)
        .contentShape(Rectangle())
    }

    private var avatar: some View {
        Group {
            if let urlString = user.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        StitchTheme.Color.pastel(for: user.id)
                    }
                }
            } else {
                StitchTheme.Color.pastel(for: user.id)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
}

// MARK: - View model

@MainActor
final class UserListViewModel: ObservableObject {
    @Published private(set) var users: [PublicUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?

    private let userId: String
    private let mode: UserListView.Mode
    private var nextCursor: String?
    private var hasLoaded = false
    private let service = ProfileService()

    init(userId: String, mode: UserListView.Mode) {
        self.userId = userId
        self.mode = mode
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        hasLoaded = true
        isLoading = true
        errorMessage = nil
        do {
            let page = try await fetch(cursor: nil)
            users = page.items
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func userAppeared(_ user: PublicUser) {
        guard user.id == users.last?.id, let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        Task {
            do {
                let page = try await fetch(cursor: cursor)
                let existing = Set(users.map(\.id))
                users.append(contentsOf: page.items.filter { !existing.contains($0.id) })
                nextCursor = page.nextCursor
            } catch {
                // Keep what we have on pagination failure.
            }
            isLoadingMore = false
        }
    }

    private func fetch(cursor: String?) async throws -> Page<PublicUser> {
        switch mode {
        case .followers: return try await service.followers(of: userId, cursor: cursor)
        case .following: return try await service.following(of: userId, cursor: cursor)
        }
    }
}
