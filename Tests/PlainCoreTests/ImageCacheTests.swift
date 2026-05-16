import PlainCore
import XCTest

final class ImageCacheTests: XCTestCase {
    func testDefaultCachePolicyIsSmallAndTemporary() {
        let cache = ImageCache()

        XCTAssertEqual(cache.maxDiskBytes, 50 * 1024 * 1024)
        XCTAssertEqual(cache.maxFileAge, 30 * 24 * 60 * 60)
    }

    func testPruneRemovesFilesOlderThanMaxAge() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = ImageCache(rootDirectory: directory, maxDiskBytes: 1_000, maxFileAge: 30 * 24 * 60 * 60)
        let now = Date()
        let staleFile = directory.appendingPathComponent("stale.png")
        let freshFile = directory.appendingPathComponent("fresh.png")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 20).write(to: staleFile)
        try Data(repeating: 2, count: 20).write(to: freshFile)
        try setModificationDate(now.addingTimeInterval(-31 * 24 * 60 * 60), for: staleFile)
        try setModificationDate(now.addingTimeInterval(-1 * 24 * 60 * 60), for: freshFile)

        try cache.prune(now: now)

        XCTAssertFalse(FileManager.default.fileExists(atPath: staleFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshFile.path))
    }

    func testStorePrunesOldestFilesWhenCacheExceedsLimit() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = ImageCache(rootDirectory: directory, maxDiskBytes: 90, maxFileAge: 30 * 24 * 60 * 60)
        let oldFile = directory.appendingPathComponent("old.png")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 70).write(to: oldFile)
        try setModificationDate(Date().addingTimeInterval(-60), for: oldFile)

        let newFile = try cache.store(
            data: Data(repeating: 2, count: 40),
            sourceURL: URL(string: "https://example.com/new.png")!,
            mimeType: "image/png"
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFile.path))
        XCTAssertLessThanOrEqual(try cache.currentSizeInBytes(), 90)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
