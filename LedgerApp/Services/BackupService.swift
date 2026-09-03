import Foundation

enum BackupService {
    static var appSupportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("cn.ledger.workerapp", isDirectory: true)
    }

    static var backupsURL: URL {
        appSupportURL.appendingPathComponent("backups", isDirectory: true)
    }

    static func saveBackup(data: Data) throws -> URL {
        try FileManager.default.createDirectory(at: backupsURL,
                                                withIntermediateDirectories: true)
        let stamp = DateSupport.isoString(Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let file = backupsURL.appendingPathComponent("ledger-state-\(stamp).json")
        try data.write(to: file, options: .atomic)
        try prune(keep: 3)
        return file
    }

    static func latestBackup() throws -> URL? {
        let files = try FileManager.default.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.lastPathComponent.hasPrefix("ledger-state-") && $0.pathExtension == "json" }
            .sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
        return files.first
    }

    static func legacyCandidateURLs() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        let project = desktop.appendingPathComponent("记账工作台融合档案_20260831", isDirectory: true)
        let dirs = [
            project.appendingPathComponent("账本数据/backups", isDirectory: true),
            project.appendingPathComponent("archive/legacy-2026-09-04/账本数据/backups", isDirectory: true)
        ]
        return dirs.flatMap { dir -> [URL] in
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
            return files.filter {
                $0.lastPathComponent.hasPrefix("ledger-state-") && $0.pathExtension == "json"
            }.sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
        }
    }

    private static func prune(keep: Int) throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: [.creationDateKey])
            .filter { $0.lastPathComponent.hasPrefix("ledger-state-") && $0.pathExtension == "json" }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        if files.count > keep {
            for file in files.prefix(files.count - keep) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

private extension URL {
    var modificationDate: Date? {
        (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
    var creationDate: Date? {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
}
