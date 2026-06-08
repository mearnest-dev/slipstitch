import SwiftUI
import PhotosUI

/// Sheet to log a new progress entry on a project.
/// Note + optional row count + optional hours + optional photo.
struct AddProgressView: View {
    let projectId: String
    var onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var includeRows = false
    @State private var rowCount = 1
    @State private var includeHours = false
    @State private var hoursText = ""

    // Photo attachment
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var uploadedPhotoId: String?
    @State private var isUploadingPhoto = false

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = JournalService()

    private var canSave: Bool {
        let hasNote = !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasContent = hasNote || includeRows || (includeHours && (Double(hoursText) ?? 0) > 0) || uploadedPhotoId != nil
        return hasContent && !isSaving && !isUploadingPhoto
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened") {
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("Today I worked on…")
                                    .font(StitchTheme.Font.body)
                                    .foregroundStyle(StitchTheme.Color.textSecondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Photo") {
                    photoRow
                }

                Section("Rows") {
                    Toggle("Log rows", isOn: $includeRows)
                    if includeRows {
                        Stepper("+\(rowCount) rows", value: $rowCount, in: 1...10000)
                    }
                }

                Section("Time") {
                    Toggle("Log hours", isOn: $includeHours)
                    if includeHours {
                        TextField("Hours (e.g. 1.5)", text: $hoursText)
                            .keyboardType(.decimalPad)
                    }
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
            .navigationTitle("Add progress")
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
            .onChange(of: pickerItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadAndUpload(newItem) }
            }
        }
    }

    @ViewBuilder
    private var photoRow: some View {
        if let image = pickedImage {
            HStack(spacing: StitchTheme.Spacing.md) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.sm, style: .continuous))
                if isUploadingPhoto {
                    ProgressView().tint(StitchTheme.Color.accent)
                    Text("Uploading…").font(StitchTheme.Font.caption)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                } else if uploadedPhotoId != nil {
                    Label("Attached", systemImage: "checkmark.circle.fill")
                        .font(StitchTheme.Font.caption)
                        .foregroundStyle(StitchTheme.Color.accent)
                }
                Spacer()
                Button(role: .destructive) {
                    pickerItem = nil; pickedImage = nil; uploadedPhotoId = nil
                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(StitchTheme.Color.textSecondary) }
            }
        } else {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Add a photo", systemImage: "photo.badge.plus")
                    .foregroundStyle(StitchTheme.Color.accent)
            }
        }
    }

    private func loadAndUpload(_ item: PhotosPickerItem) async {
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Couldn't read that photo."
                return
            }
            pickedImage = image
            isUploadingPhoto = true
            let photo = try await MediaUploader.uploadJPEG(image)
            uploadedPhotoId = photo.id
            isUploadingPhoto = false
        } catch {
            isUploadingPhoto = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Photo upload failed."
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows: Int? = includeRows ? rowCount : nil
        let hours: Double? = includeHours ? Double(hoursText) : nil
        Task {
            do {
                _ = try await service.addLog(
                    projectId: projectId,
                    note: trimmedNote.isEmpty ? nil : trimmedNote,
                    rowCount: rows,
                    hoursSpent: hours,
                    photoId: uploadedPhotoId
                )
                onAdded()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
