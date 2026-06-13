import SwiftUI

/// Another user's public profile: avatar, bio, stats, follow button, and a
/// grid of their public projects. (The signed-in user's own tab is ProfileView;
/// this view also handles "self" gracefully by hiding the follow button.)
struct UserProfileView: View {
    let userId: String

    @EnvironmentObject private var session: SessionStore
    @StateObject private var model: UserProfileViewModel
    @State private var selectedTab: ProfileTab = .makes

    enum ProfileTab: String, CaseIterable, Identifiable {
        case makes = "Makes"
        case activity = "Activity"
        var id: String { rawValue }
    }

    init(userId: String) {
        self.userId = userId
        _model = StateObject(wrappedValue: UserProfileViewModel(userId: userId))
    }

    private var isSelf: Bool { session.currentUser?.id == userId }

    /// The Activity tab only shows when the user shares it (or it's you).
    private var showsActivity: Bool {
        isSelf || (model.user?.activityVisible ?? true)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: StitchTheme.Spacing.lg) {
                if let user = model.user {
                    header(for: user)
                    if !isSelf {
                        followButton
                    }
                    statsRow(for: user)
                    if showsActivity {
                        tabPicker
                    }
                    if selectedTab == .activity && showsActivity {
                        ActivityListView(userId: userId)
                    } else {
                        projectsSection
                    }
                } else if let error = model.errorMessage {
                    errorState(error)
                } else {
                    ProgressView()
                        .tint(StitchTheme.Color.accent)
                        .padding(.top, 80)
                }
            }
            .padding(.bottom, StitchTheme.Spacing.xl)
        }
        .background(StitchTheme.Color.background.ignoresSafeArea())
        .navigationTitle(model.user.map { "@\($0.username)" } ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    // MARK: Header

    private func header(for user: PublicUser) -> some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            avatar(for: user)
                .frame(width: 104, height: 104)
                .clipShape(Circle())
                .overlay(Circle().stroke(StitchTheme.Color.surface, lineWidth: 4))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .padding(.top, StitchTheme.Spacing.md)

            Text(user.displayName)
                .font(StitchTheme.Font.title)
                .foregroundStyle(StitchTheme.Color.textPrimary)

            Text("@\(user.username)")
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)

            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, StitchTheme.Spacing.xl)
                    .padding(.top, StitchTheme.Spacing.xs)
            }

            if let links = user.socialLinks, !links.isEmpty {
                SocialLinksRow(links: links)
                    .padding(.horizontal, StitchTheme.Spacing.md)
                    .padding(.top, StitchTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tabPicker: some View {
        Picker("Profile section", selection: $selectedTab) {
            ForEach(ProfileTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    @ViewBuilder
    private func avatar(for user: PublicUser) -> some View {
        if let urlString = user.avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: StitchImagePlaceholder(seed: user.id)
                }
            }
        } else {
            StitchImagePlaceholder(seed: user.id)
        }
    }

    // MARK: Follow

    private var followButton: some View {
        Button {
            Task { await model.toggleFollow() }
        } label: {
            HStack(spacing: StitchTheme.Spacing.sm) {
                if model.isTogglingFollow {
                    ProgressView().tint(model.isFollowing ? StitchTheme.Color.accent : .white)
                } else {
                    Image(systemName: model.isFollowing ? "checkmark" : "person.badge.plus")
                    Text(model.isFollowing ? "Following" : "Follow")
                }
            }
            .font(StitchTheme.Font.headline)
            .foregroundStyle(model.isFollowing ? StitchTheme.Color.accent : .white)
            .padding(.horizontal, StitchTheme.Spacing.xl)
            .padding(.vertical, 10)
            .background(
                model.isFollowing
                    ? AnyShapeStyle(StitchTheme.Color.accentSoft.opacity(0.4))
                    : AnyShapeStyle(StitchTheme.Color.brandGradient)
            )
            .clipShape(Capsule())
        }
        .disabled(model.isTogglingFollow)
    }

    // MARK: Stats

    private func statsRow(for user: PublicUser) -> some View {
        StitchCard {
            HStack {
                stat(value: user.projectCount, label: "Projects")
                divider
                NavigationLink {
                    UserListView(userId: userId, mode: .followers)
                } label: {
                    stat(value: model.followerCount, label: "Followers")
                }
                .buttonStyle(.plain)
                divider
                NavigationLink {
                    UserListView(userId: userId, mode: .following)
                } label: {
                    stat(value: user.followingCount, label: "Following")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    private func stat(value: Int?, label: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.xs) {
            Text(value.map(String.init) ?? "—")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(label)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(StitchTheme.Color.divider)
            .frame(width: 1, height: 28)
    }

    // MARK: Projects

    private let columns = [
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md),
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md)
    ]

    @ViewBuilder
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
            Text("Makes")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
                .padding(.horizontal, StitchTheme.Spacing.md)

            if model.projects.isEmpty {
                Text(isSelf ? "No projects yet." : "No public makes yet.")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StitchTheme.Spacing.lg)
            } else {
                LazyVGrid(columns: columns, spacing: StitchTheme.Spacing.md) {
                    ForEach(model.projects) { project in
                        NavigationLink {
                            ProjectDetailView(project: project)
                        } label: {
                            UserProjectCell(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, StitchTheme.Spacing.md)
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("Couldn't load this profile")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await model.load() } }
                .foregroundStyle(StitchTheme.Color.accent)
        }
        .padding(.top, 80)
    }
}

// MARK: - Project cell

private struct UserProjectCell: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
            ZStack {
                if let cover = project.coverUrl, let url = URL(string: cover) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: StitchImagePlaceholder(seed: project.id)
                        }
                    }
                } else {
                    StitchImagePlaceholder(seed: project.id)
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))

            Text(project.title)
                .font(StitchTheme.Font.body)
                .foregroundStyle(StitchTheme.Color.textPrimary)
                .lineLimit(1)

            StitchTag(text: project.status.label,
                      color: StitchTheme.Color.pastel(for: project.status.rawValue))
        }
    }
}

// MARK: - View model

@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published private(set) var user: PublicUser?
    @Published private(set) var projects: [Project] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isFollowing = false
    @Published private(set) var followerCount: Int?
    @Published private(set) var isTogglingFollow = false

    private let userId: String
    private let service = ProfileService()

    init(userId: String) {
        self.userId = userId
    }

    func load() async {
        errorMessage = nil
        do {
            async let projectsTask = try? service.projects(for: userId)
            let fetched = try await service.publicUser(id: userId)
            user = fetched
            isFollowing = fetched.isFollowing ?? false
            followerCount = fetched.followerCount
            projects = (await projectsTask)?.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFollow() async {
        guard !isTogglingFollow else { return }
        isTogglingFollow = true
        let wasFollowing = isFollowing
        // Optimistic update.
        isFollowing = !wasFollowing
        followerCount = (followerCount ?? 0) + (wasFollowing ? -1 : 1)
        do {
            if wasFollowing {
                try await service.unfollow(userId: userId)
            } else {
                try await service.follow(userId: userId)
            }
        } catch {
            // Revert on failure.
            isFollowing = wasFollowing
            followerCount = (followerCount ?? 0) + (wasFollowing ? 1 : -1)
            errorMessage = error.localizedDescription
        }
        isTogglingFollow = false
    }
}
