//
//  PDFCreator.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 16.02.25.
//


import UIKit
import PDFKit

struct PDFCreator {
    static func createPDF(from images: [UIImage]) -> Data? {
        let pdfDocument = PDFDocument()
        for (index, image) in images.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        return pdfDocument.dataRepresentation()
    }
}
