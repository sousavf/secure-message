import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @StateObject private var scanner = QRCodeScanner()
    @Environment(\.dismiss) var dismiss
    var onScanned: (String) -> Void

    var body: some View {
        ZStack {
            // Camera preview
            QRScannerPreview(scanner: scanner)
                .ignoresSafeArea()

            // Overlay with frame and instructions
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(16)

                Spacer()

                // QR scanning frame
                VStack(spacing: 12) {
                    Text("Point camera at QR code")
                        .font(.headline)
                        .foregroundColor(.white)

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.indigo, lineWidth: 2)
                        .frame(height: 250)
                        .frame(maxWidth: 250)
                }
                .padding(16)
                .background(Color.black.opacity(0.4))
                .cornerRadius(16)

                Spacer()

                if let errorMessage = scanner.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(16)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(16)
                }
            }

            // Success state
            if let scannedCode = scanner.scannedCode {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("QR Code Scanned")
                            .font(.headline)

                        Text(scannedCode)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .truncationMode(.middle)

                        HStack(spacing: 12) {
                            Button(action: {
                                scanner.scannedCode = nil
                                scanner.startScanning()
                            }) {
                                Text("Scan Again")
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.indigo.opacity(0.2))
                                    .foregroundColor(.indigo)
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                onScanned(scannedCode)
                                dismiss()
                            }) {
                                Text("Continue")
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(16)
                    Spacer()
                }
            }
        }
        .onAppear {
            scanner.startScanning()
        }
        .onDisappear {
            scanner.stopScanning()
        }
    }
}

struct QRScannerPreview: UIViewRepresentable {
    let scanner: QRCodeScanner

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = scanner.getPreviewLayer()
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

#Preview {
    QRScannerView { _ in }
}
