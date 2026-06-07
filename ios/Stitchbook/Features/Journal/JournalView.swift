import SwiftUI

/// The Journal home: the maker's crochet projects as a warm 2-column grid.
/// Tapping a card opens its progress timeline; the "+" toolbar starts a new one.
struct JournalView: View {
    @StateObject private var model = JournalViewModel()
    @State private var showingNew = false

    private let columns = [
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md),
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            content
                .background(StitchTheme.Color.background)
                .navigationTitle("Journal")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingNew = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                        }
                        .tint(StitchTheme.Color.accent)
                    }
                }
                .sheet(isPresented: $showingNew) {
                    NewProjectView { Task { await model.load() } }
                }
                .task {
                    if model.projects.isEmpty { await model.load() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading where model.projects.isEmpty:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message) where model.projects.isEmpty:
            errorState(message)
        default:
            if model.projects.isEmpty {
                emptyState
            } else {
                grid
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: StitchTheme.Spacing.md) {
                ForEach(model.projects) { project in
                    NavigationLink {
                        ProjectDetailView(projectId: project.id) {
                            Task { await model.load() }
                        }
                    } label: {
                        ProjectRowCard(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(StitchTheme.Spacing.md)
        }
        .refreshable { await model.load() }
    }

    private var emptyState: some View {
        VStack(spacing: StitchTheme.Spacing.md) {
            Text("🧶")
                .font(.system(size: 56))
            Text("Start your first make")
                .font(StitchTheme.Font.title)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text("Track a crochet project and log your progress row by row.")
                .font(StitchTheme.Font.body)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            StitchPrimaryButton(title: "New project", icon: "plus") {
                showingNew = true
            }
            .frame(maxWidth: 260)
        }
        .padding(StitchTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.md) {
            Text("Couldn't load your journal")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            StitchPrimaryButton(title: "Try again", icon: "arrow.clockwise") {
                Task { await model.load() }
            }
            .frame(maxWidth: 220)
        }
        .padding(StitchTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class JournalViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, loaded, error(String)
    }

    @Published private(set) var projects: [Project] = []
    @Published private(set) var phase: Phase = .idle

    private let service = JournalService()

    func load() async {
        phase = .loading
        do {
            let page = try await service.myProjects()
            projects = page.items
            phase = .loaded
        } catch {
            phase = .error(error.localizedDescription)
        }
    }
}
