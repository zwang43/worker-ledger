import SwiftUI
import SwiftData
import AppKit

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard, hourly, expenses, monthly, freedom, insights, reports, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "首页"
        case .hourly: return "真实时薪"
        case .expenses: return "记账"
        case .monthly: return "月度总结"
        case .freedom: return "自由基金"
        case .insights: return "洞察"
        case .reports: return "月度报告"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "house"
        case .hourly: return "timer"
        case .expenses: return "plus.circle"
        case .monthly: return "calendar"
        case .freedom: return "safari"
        case .insights: return "lightbulb"
        case .reports: return "doc.text"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var bridge: AIBridgeService
    @Query private var settingsList: [LedgerSettings]
    @Query private var profileList: [LedgerProfile]
    @Query private var freedomList: [FreedomPlan]
    @State private var selection: AppSection? = .dashboard
    @State private var pendingMigration: ImportedState?
    @State private var migrationSummary: String?
    @State private var migrationChecked = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard: DashboardView()
            case .hourly: HourlyView()
            case .expenses: ExpensesView()
            case .monthly: MonthlyView()
            case .freedom: FreedomView()
            case .insights: InsightsView()
            case .reports: ReportsView()
            case .settings: SettingsView()
            }
        }
        .navigationTitle(selection?.title ?? "打工人小账本")
        .preferredColorScheme(settingsList.first?.theme == .dark ? .dark : .light)
        .task {
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                return
            }
            if !migrationChecked {
                await checkMigration()
            }
            ensureSingletons()
            bridge.start()
            observeTermination()
            await backupOnLaunch()
        }
        .alert("发现旧版数据", isPresented: Binding(
            get: { pendingMigration != nil },
            set: { if !$0 { pendingMigration = nil } })) {
            Button("导入") {
                if let state = pendingMigration {
                    importMigration(state)
                }
                pendingMigration = nil
            }
            Button("跳过", role: .cancel) {
                pendingMigration = nil
            }
        } message: {
            Text(migrationSummary ?? "")
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func ensureSingletons() {
        let data = LedgerDataService(context: context)
        _ = try? data.profile()
        _ = try? data.freedom()
        _ = try? data.settings()
        try? context.save()
    }

    private func checkMigration() async {
        migrationChecked = true
        let data = LedgerDataService(context: context)
        guard !data.hasAnyData() else { return }
        let candidates = BackupService.legacyCandidateURLs()
        guard let url = candidates.first,
              let fileData = try? Data(contentsOf: url),
              let state = try? ImportValidator.decodeImportedState(data: fileData) else { return }
        pendingMigration = state
        migrationSummary = """
        找到旧版备份：\(url.lastPathComponent)
        支出 \(state.expenses.count) 笔、月度总结 \(state.summaries.count) 条。
        是否导入？
        """
    }

    private func importMigration(_ state: ImportedState) {
        do {
            try LedgerDataService(context: context).replaceAll(with: state)
            try context.save()
            Task { await backupOnLaunch() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func backupOnLaunch() async {
        // 给视图/容器短暂稳定时间，随后在 Root 状态变化时由备份按钮/导出兜底。
        try? await Task.sleep(nanoseconds: 800_000_000)
        do {
            let data = LedgerDataService(context: context)
            let profile = try data.profile()
            let freedom = try data.freedom()
            let settings = try data.settings()
            let expenses = (try? context.fetch(FetchDescriptor<ExpenseRecord>())) ?? []
            let summaries = (try? context.fetch(FetchDescriptor<MonthlySummaryRecord>())) ?? []
            let payload = try data.exportData(profile: profile, expenses: expenses,
                                              summaries: summaries, freedom: freedom,
                                              settings: settings)
            _ = try BackupService.saveBackup(data: payload)
        } catch {
            // 首次无数据也允许静默失败，用户可从设置里手动备份。
        }
    }

    private func observeTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak bridge] _ in
            Task { @MainActor in
                bridge?.stop()
            }
        }
    }
}
