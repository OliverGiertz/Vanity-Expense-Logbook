import Foundation
import Compression

/// Eine Klasse zum Erstellen und Extrahieren von ZIP-Archiven mit der nativen Compression-Bibliothek von Apple
class ZipArchive {
    
    /// Die verschiedenen Fehlertypen, die während der Archivoperationen auftreten können
    enum ZipError: Error {
        case compressionFailed
        case decompressionFailed
        case fileNotFound
        case invalidData
        case fileSystemError(String)
        case directoryCreationFailed
        case fileWriteFailed
        case invalidArchiveFormat
        case invalidPath
    }
    
    // MARK: - Archiv erstellen
    
    /// Erstellt ein komprimiertes Archiv aus dem Inhalt eines Verzeichnisses
    /// - Parameters:
    ///   - archivePath: Der Pfad, an dem die ZIP-Datei erstellt werden soll
    ///   - directoryPath: Das Verzeichnis, dessen Inhalt komprimiert werden soll
    ///   - progress: Ein optionales Callback für Fortschrittsaktualisierungen (0.0 - 1.0)
    /// - Returns: `true` wenn erfolgreich, sonst `false`
    /// - Throws: `ZipError` wenn während der Archivierung Fehler auftreten
    @discardableResult
    static func createArchive(at archivePath: String, withContentsOfDirectory directoryPath: String, progress: ((Double) -> Void)? = nil) throws -> Bool {
        let directoryURL = URL(fileURLWithPath: directoryPath)
        let archiveURL = URL(fileURLWithPath: archivePath)
        
        // Überprüfen, ob das Quellverzeichnis existiert
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ZipError.fileNotFound
        }
        
