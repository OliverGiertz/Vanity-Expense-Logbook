import Foundation
import UIKit

/// Eine einfache Klasse für das Packen und Entpacken von ZIP-Archiven
class SSZipArchive {
    
    /// Erstellt ein ZIP-Archiv aus dem Inhalt eines Verzeichnisses
    /// - Parameters:
    ///   - path: Der Pfad an dem die ZIP-Datei erstellt werden soll
    ///   - directoryPath: Das Verzeichnis, dessen Inhalt gepackt werden soll
    /// - Returns: true, wenn erfolgreich, sonst false
    static func createZipFile(atPath path: String, withContentsOfDirectory directoryPath: String) -> Bool {
        ErrorLogger.shared.log(message: "SSZipArchive: Erstelle ZIP-Datei an \(path) mit Inhalt von \(directoryPath)")
        
        let fileManager = FileManager.default
        
        // Temporäres Verzeichnis für die Verarbeitung
        let tempZipDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        
        do {
            // Stelle sicher, dass das Zielverzeichnis existiert
            let parentDir = (path as NSString).deletingLastPathComponent
            if !fileManager.fileExists(atPath: parentDir) {
                try fileManager.createDirectory(atPath: parentDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Erstelle das temporäre Verzeichnis
            try fileManager.createDirectory(atPath: tempZipDir, withIntermediateDirectories: true, attributes: nil)
            
            // Kopiere alle Dateien aus dem Quellverzeichnis in das temporäre Verzeichnis
            let sourceContents = try fileManager.contentsOfDirectory(atPath: directoryPath)
            
            for item in sourceContents {
                let sourceItemPath = (directoryPath as NSString).appendingPathComponent(item)
                let destItemPath = (tempZipDir as NSString).appendingPathComponent(item)
                
                // Prüfe, ob es ein Verzeichnis ist
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: sourceItemPath, isDirectory: &isDir) {
                    if isDir.boolValue {
                        // Wenn es ein Verzeichnis ist, erstelle es und kopiere rekursiv den Inhalt
                        try fileManager.createDirectory(atPath: destItemPath, withIntermediateDirectories: true, attributes: nil)
                        
                        // Rekursiv kopieren
                        let subItems = try fileManager.contentsOfDirectory(atPath: sourceItemPath)
                        for subItem in subItems {
                            let sourceSubPath = (sourceItemPath as NSString).appendingPathComponent(subItem)
                            let destSubPath = (destItemPath as NSString).appendingPathComponent(subItem)
                            try fileManager.copyItem(atPath: sourceSubPath, toPath: destSubPath)
                        }
                    } else {
                        // Wenn es eine normale Datei ist, einfach kopieren
                        try fileManager.copyItem(atPath: sourceItemPath, toPath: destItemPath)
                    }
                } else {
                    // Wenn der Pfad nicht existiert, überspringen
                    continue
                }
            }
            
            // Erstelle eine einfache Metadaten-Datei im temporären Verzeichnis
            let metadataPath = (tempZipDir as NSString).appendingPathComponent("__zip_metadata.txt")
            let metadata = """
            Backup erstellt: \(Date())
            Quellverzeichnis: \(directoryPath)
            Dateien: \(sourceContents.count)
            """
            try metadata.write(toFile: metadataPath, atomically: true, encoding: .utf8)
            
            // Jetzt erstellen wir eine Datei mit dem Inhalt des tempZipDir
            let zipData = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
            try zipData.write(to: URL(fileURLWithPath: path))
            
            // Jetzt kopieren wir alle Dateien direkt in das Zielverzeichnis
            // Da wir die ZIP-Erstellung simulieren, kopieren wir die Dateien direkt
            // Im echten Einsatz würde hier die ZIP-Komprimierung stattfinden
            
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            let tempContents = try fileManager.contentsOfDirectory(atPath: tempZipDir)
            for item in tempContents {
                let sourcePath = (tempZipDir as NSString).appendingPathComponent(item)
                let destPath = (path as NSString).appendingPathComponent(item)
                
                // Falls das Ziel bereits existiert, löschen
                if fileManager.fileExists(atPath: destPath) {
                    try fileManager.removeItem(atPath: destPath)
                }
                
                try fileManager.copyItem(atPath: sourcePath, toPath: destPath)
            }
            
            // Temporäres Verzeichnis aufräumen
            try fileManager.removeItem(atPath: tempZipDir)
            
            return true
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "SSZipArchive - Fehler beim Erstellen des ZIP-Archivs")
            return false
        }
    }
    
    /// Entpackt ein ZIP-Archiv an den angegebenen Ort
    /// - Parameters:
    ///   - path: Der Pfad zur ZIP-Datei
    ///   - destination: Das Zielverzeichnis
    /// - Returns: true, wenn erfolgreich, sonst false
    static func unzipFile(atPath path: String, toDestination destination: String) -> Bool {
        ErrorLogger.shared.log(message: "SSZipArchive: Entpacke Archiv von \(path) nach \(destination)")
        
        let fileManager = FileManager.default
        
        // Stelle sicher, dass das Zielverzeichnis existiert
        if !fileManager.fileExists(atPath: destination) {
            do {
                try fileManager.createDirectory(atPath: destination, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "SSZipArchive - Fehler beim Erstellen des Zielverzeichnisses")
                return false
            }
        }
        
        do {
            // Kopiere alle Dateien aus dem "ZIP"-Archiv in das Zielverzeichnis
            // Da wir keine echte ZIP-Komprimierung haben, ist das in unserem Fall ein Verzeichnis
            
            // Prüfe, ob es ein Verzeichnis oder eine Datei ist
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
                if isDir.boolValue {
                    // Es ist ein Verzeichnis, kopiere seinen Inhalt
                    let contents = try fileManager.contentsOfDirectory(atPath: path)
                    for item in contents {
                        let sourcePath = (path as NSString).appendingPathComponent(item)
                        let destPath = (destination as NSString).appendingPathComponent(item)
                        
                        if fileManager.fileExists(atPath: destPath) {
                            try fileManager.removeItem(atPath: destPath)
                        }
                        
                        try fileManager.copyItem(atPath: sourcePath, toPath: destPath)
                    }
                } else {
                    // Es ist eine Datei, versuche sie zu extrahieren
                    // Da wir keine echte ZIP-Komprimierung haben, kopieren wir einfach die Metadaten-Datei
                    let destPath = (destination as NSString).appendingPathComponent("__extracted_zip_metadata.txt")
                    try fileManager.copyItem(atPath: path, toPath: destPath)
                }
                
                return true
            } else {
                ErrorLogger.shared.log(message: "SSZipArchive - Archiv nicht gefunden: \(path)")
                return false
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "SSZipArchive - Fehler beim Entpacken des Archivs")
            return false
        }
    }
}
