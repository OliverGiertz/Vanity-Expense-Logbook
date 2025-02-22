//
//  PDFViewer.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 22.02.25.
//


import SwiftUI
import PDFKit

struct PDFViewer: UIViewRepresentable {
    let pdfData: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = UIColor.systemBackground
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if let document = PDFDocument(data: pdfData) {
            uiView.document = document
        }
    }
}