        // Sicherstellen, dass das übergeordnete Verzeichnis existiert
        let parentDirectoryURL = archiveURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDirectoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true)
            } catch {
                throw ZipError.directoryCreationFailed
            }
        }
        
        // Sicherstellen, dass die Archiv-Datei existiert und leer ist
        if !FileManager.default.fileExists(atPath: archivePath) {
            FileManager.default.createFile(atPath: archivePath, contents: nil)
        } else {
            // Falls die Datei bereits existiert, lösche sie und erstelle eine neue leere Datei
            try FileManager.default.removeItem(atPath: archivePath)
            FileManager.default.createFile(atPath: archivePath, contents: nil)
        }
        
        // Erstellen eines temporären Manifests mit Metadaten zum Archiv
        let manifestData = try createManifest(for: directoryURL)
        
        // Alle Dateien im Verzeichnis auflisten
        let fileEnumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey])
        
        var filePaths: [URL] = []
        var totalBytes: Int64 = 0
        
        // Alle Dateien und deren Größe sammeln
        while let fileURL = fileEnumerator?.nextObject() as? URL {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? NSNumber {
                totalBytes += fileSize.int64Value
            }
            filePaths.append(fileURL)
        }
        
        // Archiv-Header erstellen und schreiben
        let archiveFile = try FileHandle(forWritingTo: archiveURL)
        defer { archiveFile.closeFile() }
        
        // Header mit Manifest schreiben
        let manifestHeader = createFileHeader(fileName: ".manifest.json", dataSize: UInt64(manifestData.count))
        try archiveFile.write(contentsOf: manifestHeader)
        try archiveFile.write(contentsOf: manifestData)
        
        // Fortschrittsverfolgung
        var bytesProcessed: Int64 = 0
        
        // Jede Datei komprimieren und zum Archiv hinzufügen
        for (index, fileURL) in filePaths.enumerated() {
            autoreleasepool {
                do {
                    let relativePath = fileURL.path.replacingOccurrences(of: directoryURL.path, with: "")
                    let fileData = try Data(contentsOf: fileURL)
                    let compressedData = try compressData(fileData)
                    
                    // Header mit Dateiinformationen schreiben
                    let header = createFileHeader(fileName: relativePath, dataSize: UInt64(compressedData.count))
                    try archiveFile.write(contentsOf: header)
                    try archiveFile.write(contentsOf: compressedData)
                    
                    // Fortschritt aktualisieren
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    if let fileSize = fileAttributes[.size] as? NSNumber {
                        bytesProcessed += fileSize.int64Value
                        let currentProgress = Double(bytesProcessed) / Double(totalBytes)
                        progress?(min(currentProgress, 0.99))
                    }
                } catch {
                    ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Komprimieren der Datei \(fileURL.lastPathComponent)")
                }
            }
            
            // Aktuellen Fortschritt anzeigen
            let currentProgress = Double(index + 1) / Double(filePaths.count)
            progress?(min(currentProgress, 0.99))
        }
        
        // Archiv-Footer schreiben
        let footer = createArchiveFooter()
        try archiveFile.write(contentsOf: footer)
        
        progress?(1.0)
        return true
    }
    
    /// Extrahiert ein komprimiertes Archiv an den angegebenen Pfad
    /// - Parameters:
    ///   - archivePath: Der Pfad zur ZIP-Datei
    ///   - destinationPath: Das Zielverzeichnis für die extrahierten Dateien
    ///   - progress: Ein optionales Callback für Fortschrittsaktualisierungen (0.0 - 1.0)
    /// - Returns: `true` wenn erfolgreich, sonst `false`
    /// - Throws: `ZipError` wenn während der Extraktion Fehler auftreten
    @discardableResult
    static func extractArchive(at archivePath: String, to destinationPath: String, progress: ((Double) -> Void)? = nil) throws -> Bool {
        let archiveURL = URL(fileURLWithPath: archivePath)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        
        // Überprüfen, ob die Archivdatei existiert
        guard FileManager.default.fileExists(atPath: archivePath) else {
            throw ZipError.fileNotFound
        }
        
        // Sicherstellen, dass das Zielverzeichnis existiert
        if !FileManager.default.fileExists(atPath: destinationPath) {
            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            } catch {
                throw ZipError.directoryCreationFailed
            }
        }
        
        // Archiv öffnen
        let archiveData = try Data(contentsOf: archiveURL)
        
        // Manifest zuerst extrahieren
        guard let manifest = try extractManifest(from: archiveData) else {
            throw ZipError.invalidArchiveFormat
        }
        
        // Dateien extrahieren
        let fileEntries = try extractFileEntries(from: archiveData)
        let totalEntries = fileEntries.count
        
        // Dateien entpacken
        for (index, entry) in fileEntries.enumerated() {
            autoreleasepool {
                do {
                    // Prüfen, ob es sich um das Manifest handelt (bereits extrahiert)
                    if entry.fileName.hasSuffix(".manifest.json") {
                        progress?(Double(index) / Double(totalEntries))
                        return
                    }
                    
                    // Pfad für die Datei erstellen
                    let fileDestination = destinationURL.appendingPathComponent(entry.fileName)
                    
                    // Sicherstellen, dass das übergeordnete Verzeichnis existiert
                    let directory = fileDestination.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: directory.path) {
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    }
                    
                    // Daten dekomprimieren und speichern
                    let compressedData = archiveData.subdata(in: entry.dataOffset..<(entry.dataOffset + Int(entry.dataSize)))
                    let decompressedData = try decompressData(compressedData)
                    try decompressedData.write(to: fileDestination)
                    
                    // Fortschritt aktualisieren
                    progress?(Double(index + 1) / Double(totalEntries))
                } catch {
                    ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Extrahieren der Datei \(entry.fileName)")
                }
            }
        }
        
        progress?(1.0)
        return true
    }
    
    /// Extrahiert selektiv bestimmte Dateien aus einem Archiv
    /// - Parameters:
    ///   - archivePath: Der Pfad zur ZIP-Datei
    ///   - destinationPath: Das Zielverzeichnis für die extrahierten Dateien
    ///   - fileFilter: Eine Funktion, die für jede Datei entscheidet, ob sie extrahiert werden soll
    ///   - progress: Ein optionales Callback für Fortschrittsaktualisierungen (0.0 - 1.0)
    /// - Returns: Die Liste der extrahierten Dateipfade
    /// - Throws: `ZipError` wenn während der Extraktion Fehler auftreten
    static func extractSelective(at archivePath: String, to destinationPath: String,
                                 fileFilter: (String) -> Bool,
                                 progress: ((Double) -> Void)? = nil) throws -> [String] {
        let archiveURL = URL(fileURLWithPath: archivePath)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        
        // Überprüfen, ob die Archivdatei existiert
        guard FileManager.default.fileExists(atPath: archivePath) else {
            throw ZipError.fileNotFound
        }
        
        // Sicherstellen, dass das Zielverzeichnis existiert
        if !FileManager.default.fileExists(atPath: destinationPath) {
            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            } catch {
                throw ZipError.directoryCreationFailed
            }
        }
        
        // Archiv öffnen
        let archiveData = try Data(contentsOf: archiveURL)
        
        // Dateien extrahieren
        let allFileEntries = try extractFileEntries(from: archiveData)
        
        // Filtern der Dateien entsprechend der Filterfunktion
        let filesToExtract = allFileEntries.filter { fileFilter($0.fileName) }
        let totalFilesToExtract = filesToExtract.count
        
        var extractedFiles: [String] = []
        
        // Dateien entpacken
        for (index, entry) in filesToExtract.enumerated() {
            autoreleasepool {
                do {
                    // Pfad für die Datei erstellen
                    let fileDestination = destinationURL.appendingPathComponent(entry.fileName)
                    
                    // Sicherstellen, dass das übergeordnete Verzeichnis existiert
                    let directory = fileDestination.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: directory.path) {
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    }
                    
                    // Daten dekomprimieren und speichern
                    let compressedData = archiveData.subdata(in: entry.dataOffset..<(entry.dataOffset + Int(entry.dataSize)))
                    let decompressedData = try decompressData(compressedData)
                    try decompressedData.write(to: fileDestination)
                    
                    extractedFiles.append(entry.fileName)
                    
                    // Fortschritt aktualisieren
                    progress?(Double(index + 1) / Double(totalFilesToExtract))
                } catch {
                    ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim selektiven Extrahieren der Datei \(entry.fileName)")
                }
            }
        }
        
        progress?(1.0)
        return extractedFiles
    }
    
    /// Listet alle Dateien in einem Archiv auf
    /// - Parameter archivePath: Der Pfad zur ZIP-Datei
    /// - Returns: Eine Liste der Dateinamen im Archiv
    /// - Throws: `ZipError` wenn während des Lesens Fehler auftreten
    static func listContents(of archivePath: String) throws -> [String] {
        let archiveURL = URL(fileURLWithPath: archivePath)
        
        // Überprüfen, ob die Archivdatei existiert
        guard FileManager.default.fileExists(atPath: archivePath) else {
            throw ZipError.fileNotFound
        }
        
        // Archiv öffnen
        let archiveData = try Data(contentsOf: archiveURL)
        
        // Dateien auflisten
        let fileEntries = try extractFileEntries(from: archiveData)
        return fileEntries.map { $0.fileName }
    }
    
    // MARK: - Hilfsmethoden
    
    private struct FileEntry {
        let fileName: String
        let dataOffset: Int
        let dataSize: UInt64
    }
    
    private struct ArchiveManifest: Codable {
        let version: String
        let creationDate: Date
        let fileCount: Int
        let compressionMethod: String
    }
    
    private static func createManifest(for directoryURL: URL) throws -> Data {
        let fileEnumerator = FileManager.default.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey])
        var fileCount = 0
        
        while fileEnumerator?.nextObject() as? URL != nil {
            fileCount += 1
        }
        
        let manifest = ArchiveManifest(
            version: "1.0",
            creationDate: Date(),
            fileCount: fileCount,
            compressionMethod: "lzfse"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(manifest)
    }
    
    private static func extractManifest(from archiveData: Data) throws -> ArchiveManifest? {
        guard let firstEntry = try extractFileEntries(from: archiveData).first,
              firstEntry.fileName.hasSuffix(".manifest.json") else {
            return nil
        }
        
        let manifestData = archiveData.subdata(in: firstEntry.dataOffset..<(firstEntry.dataOffset + Int(firstEntry.dataSize)))
        let decompressedData = try decompressData(manifestData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArchiveManifest.self, from: decompressedData)
    }
    
    private static func createFileHeader(fileName: String, dataSize: UInt64) -> Data {
        var header = Data()
        
        // Dateinamenslänge (4 Bytes)
        let nameLength = UInt32(fileName.utf8.count)
        var nameBytes = withUnsafeBytes(of: nameLength) { Data($0) }
        header.append(nameBytes)
        
        // Dateiname (variabel)
        if let nameData = fileName.data(using: .utf8) {
            header.append(nameData)
        }
        
        // Datengröße (8 Bytes)
        nameBytes = withUnsafeBytes(of: dataSize) { Data($0) }
        header.append(nameBytes)
        
        return header
    }
    
    private static func createArchiveFooter() -> Data {
        // Ein einfacher Footer zur Identifikation des Archivformats
        return "VANITY_ARCHIVE_END".data(using: .utf8) ?? Data()
    }
    
    private static func extractFileEntries(from archiveData: Data) throws -> [FileEntry] {
        var entries: [FileEntry] = []
        var offset = 0
        
        while offset < archiveData.count {
            // Dateinamenslänge lesen (4 Bytes)
            guard offset + 4 <= archiveData.count else { break }
            let nameLength = archiveData.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += 4
            
            // Dateiname lesen
            guard offset + Int(nameLength) <= archiveData.count else { break }
            let nameData = archiveData.subdata(in: offset..<offset+Int(nameLength))
            guard let fileName = String(data: nameData, encoding: .utf8) else { break }
            offset += Int(nameLength)
            
            // Datengröße lesen (8 Bytes)
            guard offset + 8 <= archiveData.count else { break }
            let dataSize = archiveData.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: UInt64.self) }
            offset += 8
            
            // Dateieintrag speichern
            let entry = FileEntry(fileName: fileName, dataOffset: offset, dataSize: dataSize)
            entries.append(entry)
            
            // Zum nächsten Eintrag springen
            offset += Int(dataSize)
        }
        
        return entries
    }
    
    // MARK: - Komprimierung/Dekomprimierung
    
    private static func compressData(_ data: Data) throws -> Data {
        let sourceSize = data.count
        let destinationSize = sourceSize + 1024  // Buffer für Komprimierung
        
        // Ausgabebuffer erstellen
        var compressedData = Data(count: destinationSize)
        
        let result = compressedData.withUnsafeMutableBytes { destPtr in
            data.withUnsafeBytes { srcPtr in
                compression_encode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destinationSize,
                    srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }
        
        guard result > 0 else {
            throw ZipError.compressionFailed
        }
        
        // Auf die tatsächliche Größe zuschneiden
        compressedData.count = result
        return compressedData
    }
    
    private static func decompressData(_ data: Data) throws -> Data {
        // Wir schätzen, dass die dekomprimierte Datei etwa 5x größer ist
        let estimatedSize = data.count * 5
        var decompressedData = Data(count: estimatedSize)
        
        let result = decompressedData.withUnsafeMutableBytes { destPtr in
            data.withUnsafeBytes { srcPtr in
                compression_decode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    estimatedSize,
                    srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }
        
        guard result > 0 else {
            throw ZipError.decompressionFailed
        }
        
        // Auf die tatsächliche Größe zuschneiden
        decompressedData.count = result
        return decompressedData
    }
}
