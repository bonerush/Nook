import CryptoKit
import Foundation

public struct PhrasePlanCacheKey: Hashable, Codable {
    public var model: String
    public var promptVersion: Int
    public var scriptHash: String
    public var wordsPerMinute: Int
    public var budgetWords: Int
    public var budgetCharacters: Int

    public init(
        model: String,
        promptVersion: Int,
        scriptHash: String,
        wordsPerMinute: Int,
        budgetWords: Int,
        budgetCharacters: Int
    ) {
        self.model = model
        self.promptVersion = promptVersion
        self.scriptHash = scriptHash
        self.wordsPerMinute = wordsPerMinute
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
            String(wordsPerMinute),
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
    private let fileManager: FileManager

    public init(
        directory: URL,
        maxEntries: Int = 48,
        fileManager: FileManager = .default
    ) throws {
        self.directory = directory
        self.maxEntries = max(1, maxEntries)
        self.fileManager = fileManager
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    public func load(for key: PhrasePlanCacheKey) -> PhrasePlan? {
        let url = directory.appendingPathComponent(key.fileStem + ".json")
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(PhrasePlanCacheEntry.self, from: data) else {
            return nil
        }
        return entry.plan
    }

    public func save(_ plan: PhrasePlan, for key: PhrasePlanCacheKey) {
        let entry = PhrasePlanCacheEntry(plan: plan, createdAt: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        let url = directory.appendingPathComponent(key.fileStem + ".json")
        try? data.write(to: url, options: [.atomic])
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
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = ((try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        )) ?? []).filter { $0.pathExtension == "json" }
        guard files.count > maxEntries else { return }
        let sorted = files.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            return left < right
        }
        for file in sorted.prefix(files.count - maxEntries) {
            try? fileManager.removeItem(at: file)
        }
    }
}
