import SwiftUI

/// Fetches a full `Project` by id, then shows `ProjectDetailView`. Used where
/// only a compact project reference is available (e.g. collection items).
struct ProjectLoaderView: View {
    let projectId: String

    @State private var project: Project?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let project {
                ProjectDetailView(project: project)
            } else if let errorMessage {
                errorState(errorMessage)
            } else {
                ProgressView()
                    .tint(StitchTheme.Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(StitchTheme.Color.background)
            }
        }
        .task { await load() }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("Couldn't load this project")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                errorMessage = nil
                Task { await load() }
            }
            .foregroundStyle(StitchTheme.Color.accent)
        }
        .padding(StitchTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StitchTheme.Color.background)
    }

    private func load() async {
        guard project == nil else { return }
        do {
            project = try await FeedService.shared.project(id: projectId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
