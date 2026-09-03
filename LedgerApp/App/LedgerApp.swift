import SwiftUI
import SwiftData

@main
struct LedgerApp: App {
    let container: ModelContainer

    @StateObject private var bridge = AIBridgeService()
    @StateObject private var modelRegistry = ModelRegistryService()

    init() {
        do {
            try FileManager.default.createDirectory(
                at: BackupService.appSupportURL,
                withIntermediateDirectories: true)
            let config = ModelConfiguration(
                url: BackupService.appSupportURL.appendingPathComponent("LedgerData.store"))
            container = try ModelContainer(
                for: ExpenseRecord.self,
                MonthlySummaryRecord.self,
                LedgerProfile.self,
                FreedomPlan.self,
                LedgerSettings.self,
                MonthlyReportRecord.self,
                configurations: config
            )
        } catch {
            fatalError("无法创建 SwiftData 容器：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(bridge)
                .environmentObject(modelRegistry)
        }
        .defaultSize(width: 1180, height: 760)
    }
}
