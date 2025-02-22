//
//  ReceiptDetailView.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 22.02.25.
//


import SwiftUI
import PDFKit

struct ReceiptDetailView: View {
    var receiptImage: UIImage?
    var pdfData: Data?
    
    var body: some View {
        Group {
            if let image = receiptImage {
                ScrollView([.vertical, .horizontal]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else if let pdfData = pdfData {
                PDFViewer(pdfData: pdfData)
            } else {
                Text("Kein Beleg vorhanden")
            }
        }
        .navigationBarTitle("Beleg", displayMode: .inline)
    }
}
