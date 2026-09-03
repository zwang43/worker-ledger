import XCTest
@testable import LedgerApp

final class ImportValidatorTests: XCTestCase {
    private func sampleState(expenses: [ExpenseDTO] = [],
                             summaries: [MonthlySummaryDTO] = []) -> LedgerStateDTO {
        LedgerStateDTO(
            profile: ProfileDTO(monthlySalary: 13800, payMonths: 13,
                                monthlyWorkCost: 850, dailyOfficeHours: 9,
                                oneWayCommuteMinutes: 48, weeklyOvertimeHours: 6,
                                isSample: true),
            expenses: expenses,
            monthlySummaries: summaries,
            freedom: FreedomDTO(targetAmount: 120000, targetDate: "2027-03",
                                reason: "目标", currentSaved: 36800,
                                basicMonthlyCost: 5600, startMonth: "2026-03",
                                isSample: true),
            settings: SettingsDTO(theme: "light", sampleState: "active"))
    }

    func testDecodeWrappedPayload() throws {
        let payload = ImportPayloadDTO(appId: "worker-ledger", version: 1,
                                       state: sampleState())
        let data = try JSONEncoder().encode(payload)
        let result = try ImportValidator.decodeImportedState(data: data)
        XCTAssertEqual(result.profile.monthlySalary, 13800)
        XCTAssertEqual(result.settings.theme, "light")
    }

    func testRejectsWrongAppId() {
        var payload = ImportPayloadDTO(appId: "worker-ledger", version: 1,
                                       state: sampleState())
        payload.appId = "other"
        let data = try! JSONEncoder().encode(payload)
        XCTAssertThrowsError(try ImportValidator.decodeImportedState(data: data))
    }

    func testCleansUnknownCategoryAndRejectsDuplicates() throws {
        let expense = ExpenseDTO(id: "a", _dbId: nil, date: "2026-08-01", amount: 10,
                                 category: "未知分类", note: "", createdAt: "2026-08-01T00:00:00Z",
                                 isSample: false)
        let cleaned = try ImportValidator.decodeImportedState(
            data: JSONEncoder().encode(sampleState(expenses: [expense])))
        XCTAssertEqual(cleaned.expenses.first?.category, "其他")

        let dup1 = expense
        let dup2 = ExpenseDTO(id: "a", _dbId: nil, date: "2026-08-02", amount: 3,
                              category: "餐饮", note: "", createdAt: "2026-08-01T00:00:00Z",
                              isSample: false)
        let badData = try! JSONEncoder().encode(sampleState(expenses: [dup1, dup2]))
        XCTAssertThrowsError(try ImportValidator.decodeImportedState(data: badData))
    }

    func testLegacyBackupFileDecodes() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("archive/legacy-2026-09-04/账本数据/backups/ledger-state-2026-09-03T12-17-00.json")
        let data = try Data(contentsOf: url)
        let state = try ImportValidator.decodeImportedState(data: data)
        XCTAssertFalse(state.expenses.isEmpty)
        XCTAssertFalse(state.summaries.isEmpty)
        XCTAssertEqual(state.settings.theme, "light")
    }
}
