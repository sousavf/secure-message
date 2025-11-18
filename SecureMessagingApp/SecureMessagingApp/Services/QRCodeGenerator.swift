import Foundation
import CoreImage
import UIKit

class QRCodeGenerator {
    static func generateQRCode(from string: String, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        print("[DEBUG] QRCodeGenerator - generateQRCode called with string: \(string)")
        let data = string.data(using: String.Encoding.utf8)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel")

            if let ciImage = filter.outputImage {
                print("[DEBUG] QRCodeGenerator - CI Image created with extent: \(ciImage.extent)")
                let scaleX = size.width / ciImage.extent.size.width
                let scaleY = size.height / ciImage.extent.size.height
                let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                let context = CIContext()
                if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
                    print("[DEBUG] QRCodeGenerator - Successfully created UIImage")
                    return UIImage(cgImage: cgImage)
                } else {
                    print("[ERROR] QRCodeGenerator - Failed to create CGImage")
                }
            } else {
                print("[ERROR] QRCodeGenerator - Failed to get outputImage from filter")
            }
        } else {
            print("[ERROR] QRCodeGenerator - Failed to create CIQRCodeGenerator filter")
        }

        return nil
    }

    static func generateQRCodeCIImage(from string: String) -> CIImage? {
        let data = string.data(using: String.Encoding.utf8)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel")
            return filter.outputImage
        }

        return nil
    }
}
