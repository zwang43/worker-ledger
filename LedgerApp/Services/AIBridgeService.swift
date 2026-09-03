import Foundation
import Darwin

struct BridgeHealth: Decodable {
    let ok: Bool
    let bridge: Bool?
    let online: Bool?
    let model: String?
    let active: String?
    let promptProfile: String?
    let think: Bool?
    let loaded: Bool?
    let models: [String]?
}

struct AIRecord: Decodable, Identifiable, Equatable {
    var id: String { UUID().uuidString }
    let action: String?
    let amount: Double?
    let category: String?
    let description: String?
    let date: String?
    let payment: String?
}

struct AIParseResponse: Decodable {
    let ok: Bool
    let records: [AIRecord]?
    let error: String?
}

@MainActor
final class AIBridgeService: ObservableObject {
    @Published private(set) var port: UInt16 = 0
    @Published private(set) var started = false
    @Published private(set) var health: BridgeHealth?
    @Published private(set) var lastError: String?
    @Published private(set) var isParsing = false

    private var process: Process?
    private var startTask: Task<Void, Never>?

    func start() {
        if started, process != nil {
            Task { [weak self] in await self?.refreshHealth() }
            return
        }
        guard startTask == nil else { return }
        startTask = Task { [weak self] in
            await self?.bootstrap()
            self?.startTask = nil
        }
    }

    func stop() {
        startTask?.cancel()
        startTask = nil
        process?.terminate()
        process = nil
        port = 0
        started = false
        health = nil
    }

    func refreshHealth() async {
        guard port > 0 else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: healthURL)
            health = try JSONDecoder().decode(BridgeHealth.self, from: data)
            lastError = nil
        } catch {
            health = nil
        }
    }

    func parse(text: String) async throws -> AIParseResponse {
        guard port > 0 else { throw BridgeError.notStarted }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError.emptyInput
        }
        isParsing = true
        defer { isParsing = false }
        var request = URLRequest(url: parseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        request.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AIParseResponse.self, from: data)
        lastError = response.ok ? nil : response.error
        return response
    }

    private var baseURL: URL { URL(string: "http://127.0.0.1:\(port)")! }
    private var healthURL: URL { baseURL.appendingPathComponent("health") }
    private var parseURL: URL { baseURL.appendingPathComponent("parse") }

    private func bootstrap() async {
        do {
            port = try findFreePort()
            try spawn(port: port)
            started = true
            for _ in 0..<60 {
                try await Task.sleep(nanoseconds: 500_000_000)
                await refreshHealth()
                if let health, health.ok == true, health.bridge == true { return }
            }
            lastError = "桥接服务未能在 30 秒内就绪"
        } catch {
            lastError = error.localizedDescription
            stop()
        }
    }

    private func spawn(port: UInt16) throws {
        let process = Process()
        let bin = Bundle.main.url(forResource: "ai_bridge", withExtension: "bin")
        if let bin,
           FileManager.default.isExecutableFile(atPath: bin.path) {
            process.executableURL = bin
        } else if let script = Bundle.main.url(forResource: "ai_bridge", withExtension: "py") {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", script.path]
        } else {
            throw BridgeError.missingScript
        }

        var env = ProcessInfo.processInfo.environment
        env["AI_BRIDGE_PORT"] = String(port)
        env["LEDGER_MODEL_REGISTRY"] = BackupService.appSupportURL
            .appendingPathComponent("model_registry.json").path
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        self.process = process
    }

    private func findFreePort() throws -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw BridgeError.socketFailed }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw BridgeError.socketFailed }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getResult = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        guard getResult == 0 else { throw BridgeError.socketFailed }
        return UInt16(bigEndian: addr.sin_port)
    }
}

enum BridgeError: LocalizedError {
    case notStarted
    case emptyInput
    case missingScript
    case socketFailed

    var errorDescription: String? {
        switch self {
        case .notStarted: return "本地 AI 桥接尚未启动"
        case .emptyInput: return "输入为空"
        case .missingScript: return "未找到桥接脚本 ai_bridge.py"
        case .socketFailed: return "无法分配本地端口"
        }
    }
}
