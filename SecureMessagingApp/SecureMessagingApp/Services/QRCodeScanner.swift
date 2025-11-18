import AVFoundation
import Foundation

class QRCodeScanner: NSObject, AVCaptureMetadataOutputObjectsDelegate, ObservableObject {
    @Published var scannedCode: String?
    @Published var isRunning = false
    @Published var errorMessage: String?

    private let captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    override init() {
        super.init()
        setupCamera()
    }

    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("[ERROR] QRCodeScanner - No video device found")
            errorMessage = "Camera not available"
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)

            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                print("[ERROR] QRCodeScanner - Cannot add video input to session")
                errorMessage = "Cannot add video input"
                return
            }
        } catch {
            print("[ERROR] QRCodeScanner - Error setting up video input: \(error)")
            errorMessage = "Camera setup failed"
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("[ERROR] QRCodeScanner - Cannot add metadata output")
            errorMessage = "Metadata setup failed"
            return
        }

        print("[DEBUG] QRCodeScanner - Camera setup complete")
    }

    func startScanning() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                    print("[DEBUG] QRCodeScanner - Scanning started")
                }
            }
        }
    }

    func stopScanning() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            isRunning = false
            print("[DEBUG] QRCodeScanner - Scanning stopped")
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let stringValue = metadataObject.stringValue {
            print("[DEBUG] QRCodeScanner - QR code scanned: \(stringValue)")
            DispatchQueue.main.async {
                self.scannedCode = stringValue
                self.stopScanning()
            }
        }
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }
}
