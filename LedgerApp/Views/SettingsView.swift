import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var bridge: AIBridgeService
    @EnvironmentObject private var modelRegistry: ModelRegistryService
    @Query private var settingsList: [LedgerSettings]
    @Query private var expenses: [ExpenseRecord]
    @Query private var summaries: [MonthlySummaryRecord]
    @Query private var profiles: [LedgerProfile]
    @Query private var freedoms: [FreedomPlan]

    @State private var showImporter = false
    @State private var message: String?
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: Binding(
                    get: { settingsList.first?.themeRaw ?? "light" },
                    set: { newValue in
                        settingsList.first?.themeRaw = newValue
                        try? context.save()
                    })) {
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
            }
            Section("本地 AI 模型") {
                modelHealth
                modelRows
            }
            Section("数据") {
                Button("立即备份") { backupNow() }
                Button("导入 JSON") { showImporter = true }
                Button("导出 JSON") { exportJSON() }
                Button("清除示例数据") { showClearConfirm = true }
                Button("打开数据目录") {
                    NSWorkspace.shared.activateFileViewerSelecting([BackupService.appSupportURL])
                }
            }
            if let message {
                Section("提示") {
                    Text(message).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json]) { result in
            importJSON(result)
        }
        .confirmationDialog("确定清除示例数据？编辑过和新建的数据都会保留。",
                            isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("清除", role: .destructive) { clearSamples() }
        }
        .onAppear {
            Task { await bridge.refreshHealth() }
        }
    }

    private var modelHealth: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("桥接状态：\(bridge.health == nil ? "未就绪" : bridge.health!.ok ? "正常" : "异常")")
                Spacer()
                Button("刷新") {
                    Task { await bridge.refreshHealth() }
                }
                Button("启动") { bridge.start() }
            }
            if let health = bridge.health {
                Text("oMLX：\(health.online == true ? "在线" : "离线")")
                if let active = health.active {
                    Text("激活模型：\(active)（\(health.model ?? "")）")
                }
            }
        }
        .font(.callout)
    }

    private var modelRows: some View {
        ForEach(modelRegistry.registry.models) { model in
            HStack {
                VStack(alignment: .leading) {
                    Text(model.name)
                    Text("\(model.modelId) · \(model.promptProfile) · 思考\(model.think ? "开" : "关")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if modelRegistry.registry.active == model.id {
                    Text("使用中").foregroundStyle(.secondary)
                } else {
                    Button("切换") {
                        var value = modelRegistry.registry
                        value.active = model.id
                        modelRegistry.save(value)
                    }
                }
            }
        }
    }

    private func backupNow() {
        do {
            let data = LedgerDataService(context: context)
            let profile = try data.profile()
            let freedom = try data.freedom()
            let settings = try data.settings()
            let payload = try data.exportData(profile: profile,
                                              expenses: expenses,
                                              summaries: summaries,
                                              freedom: freedom,
                                              settings: settings)
            let url = try BackupService.saveBackup(data: payload)
            message = "已备份：\(url.lastPathComponent)"
        } catch {
            message = error.localizedDescription
        }
    }

    private func importJSON(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let state = try ImportValidator.decodeImportedState(data: data)
            try LedgerDataService(context: context).replaceAll(with: state)
            message = "导入成功：支出 \(state.expenses.count) 笔、总结 \(state.summaries.count) 条"
        } catch {
            message = "导入失败：\(error.localizedDescription)"
        }
    }

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.title = "导出账本"
        panel.nameFieldStringValue = "worker-ledger-export.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = LedgerDataService(context: context)
                let profile = try data.profile()
                let freedom = try data.freedom()
                let settings = try data.settings()
                let payload = try data.exportData(profile: profile,
                                                  expenses: expenses,
                                                  summaries: summaries,
                                                  freedom: freedom,
                                                  settings: settings)
                try payload.write(to: url, options: .atomic)
                message = "已导出到 \(url.lastPathComponent)"
            } catch {
                message = "导出失败：\(error.localizedDescription)"
            }
        }
    }

    private func clearSamples() {
        try? LedgerDataService(context: context).clearSamples()
        message = "示例数据已清除"
    }
}
