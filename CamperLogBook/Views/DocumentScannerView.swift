//
//  DocumentScannerView.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 16.02.25.
//  Aktualisiert: Kamera-Zugriffsabfrage eingebaut
//

import SwiftUI
import VisionKit
import AVFoundation

struct DocumentScannerView: UIViewControllerRepresentable {
    var completion: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authStatus == .denied || authStatus == .restricted {
            // Wenn der Zugriff verweigert wurde, rufe completion sofort mit einem leeren Array auf.
            DispatchQueue.main.async {
                self.completion([])
            }
            // Gib einen leeren VNDocumentCameraViewController zurück, der nicht benutzt wird.
            return VNDocumentCameraViewController()
        } else if authStatus == .notDetermined {
            // Falls der Status noch nicht bestimmt ist, fordere den Zugriff an.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        self.completion([])
                    }
                }
            }
        }
        
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = context.coordinator
        return scannerVC
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // Keine Aktualisierung erforderlich.
    }
    
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
            // Hier wird der zentrale ErrorLogger genutzt.
            ErrorLogger.shared.log(error: error, additionalInfo: "Document scanning failed in DocumentScannerView")
            controller.dismiss(animated: true) {
                self.completion([])
            }
        }
    }
}
