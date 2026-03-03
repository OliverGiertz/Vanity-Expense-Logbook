//
//  MailComposeView.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 19.02.25.
//


//
//  MailComposeView.swift
//  CamperLogBook
//
//  Erstellt am [Datum] von [Dein Name]
//  UIViewControllerRepresentable für MFMailComposeViewController
//

import SwiftUI
import MessageUI
import UIKit

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentation
    var recipients: [String]
    var subject: String
    var messageBody: String
    var attachmentData: Data?
    var attachmentMimeType: String
    var attachmentFileName: String
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposeView
        
        init(parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.parent.presentation.wrappedValue.dismiss()
            }
        }
        
        func presentFallbackAlert(on controller: UIViewController) {
            let alert = UIAlertController(
                title: "Mail nicht verfügbar",
                message: "Bitte richte einen Mail-Account ein oder verwende eine andere Freigabeart.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.parent.presentation.wrappedValue.dismiss()
            })
            controller.present(alert, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        if MFMailComposeViewController.canSendMail() {
            let mailVC = MFMailComposeViewController()
            mailVC.mailComposeDelegate = context.coordinator
            mailVC.setToRecipients(recipients)
            mailVC.setSubject(subject)
            mailVC.setMessageBody(messageBody, isHTML: false)
            if let data = attachmentData {
                mailVC.addAttachmentData(data, mimeType: attachmentMimeType, fileName: attachmentFileName)
            }
            return mailVC
        } else {
            let placeholder = UIViewController()
            DispatchQueue.main.async {
                context.coordinator.presentFallbackAlert(on: placeholder)
            }
            return placeholder
        }
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
