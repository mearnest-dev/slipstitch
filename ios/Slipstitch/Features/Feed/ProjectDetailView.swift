import SwiftUI

/// Full project detail with like + save-to-collection actions.
struct ProjectDetailView: View {
    let initialProject: Project

    @State private var liked: Bool
    @State private var likeCount: Int
    @State private var isLiking = false
    @State private var showSaveSheet = false

    private let service = FeedService.shared

    init(project: Project) {
        self.initialProject = project
        _liked = State(initialValue: project.liked)
        _likeCount = State(initialValue: project.likeCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
                cover
                content
            }
            .padding(.bottom, StitchTheme.Spacing.xl)
        }
        .background(StitchTheme.Color.background)
        .navigationTitle(initialProject.title)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showSaveSheet) {
            SaveToCollectionSheet(target: .project(initialProject.id))
        }
    }

    // MARK: Cover

    private var cover: some View {
        Group {
            if let urlString = initialProject.coverUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image): image.resizable().scaledToFill()
                    case .failure, .empty: StitchImagePlaceholder(seed: initialProject.id)
                    @unknown default: StitchImagePlaceholder(seed: initialProject.id)
                    }
                }
            } else {
                StitchImagePlaceholder(seed: initialProject.id)
            }
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
            Text(initialProject.title)
                .font(StitchTheme.Font.largeTitle)
                .foregroundStyle(StitchTheme.Color.textPrimary)

            ownerRow

            StitchTag(text: initialProject.status.label, color: statusColor)

            if let description = initialProject.description, !description.isEmpty {
                Text(description)
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
            }

            chips

            actions
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    private var ownerRow: some View {
        HStack(spacing: StitchTheme.Spacing.sm) {
            avatar
            VStack(alignment: .leading, spacing: 0) {
                Text(initialProject.owner.displayName)
                    .font(StitchTheme.Font.headline)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                Text("@\(initialProject.owner.username)")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
            Spacer()
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = initialProject.owner.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        StitchTheme.Color.pastel(for: initialProject.owner.id)
                    }
                }
            } else {
                StitchTheme.Color.pastel(for: initialProject.owner.id)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var chips: some View {
        let items = projectChips
        if !items.isEmpty {
            FlowChips(items: items)
        }
    }

    private var projectChips: [(String, Color)] {
        var result: [(String, Color)] = []
        if let craft = initialProject.craftType, !craft.isEmpty {
            result.append((craft, StitchTheme.Color.sky))
        }
        if let yarn = initialProject.yarn, !yarn.isEmpty {
            result.append(("🧶 \(yarn)", StitchTheme.Color.mint))
        }
        if let hook = initialProject.hookSize, !hook.isEmpty {
            result.append(("Hook \(hook)", StitchTheme.Color.butter))
        }
        return result
    }

    private var actions: some View {
        HStack(spacing: StitchTheme.Spacing.md) {
            Button(action: toggleLike) {
                HStack(spacing: StitchTheme.Spacing.sm) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                    Text("\(likeCount)")
                }
                .font(StitchTheme.Font.headline)
                .foregroundStyle(liked ? .white : StitchTheme.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(liked ? StitchTheme.Color.accent : StitchTheme.Color.accentSoft.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
            }
            .disabled(isLiking)

            Button { showSaveSheet = true } label: {
                HStack(spacing: StitchTheme.Spacing.sm) {
                    Image(systemName: "bookmark")
                    Text("Save")
                }
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(StitchTheme.Color.lavender.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
            }
        }
        .padding(.top, StitchTheme.Spacing.sm)
    }

    private var statusColor: Color {
        switch initialProject.status {
        case .planning: return StitchTheme.Color.sky
        case .inProgress: return StitchTheme.Color.butter
        case .finished: return StitchTheme.Color.mint
        case .frogged: return StitchTheme.Color.peach
        }
    }

    // MARK: Actions

    private func toggleLike() {
        guard !isLiking else { return }
        isLiking = true
        let wasLiked = liked
        // Optimistic update.
        liked.toggle()
        likeCount += wasLiked ? -1 : 1

        Task {
            do {
                let response: LikeResponse = wasLiked
                    ? try await service.unlike(projectId: initialProject.id)
                    : try await service.like(projectId: initialProject.id)
                await MainActor.run {
                    liked = response.liked
                    likeCount = response.likeCount
                    isLiking = false
                }
            } catch {
                // Revert on failure.
                await MainActor.run {
                    liked = wasLiked
                    likeCount += wasLiked ? 1 : -1
                    isLiking = false
                }
            }
        }
    }
}

// MARK: - Save to collection sheet

struct SaveToCollectionSheet: View {
    let target: CollectionTarget

    @Environment(\.dismiss) private var dismiss
    @State private var collections: [Collection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var savingId: String?
    @State private var savedId: String?
    @State private var showingNew = false
    @State private var newName = ""

    private let service = FeedService.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(StitchTheme.Color.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, collections.isEmpty {
                    errorState(errorMessage)
                } else {
                    list
                }
            }
            .background(StitchTheme.Color.background)
            .navigationTitle("Save to collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingNew = true } label: { Image(systemName: "plus") }
                        .foregroundStyle(StitchTheme.Color.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StitchTheme.Color.accent)
                }
            }
            .alert("New collection", isPresented: $showingNew) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Create") { createAndSave() }
            } message: {
                Text("Create a collection and save this to it.")
            }
        }
        .task { await load() }
    }

    private var list: some View {
        List {
            if collections.isEmpty {
                Text("No collections yet — tap + to make one.")
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .listRowBackground(StitchTheme.Color.surface)
            }
            ForEach(collections) { collection in
                Button { save(collection) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(collection.name)
                                .font(StitchTheme.Font.headline)
                                .foregroundStyle(StitchTheme.Color.textPrimary)
                            Text("\(collection.itemCount) items")
                                .font(StitchTheme.Font.caption)
                                .foregroundStyle(StitchTheme.Color.textSecondary)
                        }
                        Spacer()
                        if savingId == collection.id {
                            ProgressView().tint(StitchTheme.Color.accent)
                        } else if savedId == collection.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(StitchTheme.Color.accent)
                        } else {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(StitchTheme.Color.textSecondary)
                        }
                    }
                }
                .listRowBackground(StitchTheme.Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("Couldn't load collections")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
                .foregroundStyle(StitchTheme.Color.accent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            collections = try await service.myCollections()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save(_ collection: Collection) {
        guard savingId == nil else { return }
        savingId = collection.id
        Task {
            do {
                _ = try await service.addToCollection(collectionId: collection.id, target: target)
                await MainActor.run {
                    savingId = nil
                    savedId = collection.id
                }
            } catch {
                await MainActor.run {
                    savingId = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func createAndSave() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        newName = ""
        guard !name.isEmpty else { return }
        Task {
            do {
                let created = try await service.createCollection(name: name)
                await MainActor.run { collections.insert(created, at: 0) }
                save(created)
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Simple wrapping chips layout

private struct FlowChips: View {
    let items: [(String, Color)]

    var body: some View {
        // A lightweight wrap using a Layout for iOS 17.
        WrapLayout(spacing: StitchTheme.Spacing.sm) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                StitchTag(text: item.0, color: item.1)
            }
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
