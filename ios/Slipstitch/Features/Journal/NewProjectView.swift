import SwiftUI

/// Form sheet for starting a new crochet project.
struct NewProjectView: View {
    var onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore

    @State private var title = ""
    @State private var description = ""
    @State private var craftType = ""
    @State private var yarn = ""
    @State private var yarnWeight = ""
    @State private var hookSize = ""
    @State private var status: ProjectStatus = .planning
    @State private var isPublic = false
    @State private var commentsEnabled = true
    @State private var didSeedDefaults = false
    @State private var coverPhotoId: String?

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = JournalService()

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cover photo") {
                    CoverPhotoPicker(photoId: $coverPhotoId)
                        .listRowInsets(EdgeInsets())
                }

                Section("The make") {
                    TextField("Title", text: $title)
                    TextField("Craft type (amigurumi, blanket…)", text: $craftType)
                        .autocorrectionDisabled()
                    TextField("Notes / description", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Materials") {
                    TextField("Yarn", text: $yarn)
                    Picker("Weight", selection: $yarnWeight) {
                        Text("None").tag("")
                        ForEach(YarnWeight.options, id: \.self) { w in
                            Text(w).tag(w)
                        }
                    }
                    TextField("Hook size", text: $hookSize)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
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
            .navigationTitle("New project")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Seed the comments toggle from the account-level default once.
                if !didSeedDefaults {
                    didSeedDefaults = true
                    commentsEnabled = session.currentUser?.defaultCommentsEnabled ?? true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Create") { save() }
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
        Task {
            do {
                _ = try await service.create(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: trimmed(description),
                    craftType: trimmed(craftType),
                    yarn: trimmed(yarn),
                    yarnWeight: trimmed(yarnWeight),
                    hookSize: trimmed(hookSize),
                    status: status,
                    isPublic: isPublic,
                    commentsEnabled: commentsEnabled,
                    coverPhotoId: coverPhotoId
                )
                onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
