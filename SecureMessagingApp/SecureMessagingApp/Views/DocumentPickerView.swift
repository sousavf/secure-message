import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    var onFileSelected: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf,
            .text,
            .plainText,
            .data,
            .zip,
            UTType(tag: "doc", tagClass: .filenameExtension, conformingTo: nil) ?? .data,
            UTType(tag: "docx", tagClass: .filenameExtension, conformingTo: nil) ?? .data,
            UTType(tag: "xls", tagClass: .filenameExtension, conformingTo: nil) ?? .data,
            UTType(tag: "xlsx", tagClass: .filenameExtension, conformingTo: nil) ?? .data
        ])

        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onFileSelected(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            controller.dismiss(animated: true)
        }
    }
}
