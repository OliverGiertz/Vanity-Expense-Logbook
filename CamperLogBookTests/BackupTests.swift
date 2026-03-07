import Testing
import Foundation
@testable import CamperLogBook

@Suite("Backup")
struct BackupTests {

    // MARK: - BackupError descriptions

    @Test func backupError_notInitialized_hasDescription() {
        let error = BackupError.notInitialized
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func backupError_allCases_haveDescriptions() {
        let cases: [BackupError] = [
            .notInitialized, .directoryError, .backupNotFound,
            .invalidFormat, .incompatibleVersion, .missingCoreDataBackup, .noAsset
        ]
        for backupError in cases {
            #expect(backupError.errorDescription != nil, "Missing description for \(backupError)")
        }
    }

    // MARK: - ZipArchive.ArchiveManifest Codable round-trip

    @Test func archiveManifest_codableRoundtrip() throws {
        let original = ZipArchive.ArchiveManifest(
            version: "2.5.0",
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            fileCount: 42,
            compressionMethod: "lzfse"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ZipArchive.ArchiveManifest.self, from: data)

        #expect(decoded.version == original.version)
        #expect(decoded.fileCount == original.fileCount)
        #expect(decoded.compressionMethod == original.compressionMethod)
        #expect(abs(decoded.creationDate.timeIntervalSince(original.creationDate)) < 1.0)
    }

    @Test func archiveManifest_version_preserved() throws {
        let manifest = ZipArchive.ArchiveManifest(
            version: "3.1.2",
            creationDate: Date(),
            fileCount: 5,
            compressionMethod: "lzfse"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ZipArchive.ArchiveManifest.self, from: data)

        #expect(decoded.version == "3.1.2")
    }

    @Test func archiveManifest_extractManifest_returnsNilForEmptyData() throws {
        let result = try ZipArchive.extractManifest(from: Data())
        #expect(result == nil)
    }

    @Test func archiveManifest_extractManifest_returnsNilForNonArchiveData() throws {
        let junk = Data("this is not a zip archive".utf8)
        let result = try ZipArchive.extractManifest(from: junk)
        #expect(result == nil)
    }

    // MARK: - BackupInfo

    @Test func backupInfo_id_matchesConstructedValue() {
        let info = LocalBackupManager.BackupInfo(
            id: "backup_12345",
            date: Date(),
            version: "2.4.7",
            path: URL(fileURLWithPath: "/tmp/backup_12345.zip")
        )
        #expect(info.id == "backup_12345")
        #expect(info.version == "2.4.7")
    }
}
