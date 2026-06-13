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
    @State private var showingFullCover = false

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
        .contentShape(Rectangle())
        .onTapGesture {
            if project.coverUrl != nil { showingFullCover = true }
        }
        .fullScreenPhoto(url: project.coverUrl, isPresented: $showingFullCover)
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

            MaterialsDisclosure(items: MaterialsDisclosure.items(for: project))
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
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
                // Entries threaded together by a strand of yarn down the left.
                VStack(spacing: 0) {
                    ForEach(Array(model.logs.enumerated()), id: \.element.id) { index, log in
                        HStack(alignment: .top, spacing: StitchTheme.Spacing.sm) {
                            YarnStrandGutter(
                                isFirst: index == 0,
                                isLast: index == model.logs.count - 1
                            )
                            .frame(width: 22)

                            NavigationLink {
                                ProgressLogDetailView(log: log, projectTitle: model.project?.title)
                            } label: {
                                ProgressLogCard(log: log)
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, index == model.logs.count - 1 ? 0 : StitchTheme.Spacing.md)
                        }
                        .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Yarn strand timeline

/// The gutter beside each progress entry: a stitch dot aligned with the card's
/// top, threaded onto a gently wavy strand of yarn that runs the full column.
/// The strand starts at the first entry's dot and ends at the last one's.
private struct YarnStrandGutter: View {
    let isFirst: Bool
    let isLast: Bool

    /// Vertical center of the stitch dot, roughly aligned with the card's
    /// first line of content.
    private let dotY: CGFloat = 26

    var body: some View {
        ZStack(alignment: .top) {
            YarnStrandShape(isFirst: isFirst, isLast: isLast, dotY: dotY)
                .stroke(
                    StitchTheme.Color.brand.opacity(0.45),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )

            // A tiny "stitch" knot where the entry hangs off the strand.
            Circle()
                .fill(StitchTheme.Color.brand)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(StitchTheme.Color.brand100, lineWidth: 2))
                .offset(y: dotY - 4.5)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// A vertical strand with a soft sine-wave wobble, so it reads as yarn rather
/// than a ruler line.
private struct YarnStrandShape: Shape {
    let isFirst: Bool
    let isLast: Bool
    let dotY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startY = isFirst ? dotY : rect.minY
        let endY = isLast ? dotY : rect.maxY
        guard endY > startY else { return path }

        let amplitude: CGFloat = 2.5
        let wavelength: CGFloat = 34
        let step: CGFloat = 3

        // Taper the wobble to zero at both ends so consecutive entries' strand
        // segments (each drawn in its own row) join up without a visible kink.
        func x(at y: CGFloat) -> CGFloat {
            let t = (y - startY) / (endY - startY)
            let envelope = sin(t * .pi)
            return rect.midX + amplitude * envelope * sin((y / wavelength) * 2 * .pi)
        }

        path.move(to: CGPoint(x: x(at: startY), y: startY))
        var y = startY + step
        while y < endY {
            path.addLine(to: CGPoint(x: x(at: y), y: y))
            y += step
        }
        path.addLine(to: CGPoint(x: x(at: endY), y: endY))
        return path
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
