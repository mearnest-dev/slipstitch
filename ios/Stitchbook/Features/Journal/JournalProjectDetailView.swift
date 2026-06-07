import SwiftUI

/// The journaling heart: a project's cover, details, and a vertical timeline of
/// progress logs (newest first). Status is tappable to change; project fields
/// can be edited; the project can be deleted.
struct JournalProjectDetailView: View {
    let projectId: String
    /// Called when the project changes in a way the list should reflect
    /// (status change, edit, delete).
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ProjectDetailViewModel

    @State private var showingAddProgress = false
    @State private var showingEdit = false
    @State private var showingStatusPicker = false
    @State private var showingDeleteConfirm = false

    init(projectId: String, onChanged: @escaping () -> Void = {}) {
        self.projectId = projectId
        self.onChanged = onChanged
        _model = StateObject(wrappedValue: ProjectDetailViewModel(projectId: projectId))
    }

    var body: some View {
        content
            .background(StitchTheme.Color.background)
            .navigationTitle(model.project?.title ?? "Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingEdit = true
                        } label: {
                            Label("Edit project", systemImage: "pencil")
                        }
                        .disabled(model.project == nil)

                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete project", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .tint(StitchTheme.Color.accent)
                }
            }
            .sheet(isPresented: $showingAddProgress) {
                AddProgressView(projectId: projectId) {
                    Task { await model.reload() ; onChanged() }
                }
            }
            .sheet(isPresented: $showingEdit) {
                if let project = model.project {
                    EditProjectView(project: project) {
                        Task { await model.reload() ; onChanged() }
                    }
                }
            }
            .confirmationDialog("Change status", isPresented: $showingStatusPicker, titleVisibility: .visible) {
                ForEach(ProjectStatus.allCases) { s in
                    Button(s.label) {
                        Task { await model.changeStatus(to: s) ; onChanged() }
                    }
                }
            }
            .confirmationDialog("Delete this project? This can't be undone.",
                                isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await model.delete() {
                            onChanged()
                            dismiss()
                        }
                    }
                }
            }
            .task { if model.project == nil { await model.reload() } }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.project == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let project = model.project {
            loaded(project)
        } else if let message = model.errorMessage {
            errorState(message)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loaded(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StitchTheme.Spacing.lg) {
                cover(project)
                header(project)
                addProgressButton
                timeline
            }
            .padding(.bottom, StitchTheme.Spacing.xl)
        }
        .refreshable { await model.reload() }
    }

    private func cover(_ project: Project) -> some View {
        ZStack {
            if let urlString = project.coverUrl, let url = URL(string: urlString) {
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
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func header(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
            Text(project.title)
                .font(StitchTheme.Font.title)
                .foregroundStyle(StitchTheme.Color.textPrimary)

            Button {
                showingStatusPicker = true
            } label: {
                HStack(spacing: StitchTheme.Spacing.xs) {
                    StitchTag(text: project.status.label, color: project.status.tagColor)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let chips = materialChips(project)
            if !chips.isEmpty {
                FlowChips(chips: chips)
            }
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    private func materialChips(_ project: Project) -> [String] {
        var chips: [String] = []
        if let craft = project.craftType, !craft.isEmpty { chips.append(craft) }
        if let yarn = project.yarn, !yarn.isEmpty { chips.append("🧶 \(yarn)") }
        if let hook = project.hookSize, !hook.isEmpty { chips.append("Hook \(hook)") }
        return chips
    }

    private var addProgressButton: some View {
        StitchPrimaryButton(title: "Add progress", icon: "plus.circle.fill") {
            showingAddProgress = true
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    @ViewBuilder
    private var timeline: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
            Text("Progress")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
                .padding(.horizontal, StitchTheme.Spacing.md)

            if model.logs.isEmpty {
                Text("No entries yet. Log your first rows!")
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .padding(.horizontal, StitchTheme.Spacing.md)
            } else {
                VStack(spacing: StitchTheme.Spacing.md) {
                    ForEach(model.logs) { log in
                        ProgressLogCard(log: log)
                    }
                }
                .padding(.horizontal, StitchTheme.Spacing.md)
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.md) {
            Text("Couldn't load this project")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            StitchPrimaryButton(title: "Try again", icon: "arrow.clockwise") {
                Task { await model.reload() }
            }
            .frame(maxWidth: 220)
        }
        .padding(StitchTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Simple wrapping chip layout for material tags.
private struct FlowChips: View {
    let chips: [String]
    var body: some View {
        // iOS 17 has no native flow layout, so use a simple wrapping approach.
        WrapHStack(items: chips) { chip in
            StitchTag(text: chip, color: StitchTheme.Color.surfaceAlt)
        }
    }
}

/// Minimal wrapping HStack for a handful of chips.
private struct WrapHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .padding(.trailing, StitchTheme.Spacing.xs)
                        .padding(.bottom, StitchTheme.Spacing.xs)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            if item == items.last { width = 0 } else { width -= d.width }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if item == items.last { height = 0 }
                            return result
                        }
                }
            }
        }
        .frame(height: 36)
    }
}

@MainActor
final class ProjectDetailViewModel: ObservableObject {
    let projectId: String

    @Published private(set) var project: Project?
    @Published private(set) var logs: [ProgressLog] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service = JournalService()

    init(projectId: String) {
        self.projectId = projectId
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await service.get(id: projectId)
            project = result.project
            logs = result.logs.sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func changeStatus(to status: ProjectStatus) async {
        guard status != project?.status else { return }
        do {
            project = try await service.updateStatus(id: projectId, status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func delete() async -> Bool {
        do {
            try await service.delete(id: projectId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
