//
//  MailComposeView.swift
//  CamperLogBook
//
//  Erstellt am [Datum] von [Dein Name]
//  UIViewControllerRepresentable für MFMailComposeViewController
//

import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    typealias UIViewControllerType = MFMailComposeViewController
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
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(messageBody, isHTML: false)
        if let data = attachmentData {
            vc.addAttachmentData(data, mimeType: attachmentMimeType, fileName: attachmentFileName)
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
