import SwiftUI
import AVFoundation
import Vision

struct QRScannerView: View {
    @Environment(\.dismiss) var dismiss
    var onScanned: (String) -> Void
    @State private var cameraPermissionGranted = false
    @State private var showingPermissionAlert = false
    @State private var scannedCode: String?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if cameraPermissionGranted {
                // Camera view with live QR code scanning
                CameraView(scannedCode: $scannedCode)
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
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.indigo)
                    Text("Camera Access Required")
                        .font(.headline)
                    Text("We need camera access to scan QR codes")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Button(action: requestCameraPermission) {
                        Text("Grant Permission")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(24)
            }

            // Success state
            if let code = scannedCode {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("QR Code Scanned")
                            .font(.headline)

                        Text(code)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                            .truncationMode(.middle)

                        HStack(spacing: 12) {
                            Button(action: {
                                scannedCode = nil
                            }) {
                                Text("Scan Again")
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.indigo.opacity(0.2))
                                    .foregroundColor(.indigo)
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                onScanned(code)
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
            requestCameraPermission()
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.cameraPermissionGranted = granted
                if !granted {
                    self.errorMessage = "Camera access denied. Please enable it in Settings."
                }
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = CameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode)
    }

    class Coordinator: NSObject {
        @Binding var scannedCode: String?

        init(scannedCode: Binding<String?>) {
            self._scannedCode = scannedCode
        }
    }
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    var delegate: CameraView.Coordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func setupCamera() {
        captureSession.sessionPreset = .high

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let results = request.results as? [VNBarcodeObservation] else { return }
            for result in results {
                if result.symbology == .qr, let payload = result.payloadStringValue {
                    DispatchQueue.main.async {
                        self?.delegate?.scannedCode = payload
                        self?.captureSession.stopRunning()
                    }
                    return
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
}

#Preview {
    QRScannerView { _ in }
}
