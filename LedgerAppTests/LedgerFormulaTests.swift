import XCTest
@testable import LedgerApp

final class LedgerFormulaTests: XCTestCase {
    func testHourlyProfileMatchesReferenceInputs() {
        let profile = LedgerProfile()
        profile.monthlySalary = 13800
        profile.payMonths = 13
        profile.monthlyWorkCost = 850
        profile.dailyOfficeHours = 9
        profile.oneWayCommuteMinutes = 48
        profile.weeklyOvertimeHours = 6

        let r = LedgerMath.hourlyProfile(profile: profile)
        XCTAssertEqual(r.annualIncome, 179400, accuracy: 0.01)
        XCTAssertEqual(r.netAnnualIncome, 169200, accuracy: 0.01)
        XCTAssertEqual(r.monthlyOfficeHours, 195.75, accuracy: 0.01)
        XCTAssertEqual(r.monthlyCommuteHours, 34.8, accuracy: 0.01)
        XCTAssertEqual(r.monthlyOvertimeHours, 26, accuracy: 0.01)
        XCTAssertEqual(r.annualInvestedHours, 3078.6, accuracy: 0.01)
        XCTAssertEqual(r.nominalHourly ?? 0, 79.31, accuracy: 0.01)
        XCTAssertEqual(r.realHourly ?? 0, 54.96, accuracy: 0.01)
        XCTAssertEqual(r.gapDirection, "lower")
    }

    func testMonthlyBalance() {
        XCTAssertEqual(LedgerMath.monthlyBalance(income: 13800, fixed: 5600, flexible: 3500) ?? 0,
                       4700, accuracy: 0.001)
        XCTAssertEqual(LedgerMath.monthlyBalance(income: 1000, fixed: 1200, flexible: 100) ?? 0,
                       -300, accuracy: 0.001)
    }

    func testFreedomForecast() {
        let f = LedgerMath.freedomForecast(currentSaved: 36800,
                                           targetAmount: 120000,
                                           averageMonthlySavings: 4700,
                                           now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(f.remainingAmount, 83200, accuracy: 0.001)
        XCTAssertEqual(f.remainingMonths, 18)
        XCTAssertEqual(f.achieved, false)
    }

    func testSafetyBuffer() {
        let s = LedgerMath.safetyBuffer(currentSaved: 36800, basicMonthlyCost: 5600)
        XCTAssertEqual(s.months ?? 0, 6.57, accuracy: 0.01)
        XCTAssertEqual(s.levels.map(\.reached), [true, true, false])
    }
}
