import SwiftUI

/// A single collection board: header (name/description), edit + delete actions,
/// and a 2-column grid of saved items (projects and external pins).
struct CollectionDetailView: View {
    let collectionId: String
    /// Called after the collection is edited or deleted so the parent list can refresh.
    var onChange: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: CollectionDetailViewModel
    @State private var showingEdit = false
    @State private var showingDeleteConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md),
        GridItem(.flexible(), spacing: StitchTheme.Spacing.md)
    ]

    init(collectionId: String, onChange: (() async -> Void)? = nil) {
        self.collectionId = collectionId
        self.onChange = onChange
        _model = StateObject(wrappedValue: CollectionDetailViewModel(collectionId: collectionId))
    }

    var body: some View {
        content
            .background(StitchTheme.Color.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(model.collection?.name ?? "Collection")
            .toolbar {
                if model.collection != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingEdit = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                Label("Delete collection", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .tint(StitchTheme.Color.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                if let collection = model.collection {
                    EditCollectionSheet(collection: collection) { name, description, isPublic in
                        try await model.update(name: name, description: description, isPublic: isPublic)
                        await onChange?()
                    }
                }
            }
            .alert("Delete this collection?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await model.deleteCollection() {
                            await onChange?()
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the board and its saves. This can't be undone.")
            }
            .task { await model.load() }
            .refreshable { await model.load() }
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

        case .loaded:
            loaded
        }
    }

    private var loaded: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StitchTheme.Spacing.lg) {
                header

                if model.items.isEmpty {
                    emptyItems
                } else {
                    LazyVGrid(columns: columns, spacing: StitchTheme.Spacing.md) {
                        ForEach(model.items) { item in
                            CollectionItemCardView(item: item) {
                                Task { await model.remove(item: item) }
                            }
                        }
                    }
                }
            }
            .padding(StitchTheme.Spacing.md)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let collection = model.collection {
            VStack(alignment: .leading, spacing: StitchTheme.Spacing.sm) {
                HStack(spacing: StitchTheme.Spacing.sm) {
                    StitchTag(
                        text: collection.isPublic ? "Public" : "Private",
                        color: collection.isPublic ? StitchTheme.Color.mint : StitchTheme.Color.lavender
                    )
                    Text("\(collection.itemCount) save\(collection.itemCount == 1 ? "" : "s")")
                        .font(StitchTheme.Font.caption)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                }
                if let description = collection.description, !description.isEmpty {
                    Text(description)
                        .font(StitchTheme.Font.body)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                }
            }
        }
    }

    private var emptyItems: some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            Text("🪡")
                .font(.system(size: 44))
            Text("Nothing saved here yet")
                .font(StitchTheme.Font.headline)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text("Add projects and pins to fill out this board.")
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, StitchTheme.Spacing.xl)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: StitchTheme.Spacing.md) {
            Text("😿").font(.system(size: 48))
            Text("Couldn't load this board")
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

// MARK: - Item card

private struct CollectionItemCardView: View {
    let item: CollectionItem
    let onRemove: () -> Void

    var body: some View {
        StitchCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                cover
                    .frame(height: 130)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
                    Text(title)
                        .font(StitchTheme.Font.body)
                        .foregroundStyle(StitchTheme.Color.textPrimary)
                        .lineLimit(2)
                    StitchTag(
                        text: item.kind == "pin" ? "Pin" : "Project",
                        color: item.kind == "pin" ? StitchTheme.Color.peach : StitchTheme.Color.sky
                    )
                }
                .padding(StitchTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onRemove) {
                Label("Remove from collection", systemImage: "trash")
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            .padding(StitchTheme.Spacing.xs)
        }
    }

    private var title: String {
        switch item.kind {
        case "pin": return item.pin?.title ?? "Pin"
        default: return item.project?.title ?? "Project"
        }
    }

    private var imageURLString: String? {
        switch item.kind {
        case "pin": return item.pin?.imageUrl
        default: return item.project?.coverUrl
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let urlString = imageURLString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .empty:
                    ZStack {
                        StitchImagePlaceholder(seed: item.id)
                        ProgressView().tint(StitchTheme.Color.accent)
                    }
                case .failure:
                    StitchImagePlaceholder(seed: item.id)
                @unknown default:
                    StitchImagePlaceholder(seed: item.id)
                }
            }
        } else {
            StitchImagePlaceholder(seed: item.id)
        }
    }
}

// MARK: - View model

@MainActor
final class CollectionDetailViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var collection: Collection?
    @Published private(set) var items: [CollectionItem] = []

    private let collectionId: String
    private let service = CollectionsService()

    init(collectionId: String) {
        self.collectionId = collectionId
    }

    func load() async {
        if collection == nil { phase = .loading }
        do {
            let detail = try await service.get(id: collectionId)
            collection = detail.collection
            items = detail.items
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func update(name: String?, description: String?, isPublic: Bool?) async throws {
        let updated = try await service.update(
            id: collectionId, name: name, description: description, isPublic: isPublic
        )
        collection = updated
    }

    func remove(item: CollectionItem) async {
        do {
            try await service.removeItem(collectionId: collectionId, itemId: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Returns true on success.
    func deleteCollection() async -> Bool {
        do {
            try await service.delete(id: collectionId)
            return true
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
    }
}

// MARK: - Edit sheet

private struct EditCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let collection: Collection
    let onSave: (String, String?, Bool) async throws -> Void

    @State private var name: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(collection: Collection, onSave: @escaping (String, String?, Bool) async throws -> Void) {
        self.collection = collection
        self.onSave = onSave
        _name = State(initialValue: collection.name)
        _description = State(initialValue: collection.description ?? "")
        _isPublic = State(initialValue: collection.isPublic)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section("Description") {
                    TextField("Optional", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Toggle("Public", isOn: $isPublic)
                        .tint(StitchTheme.Color.accent)
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
            .navigationTitle("Edit collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
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
            try await onSave(trimmedName, trimmedDesc.isEmpty ? nil : trimmedDesc, isPublic)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
