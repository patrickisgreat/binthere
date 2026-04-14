import Foundation
import UIKit
import Supabase

enum CloudStorageService {
    private static let bucketName = "item-images"
    private static var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Upload

    static func uploadImage(
        localFilename: String,
        householdId: String,
        entityId: UUID
    ) async throws -> String {
        guard let image = ImageStorageService.loadImage(filename: localFilename),
              let data = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageLoadFailed
        }

        let remotePath = "\(householdId)/\(entityId.uuidString)/\(localFilename)"

        try await client.storage
            .from(bucketName)
            .upload(remotePath, data: data, options: .init(contentType: "image/jpeg", upsert: true))

        return remotePath
    }

    // MARK: - Download

    static func downloadImage(remotePath: String) async throws -> String {
        let data = try await client.storage
            .from(bucketName)
            .download(path: remotePath)

        guard let image = UIImage(data: data) else {
            throw StorageError.imageDecodeFailed
        }

        guard let localFilename = ImageStorageService.saveImage(image) else {
            throw StorageError.localSaveFailed
        }

        return localFilename
    }

    // MARK: - Delete

    static func deleteImage(remotePath: String) async throws {
        try await client.storage
            .from(bucketName)
            .remove(paths: [remotePath])
    }

    // MARK: - Sync helpers

    /// Upload all local images that haven't been uploaded yet for an item
    static func syncItemImages(
        item: Item,
        householdId: String
    ) async {
        for path in item.imagePaths {
            // Skip if it looks like a remote path already
            guard !path.contains("/") else { continue }
            do {
                _ = try await uploadImage(
                    localFilename: path,
                    householdId: householdId,
                    entityId: item.id
                )
            } catch {
                // Non-fatal — image stays local, will retry on next sync
                print("Failed to upload image \(path): \(error)")
            }
        }
    }

    /// Upload bin content images
    static func syncBinImages(
        bin: Bin,
        householdId: String
    ) async {
        for path in bin.contentImagePaths {
            guard !path.contains("/") else { continue }
            do {
                _ = try await uploadImage(
                    localFilename: path,
                    householdId: householdId,
                    entityId: bin.id
                )
            } catch {
                print("Failed to upload bin image \(path): \(error)")
            }
        }
    }
}

enum StorageError: LocalizedError {
    case imageLoadFailed
    case imageDecodeFailed
    case localSaveFailed

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed: "Failed to load local image"
        case .imageDecodeFailed: "Failed to decode downloaded image"
        case .localSaveFailed: "Failed to save image locally"
        }
    }
}
