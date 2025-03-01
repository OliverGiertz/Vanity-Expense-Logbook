//
//  FileManager+ZipExtensions.swift
//  CamperLogBook
//
//  Erstellt am 01.03.25 von Oliver Giertz
//
// Diese Extension verwendet nun die echte ZIP-Komprimierung über die ZipArchive-Klasse.
// Bei Fehlern wird das zentrale ErrorLogger-System verwendet.

import Foundation

extension FileManager {
    func zipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Überprüfe, ob das Quellverzeichnis existiert
        guard fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSLocalizedDescriptionKey: "Quelle nicht gefunden"])
        }
        
        // Sicherstellen, dass das Ziel nicht bereits existiert
        if fileExists(atPath: destinationURL.path) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: [NSLocalizedDescriptionKey: "Zieldatei existiert bereits"])
        }
        
        do {
            // Nutze ZipArchive, um ein echtes ZIP-Archiv zu erstellen.
            let success = try ZipArchive.createArchive(at: destinationURL.path, withContentsOfDirectory: sourceURL.path, progress: nil)
            if !success {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: [NSLocalizedDescriptionKey: "ZIP-Erstellung fehlgeschlagen"])
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Zippen von \(sourceURL.path) nach \(destinationURL.path)")
            throw error
        }
    }
    
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        // Überprüfe, ob die ZIP-Datei existiert
        guard fileExists(atPath: sourceURL.path) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [NSLocalizedDescriptionKey: "ZIP-Datei nicht gefunden"])
        }
        
        // Erstelle das Zielverzeichnis, falls nicht vorhanden
        if !fileExists(atPath: destinationURL.path) {
            try createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        do {
            let success = try ZipArchive.extractArchive(at: sourceURL.path, to: destinationURL.path, progress: nil)
            if !success {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: [NSLocalizedDescriptionKey: "ZIP-Entpackung fehlgeschlagen"])
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Entzippen von \(sourceURL.path) nach \(destinationURL.path)")
            throw error
        }
    }
}
