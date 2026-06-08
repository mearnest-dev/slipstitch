import SwiftUI
import PhotosUI

/// Reusable cover-photo picker. Picks an image, uploads it to R2 via
/// `MediaUploader`, and binds the resulting `photoId`. Shows the picked image,
/// an existing cover URL, or an "add cover" prompt.
struct CoverPhotoPicker: View {
    @Binding var photoId: String?
    var existingURL: String? = nil

    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
            PhotosPicker(selection: $item, matching: .images) {
                preview
            }
            .buttonStyle(.plain)

            if isUploading {
                Label("Uploading…", systemImage: "arrow.up.circle")
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            } else if let errorMessage {
                Text(errorMessage).font(StitchTheme.Font.caption).foregroundStyle(.red)
            }
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task { await load(newItem) }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let existingURL, let url = URL(string: existingURL) {
                AsyncImage(url: url) { phase in
                    if case let .success(img) = phase { img.resizable().scaledToFill() } else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
                .padding(StitchTheme.Spacing.sm)
        }
    }

    private var placeholder: some View {
        ZStack {
            StitchTheme.Color.surfaceAlt
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.plus").font(.title2)
                Text("Add a cover photo").font(StitchTheme.Font.caption)
            }
            .foregroundStyle(StitchTheme.Color.textSecondary)
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else {
                errorMessage = "Couldn't read that photo."
                return
            }
            image = img
            isUploading = true
            let photo = try await MediaUploader.uploadJPEG(img)
            photoId = photo.id
            isUploading = false
        } catch {
            isUploading = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Upload failed."
        }
    }
}
