import Foundation

class ErrorLogger {
    static let shared = ErrorLogger()
    private let logFileName = "error.log"

    // Serial queue protects all file I/O from concurrent writes.
    private let queue = DispatchQueue(label: "de.vanityontour.camperlogbook.errorlogger", qos: .utility)
    private static let timestampFormatter: ISO8601DateFormatter = ISO8601DateFormatter()

    private var logFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(logFileName)
    }

    func log(error: Error, additionalInfo: String? = nil) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        var entry = "[\(timestamp)] Error: \(error.localizedDescription)"
        if let info = additionalInfo { entry += " | Info: \(info)" }
        entry += "\n"
        append(logEntry: entry)
    }

    func log(message: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        append(logEntry: "[\(timestamp)] \(message)\n")
    }

    private func append(logEntry: String) {
        queue.async { [weak self] in
            guard let self, let url = self.logFileURL else { return }
            guard let data = logEntry.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? logEntry.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func getLogFileURL() -> URL? { logFileURL }

    func clearLog() {
        queue.async { [weak self] in
            guard let self, let url = self.logFileURL else { return }
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
