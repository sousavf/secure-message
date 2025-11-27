import Foundation
import CryptoKit
import UIKit

class FileService {
    static let shared = FileService()

    // File size limits (in bytes)
    let maxFileSizeBytes = 10 * 1024 * 1024  // 10MB
    let jpegCompressionQuality: CGFloat = 0.8  // 80% quality for photos

    // MARK: - File Compression

    /// Compress a photo/image file
    func compressImage(_ imageData: Data) throws -> Data {
        guard let image = UIImage(data: imageData) else {
            throw FileServiceError.invalidImageData
        }

        // Compress to JPEG format with quality setting
        guard let compressedData = image.jpegData(compressionQuality: jpegCompressionQuality) else {
            throw FileServiceError.compressionFailed
        }

        // Check if compressed size is under limit
        if compressedData.count > maxFileSizeBytes {
            throw FileServiceError.fileTooLarge(
                "Image is \(formatFileSize(compressedData.count)), max is \(formatFileSize(maxFileSizeBytes))"
            )
        }

        return compressedData
    }

    /// Validate file size
    func validateFileSize(_ data: Data) throws {
        if data.count > maxFileSizeBytes {
            throw FileServiceError.fileTooLarge(
                "File is \(formatFileSize(data.count)), max is \(formatFileSize(maxFileSizeBytes))"
            )
        }
    }

    // MARK: - File Encryption

    /// Encrypt file data with conversation key
    func encryptFile(_ fileData: Data, key: SymmetricKey) throws -> EncryptedFile {
        let nonce = NIST.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(fileData, using: key, nonce: nonce)

        guard let ciphertext = sealedBox.ciphertext.base64EncodedString().isEmpty == false ?
              sealedBox.ciphertext.base64EncodedString() : nil else {
            throw FileServiceError.encryptionFailed
        }

        let nonceString = nonce.withUnsafeBytes { Data($0).base64EncodedString() }
        let tagString = sealedBox.tag.base64EncodedString()

        return EncryptedFile(
            ciphertext: ciphertext,
            nonce: nonceString,
            tag: tagString
        )
    }

    /// Decrypt file data with conversation key
    func decryptFile(_ encryptedFile: EncryptedFile, key: SymmetricKey) throws -> Data {
        guard let ciphertextData = Data(base64Encoded: encryptedFile.ciphertext),
              let nonceData = Data(base64Encoded: encryptedFile.nonce),
              let tagData = Data(base64Encoded: encryptedFile.tag),
              let nonce = try? NIST.GCM.Nonce(data: nonceData) else {
            throw FileServiceError.decryptionFailed
        }

        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertextData, tag: tagData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    // MARK: - File Utilities

    /// Generate thumbnail from image data
    func generateThumbnail(from imageData: Data, size: CGSize = CGSize(width: 200, height: 200)) throws -> UIImage {
        guard let image = UIImage(data: imageData) else {
            throw FileServiceError.invalidImageData
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        return thumbnail
    }

    /// Format file size for display (e.g., "5.2 MB")
    func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Get MIME type from file name
    func getMimeType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()

        let mimeTypes: [String: String] = [
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "webp": "image/webp",
            "pdf": "application/pdf",
            "txt": "text/plain",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "zip": "application/zip"
        ]

        return mimeTypes[ext] ?? "application/octet-stream"
    }

    /// Get file extension from MIME type
    func getFileExtension(for mimeType: String) -> String {
        let extensions: [String: String] = [
            "image/jpeg": "jpg",
            "image/png": "png",
            "image/gif": "gif",
            "image/webp": "webp",
            "application/pdf": "pdf",
            "text/plain": "txt",
            "application/msword": "doc",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
            "application/vnd.ms-excel": "xls",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "xlsx",
            "application/zip": "zip"
        ]

        return extensions[mimeType] ?? "bin"
    }
}

// MARK: - Models

struct EncryptedFile: Codable {
    let ciphertext: String
    let nonce: String
    let tag: String
}

enum FileServiceError: Error, LocalizedError {
    case fileTooLarge(String)
    case invalidImageData
    case compressionFailed
    case encryptionFailed
    case decryptionFailed
    case invalidFileData

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let message):
            return message
        case .invalidImageData:
            return "Invalid image data"
        case .compressionFailed:
            return "Failed to compress image"
        case .encryptionFailed:
            return "Failed to encrypt file"
        case .decryptionFailed:
            return "Failed to decrypt file"
        case .invalidFileData:
            return "Invalid file data"
        }
    }
}
