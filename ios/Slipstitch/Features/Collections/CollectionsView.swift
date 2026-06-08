import SwiftUI

/// Collections home: a 2-column grid of the user's saved boards.
/// Tap a card to open its detail; use the toolbar "+" to create a new board.
struct CollectionsView: View {
    @StateObject private var model = CollectionsViewModel()
    @State private var showingCreate = false

    private let columns = [
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md),
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md)
    ]

    var body: some View {
        NavigationStack {
            content
                .background(StitchTheme.Color.background)
                .navigationTitle("Collections")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .tint(StitchTheme.Color.accent)
                    }
                }
                .navigationDestination(for: Collection.self) { collection in
                    CollectionDetailView(collectionId: collection.id) {
                        await model.load()
                    }
                }
                .sheet(isPresented: $showingCreate) {
                    CreateCollectionSheet { name, description, isPublic, coverPhotoId in
                        try await model.create(name: name, description: description,
                                               isPublic: isPublic, coverPhotoId: coverPhotoId)
                    }
                }
                .task { await model.load() }
                .refreshable { await model.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .tint(StitchTheme.Color.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            errorState(message)

        case .loaded where model.collections.isEmpty:
            emptyState

        case .loaded:
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: StitchTheme.Spacing.md) {
                ForEach(model.collections) { collection in
                    NavigationLink(value: collection) {
                        CollectionCardView(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(StitchTheme.Spacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: StitchTheme.Spacing.md) {
            Text("🧺")
                .font(.system(size: 56))
            Text("No collections yet")
                .font(StitchTheme.Font.title)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text("Make a cozy board to gather projects and pins you love.")
                .font(StitchTheme.Font.body)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            StitchPrimaryButton(title: "New collection", icon: "plus") {
                showingCreate = true
            }
            .fixedSize()
        }
        .padding(StitchTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.md) {
            Text("😿")
                .font(.system(size: 48))
            Text("Couldn't load collections")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(message)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
            StitchPrimaryButton(title: "Try again") {
                Task { await model.load() }
            }
            .fixedSize()
        }
        .padding(StitchTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View model

@MainActor
final class CollectionsViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var collections: [Collection] = []

    private let service = CollectionsService()

    func load() async {
        if collections.isEmpty { phase = .loading }
        do {
            collections = try await service.list()
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func create(name: String, description: String?, isPublic: Bool, coverPhotoId: String?) async throws {
        let created = try await service.create(name: name, description: description,
                                               isPublic: isPublic, coverPhotoId: coverPhotoId)
        collections.insert(created, at: 0)
        phase = .loaded
    }
}

// MARK: - Create sheet

private struct CreateCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Performs the create; throws to surface an error inside the sheet.
    let onCreate: (String, String?, Bool, String?) async throws -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var coverPhotoId: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cover photo") {
                    CoverPhotoPicker(photoId: $coverPhotoId)
                        .listRowInsets(EdgeInsets())
                }
                Section("Name") {
                    TextField("e.g. Cozy blankets", text: $name)
                }
                Section("Description") {
                    TextField("Optional", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Toggle("Public", isOn: $isPublic)
                        .tint(StitchTheme.Color.accent)
                } footer: {
                    Text(isPublic
                         ? "Anyone can see this board."
                         : "Only you can see this board.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(StitchTheme.Color.background)
            .navigationTitle("New collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await save() } }
                        .disabled(!canSave || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView().tint(StitchTheme.Color.accent)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onCreate(trimmedName, trimmedDesc.isEmpty ? nil : trimmedDesc, isPublic, coverPhotoId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
