import CryptoKit
import Foundation

public struct ImageCache: Sendable {
    public let rootDirectory: URL
    public let maxDiskBytes: Int64
    public let maxFileAge: TimeInterval

    public init(
        rootDirectory: URL? = nil,
        maxDiskBytes: Int64 = 50 * 1024 * 1024,
        maxFileAge: TimeInterval = 30 * 24 * 60 * 60
    ) {
        self.maxDiskBytes = maxDiskBytes
        self.maxFileAge = maxFileAge

        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first
                ?? FileManager.default.temporaryDirectory
            self.rootDirectory = supportDirectory
                .appendingPathComponent("Plain", isDirectory: true)
                .appendingPathComponent("images", isDirectory: true)
        }
    }

    public func localURL(for sourceURL: URL, mimeType: String? = nil) -> URL {
        rootDirectory
            .appendingPathComponent(cacheKey(for: sourceURL), isDirectory: false)
            .appendingPathExtension(fileExtension(for: sourceURL, mimeType: mimeType))
    }

    public func existingLocalURL(for sourceURL: URL, mimeType: String? = nil) -> URL? {
        let localURL = localURL(for: sourceURL, mimeType: mimeType)
        return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
    }

    public func store(data: Data, sourceURL: URL, mimeType: String?) throws -> URL {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let localURL = localURL(for: sourceURL, mimeType: mimeType)
        try data.write(to: localURL, options: [.atomic])
        try prune()
        return localURL
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else {
            return
        }
        try FileManager.default.removeItem(at: rootDirectory)
    }

    public func currentSizeInBytes() throws -> Int64 {
        try cachedFiles().reduce(0) { $0 + $1.size }
    }

    public func prune(now: Date = Date()) throws {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else {
            return
        }

        let cutoff = now.addingTimeInterval(-maxFileAge)
        var files = try cachedFiles()

        for file in files where file.modifiedAt < cutoff {
            try? FileManager.default.removeItem(at: file.url)
        }

        files = try cachedFiles().sorted {
            if $0.modifiedAt == $1.modifiedAt {
                return $0.url.lastPathComponent < $1.url.lastPathComponent
            }
            return $0.modifiedAt < $1.modifiedAt
        }

        var totalSize = files.reduce(0) { $0 + $1.size }
        guard totalSize > maxDiskBytes else {
            return
        }

        for file in files {
            try? FileManager.default.removeItem(at: file.url)
            totalSize -= file.size
            if totalSize <= maxDiskBytes {
                break
            }
        }
    }

    private func cacheKey(for sourceURL: URL) -> String {
        let data = Data(sourceURL.absoluteString.utf8)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func fileExtension(for sourceURL: URL, mimeType: String?) -> String {
        if let mimeType {
            switch mimeType.lowercased().split(separator: ";").first?.trimmingCharacters(in: .whitespaces) {
            case "image/jpeg", "image/jpg":
                return "jpg"
            case "image/png":
                return "png"
            case "image/gif":
                return "gif"
            case "image/webp":
                return "webp"
            case "image/avif":
                return "avif"
            case "image/svg+xml":
                return "svg"
            default:
                break
            }
        }

        let pathExtension = sourceURL.pathExtension
        return pathExtension.isEmpty ? "img" : pathExtension
    }

    private func cachedFiles() throws -> [CachedFile] {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else {
            return []
        }

        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey,
            .creationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ]

        return try FileManager.default
            .contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
            .compactMap { url in
                let values = try url.resourceValues(forKeys: keys)
                guard values.isRegularFile == true else {
                    return nil
                }

                return CachedFile(
                    url: url,
                    size: Int64(values.fileSize ?? 0),
                    modifiedAt: values.contentModificationDate ?? values.creationDate ?? .distantPast
                )
            }
    }
}

private struct CachedFile {
    var url: URL
    var size: Int64
    var modifiedAt: Date
}
