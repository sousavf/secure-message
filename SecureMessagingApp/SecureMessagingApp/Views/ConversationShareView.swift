import SwiftUI
import UIKit

struct ConversationShareView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var shareLink: String
    let conversationId: UUID
    @State private var qrCodeImage: UIImage?
    @State private var showLinkCopiedAlert = false
    @State private var showImageSaveAlert = false
    @State private var imageShareSheet = false
    @State private var linkShareSheet = false
    @State private var savedImageMessage: String?

    var body: some View {
        print("[DEBUG] ConversationShareView - body rendering with shareLink: \(shareLink)")
        return ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Spacer()
                    Text("Share")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .border(Color.gray.opacity(0.2), width: 1)

                ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48))
                            .foregroundColor(.indigo)

                        Text("Share Conversation")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Invite others to join this private conversation")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                    // QR Code Section
                    VStack(spacing: 12) {
                        Text("Scan to Join")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let qrImage = qrCodeImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 280)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(12)
                                .border(Color.gray.opacity(0.2))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 280)
                                .overlay(
                                    ProgressView()
                                        .tint(.indigo)
                                )
                        }

                        HStack(spacing: 12) {
                            Button(action: saveQRCodeAsImage) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text("Save Image")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.indigo.opacity(0.1))
                                .foregroundColor(.indigo)
                                .cornerRadius(8)
                            }

                            Button(action: shareQRCodeAsImage) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share QR")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.indigo.opacity(0.1))
                                .foregroundColor(.indigo)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Link Section
                    VStack(spacing: 12) {
                        Text("Share Link")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 8) {
                            Text(shareLink)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(3)
                                .truncationMode(.middle)
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                Button(action: copyLinkToClipboard) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Link")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }

                                Button(action: shareLinkViaActivitySheet) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding(16)
            }
            .alert("Copied!", isPresented: $showLinkCopiedAlert) {
                Button("OK") { }
            } message: {
                Text("Link copied to clipboard")
            }
            .alert("Saved!", isPresented: $showImageSaveAlert) {
                Button("OK") { }
            } message: {
                Text(savedImageMessage ?? "QR code image saved to Photos")
            }
            .sheet(isPresented: $imageShareSheet) {
                if let qrImage = qrCodeImage {
                    ActivityViewController(activityItems: [qrImage])
                }
            }
                .sheet(isPresented: $linkShareSheet) {
                    ActivityViewController(activityItems: [shareLink])
                }
                .background(Color(.systemBackground))
                .onAppear {
                    print("[DEBUG] ConversationShareView - onAppear called, generating QR code")
                    generateQRCode()
                }
                .onChange(of: shareLink) { _ in
                    print("[DEBUG] ConversationShareView - shareLink changed, regenerating QR code")
                    generateQRCode()
                }
            }
        }
    }

    private func generateQRCode() {
        print("[DEBUG] ConversationShareView - Generating QR code from shareLink: \(shareLink)")
        print("[DEBUG] ConversationShareView - shareLink length: \(shareLink.count)")
        qrCodeImage = QRCodeGenerator.generateQRCode(from: shareLink, size: CGSize(width: 300, height: 300))
    }

    private func copyLinkToClipboard() {
        UIPasteboard.general.string = shareLink
        showLinkCopiedAlert = true
    }

    private func shareLinkViaActivitySheet() {
        linkShareSheet = true
    }

    private func saveQRCodeAsImage() {
        guard let qrImage = qrCodeImage else { return }

        let imageSaver = ImageSaver()
        imageSaver.successHandler = {
            savedImageMessage = "QR code saved to Photos"
            showImageSaveAlert = true
        }
        imageSaver.errorHandler = { error in
            savedImageMessage = "Failed to save: \(error.localizedDescription)"
            showImageSaveAlert = true
        }
        imageSaver.writeToPhotoAlbum(image: qrImage)
    }

    private func shareQRCodeAsImage() {
        imageShareSheet = true
    }
}

// MARK: - Image Saver Helper

class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((NSError) -> Void)?

    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error as? NSError {
            errorHandler?(error)
        } else {
            successHandler?()
        }
    }
}

#Preview {
    ConversationShareView(
        shareLink: .constant("https://privileged.stratholme.eu/conversations/abc123/join?token=xyz789"),
        conversationId: UUID()
    )
}
