import XCTest
@testable import LedgerApp

final class MonthlyReportTests: XCTestCase {
    func testDefaultMonthIsPreviousMonth() {
        let comps = DateComponents(year: 2026, month: 9, day: 15)
        let date = Calendar.current.date(from: comps)!
        let d = MonthlyReportService.defaultMonth(now: date)
        XCTAssertEqual(d.year, 2026)
        XCTAssertEqual(d.month, 8)
    }

    func testGenerateUsesMonthlySummary() throws {
        let summary = MonthlySummaryRecord(monthKey: "2026-08", dbId: nil,
                                           income: 13800, fixed: 5600,
                                           flexible: 3500, updatedAt: Date(),
                                           isSample: false)
        let expense = ExpenseRecord(id: "1", dateKey: "2026-08-10", amount: 80,
                                    category: "餐饮", note: "聚餐",
                                    createdAt: Date(), isSample: false)
        let report = try MonthlyReportService.generate(year: 2026, month: 8,
                                                       expenses: [expense],
                                                       summary: summary)
        XCTAssertEqual(report.title, "月度账单报告 - 2026年8月")
        XCTAssertTrue(report.content.contains("总收入"))
        XCTAssertTrue(report.content.contains("13800.00"))
        XCTAssertTrue(report.content.contains("聚餐"))
        XCTAssertFalse(report.content.contains("未填写"))
    }

    func testGenerateFallsBackWhenNoSummary() throws {
        let housing = ExpenseRecord(id: "1", dateKey: "2026-08-02", amount: 5600,
                                    category: "房租/水电", note: "房租",
                                    createdAt: Date(), isSample: false)
        let report = try MonthlyReportService.generate(year: 2026, month: 8,
                                                       expenses: [housing],
                                                       summary: nil)
        XCTAssertTrue(report.content.contains("未填写"))
        XCTAssertTrue(report.content.contains("5600.00"))
    }
}
