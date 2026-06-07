import Foundation
import UIKit

/// Reusable direct-to-R2 photo upload helper.
///
/// Implements the three-step presigned upload flow described in `docs/API.md`
/// (Media section). Any feature that needs to attach a photo — profile avatars,
/// journal progress photos, project covers — should reuse this rather than
/// re-implementing the dance:
///
///   1. Load `Data` + `UIImage` from the source to learn the content type,
///      byte size, and pixel dimensions.
///   2. `POST /media/upload-url { contentType, fileSize }` -> `{ photoId, uploadUrl, r2Key }`.
///   3. Raw `URLSession` `PUT` of the image bytes to `uploadUrl` (this is an
///      opaque R2 presigned URL, so it must NOT go through `APIClient`). The
///      `Content-Type` header must match the content type sent in step 2.
///   4. `POST /media/:photoId/complete { width, height, blurhash? }` -> `Photo`.
///
/// Returns the finalized `Photo` (with its public CDN `url`), ready to reference
/// by `id` in a follow-up request (e.g. `PATCH /me { avatarPhotoId }`).
@MainActor
enum MediaUploader {

    enum UploadError: LocalizedError {
        case invalidImageData
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidImageData: return "That image couldn't be read. Try another photo."
            case .encodingFailed: return "Couldn't prepare the image for upload."
            }
        }
    }

    // MARK: - Wire DTOs (Media section of the API contract)

    private struct UploadURLRequest: Encodable {
        let contentType: String
        let fileSize: Int
    }

    private struct UploadURLResponse: Decodable {
        let photoId: String
        let uploadUrl: String
        let r2Key: String
    }

    private struct CompleteRequest: Encodable {
        let width: Int
        let height: Int
        let blurhash: String?
    }

    // MARK: - Public API

    /// Upload raw JPEG/PNG-ish `Data` you already have in hand, plus the decoded
    /// image so we can read its pixel dimensions.
    ///
    /// - Parameters:
    ///   - data: the raw bytes to PUT to R2.
    ///   - image: the decoded image, used for width/height.
    ///   - contentType: MIME type to advertise (defaults to `image/jpeg`).
    /// - Returns: the finalized `Photo` from `/media/:id/complete`.
    static func upload(data: Data,
                       image: UIImage,
                       contentType: String = "image/jpeg") async throws -> Photo {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)

        // Step 2: presigned URL.
        let presign: UploadURLResponse = try await APIClient.shared.send(
            .POST, "/media/upload-url",
            body: UploadURLRequest(contentType: contentType, fileSize: data.count)
        )

        // Step 3: raw PUT to R2 (bypasses APIClient — opaque presigned URL).
        try await putToR2(uploadUrl: presign.uploadUrl, data: data, contentType: contentType)

        // Step 4: confirm and get the finalized Photo.
        let photo: Photo = try await APIClient.shared.send(
            .POST, "/media/\(presign.photoId)/complete",
            body: CompleteRequest(width: width, height: height, blurhash: nil)
        )
        return photo
    }

    /// Convenience: take a JPEG-encodable `UIImage`, compress it, then upload.
    /// Used by the profile avatar picker. `compressionQuality` trades size for fidelity.
    static func uploadJPEG(_ image: UIImage,
                           compressionQuality: CGFloat = 0.85) async throws -> Photo {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw UploadError.encodingFailed
        }
        return try await upload(data: data, image: image, contentType: "image/jpeg")
    }

    // MARK: - R2 PUT

    private static func putToR2(uploadUrl: String, data: Data, contentType: String) async throws {
        guard let url = URL(string: uploadUrl) else { throw UploadError.invalidImageData }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (respData, response): (Data, URLResponse)
        do {
            (respData, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: respData, encoding: .utf8) ?? "Upload failed (\(http.statusCode))"
            throw APIError.http(status: http.statusCode, code: "r2_put_\(http.statusCode)", message: message)
        }
    }
}
