//
//  ReceiptSource.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 17.02.25.
//


import SwiftUI

// Enum zur Identifikation der Belegquelle
enum ReceiptSource: Identifiable, Equatable {
    case photo
    case pdf
    case scanner
    
    var id: Int {
        switch self {
        case .photo: return 1
        case .pdf: return 2
        case .scanner: return 3
        }
    }
}

/// Diese View kapselt die Logik für die Auswahl eines Belegs.
/// Wird über ein Binding gesteuert und gibt das ausgewählte Bild (oder PDF-Daten) zurück.
struct ReceiptPickerSheet: View {
    @Binding var source: ReceiptSource?
    @Binding var receiptImage: UIImage?
    @Binding var pdfData: Data?
    
    var body: some View {
        Group {
            if let source = source {
                switch source {
                case .photo:
                    PhotoPickerView { image in
                        if let img = image {
                            receiptImage = img
                            pdfData = nil
                        }
                        self.source = nil
                    }
                case .pdf:
                    PDFDocumentPicker { url in
                        if let url = url, let data = try? Data(contentsOf: url) {
                            pdfData = data
                            receiptImage = nil
                        }
                        self.source = nil
                    }
                case .scanner:
                    DocumentScannerView { images in
                        if !images.isEmpty, let pdf = PDFCreator.createPDF(from: images) {
                            pdfData = pdf
                            receiptImage = nil
                        }
                        self.source = nil
                    }
                }
            }
        }
    }
}
