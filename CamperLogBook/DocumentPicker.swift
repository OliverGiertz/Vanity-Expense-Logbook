//
//  DocumentPicker.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 15.02.25.
//


import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.plainText, UTType.commaSeparatedText, UTType.tabSeparatedText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var completion: (URL?) -> Void

        init(completion: @escaping (URL?) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil)
        }
    }
}
