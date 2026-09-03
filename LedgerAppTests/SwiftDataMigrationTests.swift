import XCTest
import SwiftData
@testable import LedgerApp

@MainActor
final class SwiftDataMigrationTests: XCTestCase {
    func testReplaceAllWritesSwiftData() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ExpenseRecord.self,
            MonthlySummaryRecord.self,
            LedgerProfile.self,
            FreedomPlan.self,
            LedgerSettings.self,
            MonthlyReportRecord.self,
            configurations: config)
        let context = container.mainContext
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("archive/legacy-2026-09-04/账本数据/backups/ledger-state-2026-09-03T12-17-00.json")
        let data = try Data(contentsOf: url)
        let state = try ImportValidator.decodeImportedState(data: data)

        let service = LedgerDataService(context: context)
        try service.replaceAll(with: state)

        let expenses = try context.fetch(FetchDescriptor<ExpenseRecord>())
        let summaries = try context.fetch(FetchDescriptor<MonthlySummaryRecord>())
        XCTAssertEqual(expenses.count, state.expenses.count)
        XCTAssertEqual(summaries.count, state.summaries.count)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LedgerProfile>()).count, 1)
        XCTAssertEqual(Set(expenses.map(\.category)),
                       Set(state.expenses.map(\.category)))
        XCTAssertEqual(Set(expenses.map(\.dateKey)),
                       Set(state.expenses.map(\.date)))
    }
}
