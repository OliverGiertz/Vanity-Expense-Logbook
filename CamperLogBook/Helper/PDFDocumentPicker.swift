//
//  PDFDocumentPicker.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 16.02.25.
//

import SwiftUI
import UniformTypeIdentifiers
import VisionKit  // Wichtiger Import für VNDocumentCameraViewController und zugehörige Typen

struct PDFDocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
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

extension PDFDocumentPicker {
    // Diese View wird zum Scannen von Dokumenten mittels VNDocumentCameraViewController genutzt.
    struct DocumentScannerView: UIViewControllerRepresentable {
        var completion: ([UIImage]) -> Void
        
        // Explizite Angabe des Typs
        typealias UIViewControllerType = VNDocumentCameraViewController
        
        func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
            let scannerVC = VNDocumentCameraViewController()
            scannerVC.delegate = context.coordinator
            return scannerVC
        }
        
        func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(completion: completion)
        }
        
        class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
            var completion: ([UIImage]) -> Void
            
            init(completion: @escaping ([UIImage]) -> Void) {
                self.completion = completion
            }
            
            func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
                var images = [UIImage]()
                for index in 0..<scan.pageCount {
                    images.append(scan.imageOfPage(at: index))
                }
                controller.dismiss(animated: true) {
                    self.completion(images)
                }
            }
            
            func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
                controller.dismiss(animated: true) {
                    self.completion([])
                }
            }
            
            func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
                // Hier wird unser zentraler ErrorLogger genutzt
                ErrorLogger.shared.log(error: error, additionalInfo: "Document scanning failed in DocumentScannerView")
                controller.dismiss(animated: true) {
                    self.completion([])
                }
            }
        }
    }
}
