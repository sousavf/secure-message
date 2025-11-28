import SwiftUI
import UIKit

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: Data?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var onCompletion: (UIImage) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                if let imageData = uiImage.jpegData(compressionQuality: 0.8) {
                    parent.selectedImage = imageData
                }
                parent.onCompletion(uiImage)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// Add UTType import
import UniformTypeIdentifiers
