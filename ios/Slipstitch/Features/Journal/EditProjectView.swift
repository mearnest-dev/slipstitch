import SwiftUI

/// Edit sheet for an existing project. PATCHes changed fields.
struct EditProjectView: View {
    let project: Project
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var craftType: String
    @State private var yarn: String
    @State private var yarnWeight: String
    @State private var hookSize: String
    @State private var isPublic: Bool
    @State private var commentsEnabled: Bool
    @State private var coverPhotoId: String?

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = JournalService()

    init(project: Project, onSaved: @escaping () -> Void) {
        self.project = project
        self.onSaved = onSaved
        _title = State(initialValue: project.title)
        _description = State(initialValue: project.description ?? "")
        _craftType = State(initialValue: project.craftType ?? "")
        _yarn = State(initialValue: project.yarn ?? "")
        _yarnWeight = State(initialValue: project.yarnWeight ?? "")
        _hookSize = State(initialValue: project.hookSize ?? "")
        _isPublic = State(initialValue: project.isPublic)
        _commentsEnabled = State(initialValue: project.commentsEnabled ?? true)
    }

    /// Standard weights, plus the project's current custom value if it has one.
    private var weightOptions: [String] {
        if !yarnWeight.isEmpty && !YarnWeight.options.contains(yarnWeight) {
            return YarnWeight.options + [yarnWeight]
        }
        return YarnWeight.options
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cover photo") {
                    CoverPhotoPicker(photoId: $coverPhotoId, existingURL: project.coverUrl)
                        .listRowInsets(EdgeInsets())
                }

                Section("The make") {
                    TextField("Title", text: $title)
                    TextField("Craft type", text: $craftType)
                        .autocorrectionDisabled()
                    TextField("Notes / description", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Materials") {
                    TextField("Yarn", text: $yarn)
                    Picker("Weight", selection: $yarnWeight) {
                        Text("None").tag("")
                        ForEach(weightOptions, id: \.self) { w in
                            Text(w).tag(w)
                        }
                    }
                    TextField("Hook size", text: $hookSize)
                }

                Section {
                    Toggle("Share publicly", isOn: $isPublic)
                    Toggle("Allow comments", isOn: $commentsEnabled)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(StitchTheme.Color.accent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(StitchTheme.Color.background)
            .navigationTitle("Edit project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        let trimmed = { (s: String) -> String? in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        let input = JournalService.ProjectInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmed(description),
            craftType: trimmed(craftType),
            yarn: trimmed(yarn),
            yarnWeight: trimmed(yarnWeight),
            hookSize: trimmed(hookSize),
            status: nil,
            isPublic: isPublic,
            commentsEnabled: commentsEnabled,
            coverPhotoId: coverPhotoId
        )
        Task {
            do {
                _ = try await service.update(id: project.id, input)
                onSaved()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
