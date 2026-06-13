import SwiftUI

/// Full project detail with like + save-to-collection actions.
struct ProjectDetailView: View {
    let initialProject: Project

    @State private var liked: Bool
    @State private var likeCount: Int
    @State private var isLiking = false
    @State private var showSaveSheet = false
    @State private var showFullCover = false

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
        .contentShape(Rectangle())
        .onTapGesture {
            if initialProject.coverUrl != nil { showFullCover = true }
        }
        .fullScreenPhoto(url: initialProject.coverUrl, isPresented: $showFullCover)
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

            CommentsSection(project: initialProject)
                .padding(.top, StitchTheme.Spacing.sm)
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    private var ownerRow: some View {
        NavigationLink {
            UserProfileView(userId: initialProject.owner.id)
        } label: {
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
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
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

    private var chips: some View {
        MaterialsDisclosure(items: MaterialsDisclosure.items(for: initialProject))
    }

    // Unselected states sit on the adaptive surfaceAlt so they read correctly
    // in both light and dark mode (fixed pastels washed out on dark).
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
                .background(liked
                    ? AnyShapeStyle(StitchTheme.Color.accent)
                    : AnyShapeStyle(StitchTheme.Color.surfaceAlt))
                .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
            }
            .disabled(isLiking)

            Button { showSaveSheet = true } label: {
                HStack(spacing: StitchTheme.Spacing.sm) {
                    Image(systemName: "bookmark")
                    Text("Save")
                }
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(StitchTheme.Color.surfaceAlt)
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

