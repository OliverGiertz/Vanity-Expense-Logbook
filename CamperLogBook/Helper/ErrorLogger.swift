//
//  ErrorLogger.swift
//  CamperLogBook
//
//  Erstellt am [Datum] von [Dein Name]
//  Zentraler Logger für Fehler, der Fehler mit Zeitstempel in eine .log-Datei im Dokumentenverzeichnis schreibt.
//

import Foundation

class ErrorLogger {
    static let shared = ErrorLogger()
    private let logFileName = "error.log"
    
    private var logFileURL: URL? {
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            return docs.appendingPathComponent(logFileName)
        }
        return nil
    }
    
    /// Loggt einen Fehler mit optionalen Zusatzinformationen.
    func log(error: Error, additionalInfo: String? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var logEntry = "[\(timestamp)] Error: \(error.localizedDescription)"
        if let info = additionalInfo {
            logEntry += " | Info: \(info)"
        }
        logEntry += "\n"
        append(logEntry: logEntry)
    }
    
    /// Loggt eine beliebige Nachricht.
    func log(message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        append(logEntry: logEntry)
    }
    
    private func append(logEntry: String) {
        guard let url = logFileURL else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let fileHandle = try? FileHandle(forWritingTo: url) {
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        } else {
            try? logEntry.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    /// Liefert die URL der Logdatei.
    func getLogFileURL() -> URL? {
        return logFileURL
    }
    
    /// Löscht den aktuellen Log.
    func clearLog() {
        guard let url = logFileURL else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }
}
