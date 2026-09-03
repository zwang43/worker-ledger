import Foundation

struct ModelEntry: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var endpoint: String
    var modelId: String
    var think: Bool
    var promptProfile: String
}

struct ModelRegistry: Codable, Equatable {
    var version: Int
    var active: String
    var models: [ModelEntry]

    static let empty = ModelRegistry(version: 1, active: "", models: [])
}

@MainActor
final class ModelRegistryService: ObservableObject {
    @Published private(set) var registry: ModelRegistry = .empty
    @Published private(set) var errorText: String?

    private let fileURL: URL
    private let bundledURL: URL?

    init() {
        fileURL = BackupService.appSupportURL.appendingPathComponent("model_registry.json")
        bundledURL = Bundle.main.url(forResource: "default_model_registry", withExtension: "json")
        reload()
    }

    func reload() {
        if let data = try? Data(contentsOf: fileURL),
           let value = try? JSONDecoder().decode(ModelRegistry.self, from: data) {
            registry = value
            errorText = nil
            return
        }
        if let bundledURL,
           let data = try? Data(contentsOf: bundledURL),
           let value = try? JSONDecoder().decode(ModelRegistry.self, from: data) {
            registry = value
            try? saveRegistry(value)
        }
    }

    @discardableResult
    func save(_ value: ModelRegistry) -> Bool {
        do {
            try saveRegistry(value)
            registry = value
            errorText = nil
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func saveRegistry(_ value: ModelRegistry) throws {
        try FileManager.default.createDirectory(at: BackupService.appSupportURL,
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        let temp = fileURL.appendingPathExtension("tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: fileURL)
        }
    }
}
