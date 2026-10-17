import CryptoKit
import Foundation

public struct PhrasePlanCacheKey: Hashable, Codable {
    public var model: String
    public var promptVersion: Int
    public var scriptHash: String
    public var tokenizerVersion: Int
    public var budgetWords: Int
    public var budgetCharacters: Int

    public init(
        model: String,
        promptVersion: Int,
        scriptHash: String,
        tokenizerVersion: Int,
        budgetWords: Int,
        budgetCharacters: Int
    ) {
        self.model = model
        self.promptVersion = promptVersion
        self.scriptHash = scriptHash
        self.tokenizerVersion = tokenizerVersion
        self.budgetWords = budgetWords
        self.budgetCharacters = budgetCharacters
    }

    public static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public var fileStem: String {
        let raw = [
            model,
            String(promptVersion),
            scriptHash,
            String(tokenizerVersion),
            String(budgetWords),
            String(budgetCharacters)
        ].joined(separator: "|")
        return Self.hash(raw)
    }
}

private struct PhrasePlanCacheEntry: Codable {
    var plan: PhrasePlan
    var createdAt: Date
}

public final class PhrasePlanCache {
    private let directory: URL
    private let maxEntries: Int
    private let maxBytes: Int
    private let fileManager: FileManager

    public init(
        directory: URL,
        maxEntries: Int = 20,
        maxBytes: Int = 2_000_000,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.maxEntries = max(1, maxEntries)
        self.maxBytes = max(64_000, maxBytes)
        self.fileManager = fileManager
        // The cache is best-effort. A read-only or missing Application
        // Support directory must never block app launch or planning.
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
        trim()
    }

    public func load(for key: PhrasePlanCacheKey) -> PhrasePlan? {
        let url = directory.appendingPathComponent(key.fileStem + ".json")
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(PhrasePlanCacheEntry.self, from: data) else {
            return nil
        }
        // Touch on hit so the size trim behaves as an LRU.
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
        return entry.plan
    }

    public func save(_ plan: PhrasePlan, for key: PhrasePlanCacheKey) {
        let entry = PhrasePlanCacheEntry(plan: plan, createdAt: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        let url = directory.appendingPathComponent(key.fileStem + ".json")
        try? data.write(to: url, options: [.atomic])
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
        trim()
    }

    public func clear() {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for file in files where file.pathExtension == "json" {
            try? fileManager.removeItem(at: file)
        }
    }

    private func trim() {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let files = ((try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        )) ?? []).filter { $0.pathExtension == "json" }
        var entries: [(url: URL, size: Int, date: Date)] = files.map { file in
            let values = try? file.resourceValues(forKeys: Set(keys))
            return (
                file,
                values?.fileSize ?? 0,
                values?.contentModificationDate ?? .distantPast
            )
        }
        var totalBytes = entries.reduce(0) { $0 + $1.size }
        entries.sort { $0.date < $1.date }
        while (entries.count > maxEntries || totalBytes > maxBytes), !entries.isEmpty {
            let oldest = entries.removeFirst()
            try? fileManager.removeItem(at: oldest.url)
            totalBytes -= oldest.size
        }
    }
}
