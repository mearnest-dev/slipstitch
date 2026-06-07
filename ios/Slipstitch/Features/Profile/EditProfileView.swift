import SwiftUI
import PhotosUI

/// Sheet for editing the signed-in user's profile: display name, bio, and
/// avatar. Avatar changes run through `MediaUploader` (the R2 upload flow) and
/// then `PATCH /me` persists `displayName` / `bio` / `avatarPhotoId` together.
struct EditProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    private let service = ProfileService()

    @State private var displayName: String
    @State private var bio: String

    // Avatar picking / upload state.
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?      // locally previewed selection
    @State private var uploadedPhotoId: String?   // set once R2 upload completes
    @State private var isProcessingPhoto = false

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(user: User) {
        _displayName = State(initialValue: user.displayName)
        _bio = State(initialValue: user.bio ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: StitchTheme.Spacing.lg) {
                    avatarSection
                    fieldsSection
                    if let errorMessage {
                        Text(errorMessage)
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(StitchTheme.Color.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(StitchTheme.Spacing.lg)
            }
            .background(StitchTheme.Color.background.ignoresSafeArea())
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .font(StitchTheme.Font.headline)
                            .foregroundStyle(StitchTheme.Color.accent)
                            .disabled(!canSave)
                    }
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await handlePicked(newItem) }
            }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            ZStack {
                avatarPreview
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(StitchTheme.Color.surface, lineWidth: 4))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                if isProcessingPhoto {
                    Circle()
                        .fill(.black.opacity(0.3))
                        .frame(width: 110, height: 110)
                    ProgressView().tint(.white)
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Text(isProcessingPhoto ? "Uploading…" : "Change photo")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.accent)
            }
            .disabled(isProcessingPhoto)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let pickedImage {
            Image(uiImage: pickedImage)
                .resizable()
                .scaledToFill()
        } else if let urlString = session.currentUser?.avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: StitchImagePlaceholder(seed: session.currentUser?.id ?? "avatar")
                }
            }
        } else {
            StitchImagePlaceholder(seed: session.currentUser?.id ?? "avatar")
        }
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.md) {
            fieldLabel("Display name")
            TextField("Your name", text: $displayName)
                .font(StitchTheme.Font.body)
                .padding(StitchTheme.Spacing.md)
                .background(StitchTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))

            fieldLabel("Bio")
            TextField("Tell us about your crafting…", text: $bio, axis: .vertical)
                .font(StitchTheme.Font.body)
                .lineLimit(3...6)
                .padding(StitchTheme.Spacing.md)
                .background(StitchTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(StitchTheme.Font.caption)
            .foregroundStyle(StitchTheme.Color.textSecondary)
    }

    // MARK: - State helpers

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !isProcessingPhoto
    }

    // MARK: - Actions

    /// Decode the picked item locally for preview, then run the R2 upload so the
    /// `avatarPhotoId` is ready by the time the user taps Save.
    private func handlePicked(_ item: PhotosPickerItem) async {
        errorMessage = nil
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw MediaUploader.UploadError.invalidImageData
            }
            pickedImage = image
            let photo = try await MediaUploader.uploadJPEG(image)
            uploadedPhotoId = photo.id
        } catch {
            pickedImage = nil
            uploadedPhotoId = nil
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let current = session.currentUser else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

        // Only send changed fields.
        let nameChanged = trimmedName != current.displayName
        let bioChanged = trimmedBio != (current.bio ?? "")

        do {
            let updated = try await service.updateProfile(
                displayName: nameChanged ? trimmedName : nil,
                bio: bioChanged ? trimmedBio : nil,
                avatarPhotoId: uploadedPhotoId
            )
            session.updateUser(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
