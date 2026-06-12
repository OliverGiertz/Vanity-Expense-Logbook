import Testing
import Foundation
@testable import CamperLogBook

@Suite("BackupIntegration")
struct BackupIntegrationTests {

    // MARK: - ZipArchive create + extract cycle

    @Test func test_createAndExtractArchive_filesPreserved() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let srcDir = tmpDir.appendingPathComponent("source")
        let dstDir = tmpDir.appendingPathComponent("destination")
        let archivePath = tmpDir.appendingPathComponent("backup.zip").path

        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let content = "Hello, Backup!".data(using: .utf8)!
        try content.write(to: srcDir.appendingPathComponent("test.txt"))

        let created = try ZipArchive.createArchive(at: archivePath, withContentsOfDirectory: srcDir.path)
        #expect(created == true)

        let extracted = try ZipArchive.extractArchive(at: archivePath, to: dstDir.path)
        #expect(extracted == true)

        let restoredPath = dstDir.appendingPathComponent("test.txt")
        #expect(FileManager.default.fileExists(atPath: restoredPath.path))
        let restoredContent = try Data(contentsOf: restoredPath)
        #expect(restoredContent == content)
    }

    @Test func test_createArchive_manifestIsEmbedded() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let srcDir = tmpDir.appendingPathComponent("source")
        let archivePath = tmpDir.appendingPathComponent("backup.zip").path
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try "data".data(using: .utf8)!.write(to: srcDir.appendingPathComponent("entry.json"))

        _ = try ZipArchive.createArchive(at: archivePath, withContentsOfDirectory: srcDir.path)
        let archiveData = try Data(contentsOf: URL(fileURLWithPath: archivePath))
        let manifest = try ZipArchive.extractManifest(from: archiveData)
        #expect(manifest != nil)
        #expect(manifest?.compressionMethod == "lzfse")
    }

    @Test func test_listContents_includesAllSourceFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let srcDir = tmpDir.appendingPathComponent("source")
        let archivePath = tmpDir.appendingPathComponent("backup.zip").path
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try "a".data(using: .utf8)!.write(to: srcDir.appendingPathComponent("fileA.txt"))
        try "b".data(using: .utf8)!.write(to: srcDir.appendingPathComponent("fileB.txt"))

        _ = try ZipArchive.createArchive(at: archivePath, withContentsOfDirectory: srcDir.path)
        let contents = try ZipArchive.listContents(of: archivePath)

        let fileNames = Set(contents.map { URL(fileURLWithPath: $0).lastPathComponent })
        #expect(fileNames.contains("fileA.txt"))
        #expect(fileNames.contains("fileB.txt"))
    }

    @Test func test_extractManifest_fromCorruptData_returnsNil() throws {
        let corrupt = Data("this is not a valid archive".utf8)
        let manifest = try ZipArchive.extractManifest(from: corrupt)
        #expect(manifest == nil)
    }

    @Test func test_backupInfo_idAndVersionPreserved() {
        let info = LocalBackupManager.BackupInfo(
            id: "backup_test_42",
            date: Date(),
            version: "3.0.1",
            path: URL(fileURLWithPath: "/tmp/backup_test_42.zip")
        )
        #expect(info.id == "backup_test_42")
        #expect(info.version == "3.0.1")
    }
}
