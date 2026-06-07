import SwiftUI

/// The signed-in user's profile: avatar, name, bio, stats, and a grid of their
/// own projects. Cozy and personal — soft pastels, rounded type, generous space.
struct ProfileView: View {
    @EnvironmentObject var session: SessionStore

    @StateObject private var model = ProfileViewModel()
    @State private var showEdit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let user = session.currentUser {
                    VStack(spacing: StitchTheme.Spacing.lg) {
                        header(for: user)
                        statsRow
                        projectsSection
                    }
                    .padding(.bottom, StitchTheme.Spacing.xl)
                } else {
                    ProgressView()
                        .padding(.top, 80)
                }
            }
            .background(StitchTheme.Color.background.ignoresSafeArea())
            .navigationTitle("My Nook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEdit = true }
                        .font(StitchTheme.Font.headline)
                        .foregroundStyle(StitchTheme.Color.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) { session.signOut() } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                if let user = session.currentUser {
                    EditProfileView(user: user)
                        .environmentObject(session)
                }
            }
            .task {
                if let id = session.currentUser?.id { await model.load(userId: id) }
            }
            .refreshable {
                if let id = session.currentUser?.id { await model.load(userId: id) }
            }
        }
    }

    // MARK: - Header

    private func header(for user: User) -> some View {
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
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        if let urlString = user.avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .empty: StitchImagePlaceholder(seed: user.id)
                default: StitchImagePlaceholder(seed: user.id)
                }
            }
        } else {
            StitchImagePlaceholder(seed: user.id)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        StitchCard {
            HStack {
                stat(value: model.projectCountText, label: "Projects")
                divider
                stat(value: model.followerCountText, label: "Followers")
                divider
                stat(value: model.followingCountText, label: "Following")
            }
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.xs) {
            Text(value)
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

    // MARK: - Projects

    private let columns = [
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md),
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md)
    ]

    @ViewBuilder
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
            HStack {
                Text("My projects")
                    .font(StitchTheme.Font.headline)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, StitchTheme.Spacing.md)

            switch model.state {
            case .loading where model.projects.isEmpty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StitchTheme.Spacing.xl)
            case .error(let message) where model.projects.isEmpty:
                errorState(message)
            case _ where model.projects.isEmpty:
                emptyState
            default:
                LazyVGrid(columns: columns, spacing: StitchTheme.Spacing.md) {
                    ForEach(model.projects) { project in
                        ProjectGridCell(project: project)
                    }
                }
                .padding(.horizontal, StitchTheme.Spacing.md)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("🧶")
                .font(.system(size: 44))
            Text("No projects yet")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text("Start a make in your Journal and it'll show up here.")
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StitchTheme.Spacing.xl)
        .padding(.horizontal, StitchTheme.Spacing.lg)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("Couldn't load your projects")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { if let id = session.currentUser?.id { await model.load(userId: id) } }
            }
            .font(StitchTheme.Font.headline)
            .foregroundStyle(StitchTheme.Color.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, StitchTheme.Spacing.xl)
        .padding(.horizontal, StitchTheme.Spacing.lg)
    }
}

// MARK: - Project grid cell

private struct ProjectGridCell: View {
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

            StitchTag(text: project.status.label, color: StitchTheme.Color.pastel(for: project.status.rawValue))
        }
    }
}

// MARK: - View model

@MainActor
final class ProfileViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded, error(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var projects: [Project] = []
    @Published private(set) var publicUser: PublicUser?

    private let service = ProfileService()

    var projectCountText: String { countText(publicUser?.projectCount ?? projects.count) }
    var followerCountText: String { countText(publicUser?.followerCount) }
    var followingCountText: String { countText(publicUser?.followingCount) }

    private func countText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)"
    }

    func load(userId: String) async {
        state = .loading
        // Fetch counts and projects together; tolerate a counts failure.
        async let userTask = try? service.publicUser(id: userId)
        do {
            let page = try await service.projects(for: userId)
            projects = page.items
            publicUser = await userTask
            state = .loaded
        } catch {
            publicUser = await userTask
            state = .error(error.localizedDescription)
        }
    }
}
