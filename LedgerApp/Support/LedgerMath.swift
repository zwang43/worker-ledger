import Foundation

struct HourlyBreakdown: Equatable {
    var nominalHourly: Double?
    var realHourly: Double?
    var gapDirection: String   // invalid | equal | lower | higher
    var gapRatio: Double?
    var annualIncome: Double
    var annualWorkCost: Double
    var netAnnualIncome: Double
    var monthlyOfficeHours: Double
    var monthlyCommuteHours: Double
    var monthlyOvertimeHours: Double
    var annualInvestedHours: Double
}

enum LedgerMath {
    static func finiteNonNegative(_ value: Double, fallback: Double = 0) -> Double {
        value.isFinite && value >= 0 ? value : fallback
    }

    static func round(_ value: Double, digits: Int = 2) -> Double? {
        guard value.isFinite else { return nil }
        let power = pow(10.0, Double(digits))
        return (value * power).rounded() / power
    }

    static func hourlyProfile(profile: LedgerProfile) -> HourlyBreakdown {
        let salary = finiteNonNegative(profile.monthlySalary)
        let payMonths = finiteNonNegative(profile.payMonths)
        let workCost = finiteNonNegative(profile.monthlyWorkCost)
        let officeHours = finiteNonNegative(profile.dailyOfficeHours)
        let commuteMinutes = finiteNonNegative(profile.oneWayCommuteMinutes)
        let overtimeWeekly = finiteNonNegative(profile.weeklyOvertimeHours)

        let nominal = salary > 0 ? salary / LedgerConstants.workDaysPerMonth / 8 : nil
        let annualIncome = salary * payMonths
        let annualWorkCost = workCost * 12
        let netAnnual = annualIncome - annualWorkCost
        let monthlyOffice = officeHours * LedgerConstants.workDaysPerMonth
        let monthlyCommute = commuteMinutes * 2 * LedgerConstants.workDaysPerMonth / 60
        let monthlyOvertime = overtimeWeekly * 52 / 12
        let annualHours = (monthlyOffice + monthlyCommute + monthlyOvertime) * 12
        let real = netAnnual > 0 && annualHours > 0 ? netAnnual / annualHours : nil

        var direction = "invalid"
        var ratio: Double?
        if let nominal, let real {
            ratio = abs(nominal - real) / nominal
            if abs(nominal - real) < 0.000001 {
                direction = "equal"
            } else {
                direction = real < nominal ? "lower" : "higher"
            }
        }

        return HourlyBreakdown(
            nominalHourly: nominal.flatMap { round($0) },
            realHourly: real.flatMap { round($0) },
            gapDirection: direction,
            gapRatio: round(ratio ?? 0, digits: 4),
            annualIncome: round(annualIncome) ?? 0,
            annualWorkCost: round(annualWorkCost) ?? 0,
            netAnnualIncome: round(netAnnual) ?? 0,
            monthlyOfficeHours: round(monthlyOffice) ?? 0,
            monthlyCommuteHours: round(monthlyCommute) ?? 0,
            monthlyOvertimeHours: round(monthlyOvertime) ?? 0,
            annualInvestedHours: round(annualHours) ?? 0
        )
    }

    static func monthlyBalance(income: Double, fixed: Double, flexible: Double) -> Double? {
        round(finiteNonNegative(income) - finiteNonNegative(fixed) - finiteNonNegative(flexible))
    }

    static func recentCompleteMonths(_ summaries: [MonthlySummaryRecord], currentMonth: String = DateSupport.localMonthKey()) -> (average: Double?, months: [String], balances: [Double]) {
        let valid = summaries
            .filter { DateSupport.isValidMonthKey($0.monthKey) && $0.monthKey < currentMonth }
            .sorted { $0.monthKey < $1.monthKey }
            .suffix(6)
        let balances = valid.map { $0.balance }
        let avg = balances.isEmpty ? nil : (round(balances.reduce(0, +) / Double(balances.count)) ?? 0)
        return (avg, valid.map(\.monthKey), balances)
    }

    static func lastDayOfMonth(after monthsToAdd: Int, now: Date = Date()) -> String {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        guard let target = cal.date(byAdding: .month, value: monthsToAdd + 1, to: now) else {
            return DateSupport.localDateKey()
        }
        let targetMonth = cal.dateComponents([.year, .month], from: target)
        let comps = DateComponents(year: targetMonth.year,
                                   month: targetMonth.month,
                                   day: 0)
        guard let lastDate = cal.date(from: comps) else {
            return DateSupport.localDateKey()
        }
        let d = cal.dateComponents([.year, .month, .day], from: lastDate)
        return DateSupport.dateKey(year: d.year ?? 0, month: d.month ?? 1, day: d.day ?? 1)
    }

    struct FreedomForecast {
        var remainingAmount: Double
        var progressRatio: Double?
        var remainingMonths: Int?
        var estimatedDate: String?
        var achieved: Bool
    }

    static func freedomForecast(currentSaved: Double, targetAmount: Double,
                                averageMonthlySavings: Double?, now: Date = Date()) -> FreedomForecast {
        let saved = finiteNonNegative(currentSaved)
        let target = finiteNonNegative(targetAmount)
        let remaining = max(0, target - saved)
        let ratio: Double? = target > 0 ? round(saved / target, digits: 4) : nil

        if target > 0 && remaining == 0 {
            return FreedomForecast(remainingAmount: 0, progressRatio: ratio,
                                   remainingMonths: 0,
                                   estimatedDate: lastDayOfMonth(after: 0, now: now),
                                   achieved: true)
        }
        guard let avg = averageMonthlySavings, avg.isFinite, avg > 0, target > 0 else {
            return FreedomForecast(remainingAmount: round(remaining) ?? 0, progressRatio: ratio,
                                   remainingMonths: nil, estimatedDate: nil, achieved: false)
        }
        let months = Int(ceil(remaining / avg))
        return FreedomForecast(remainingAmount: round(remaining) ?? 0, progressRatio: ratio,
                               remainingMonths: months,
                               estimatedDate: lastDayOfMonth(after: months, now: now),
                               achieved: false)
    }

    static func safetyBuffer(currentSaved: Double, basicMonthlyCost: Double) -> (months: Double?, levels: [(months: Int, reached: Bool)]) {
        let saved = finiteNonNegative(currentSaved)
        let cost = finiteNonNegative(basicMonthlyCost)
        let months: Double? = cost > 0 ? saved / cost : nil
        return (months.flatMap { round($0) },
                [3, 6, 12].map { (months: $0, reached: months != nil && months! >= Double($0)) })
    }

    struct Scenario {
        var id: String
        var monthlyCashGain: Double
        var monthlyTimeSaved: Double
        var freedomEquivalentGain: Double
        var cashProjectedMonths: Int?
        var freedomProjectedMonths: Int?
    }

    static func projectedMonths(remaining: Double, speed: Double) -> Int? {
        guard remaining > 0 else { return 0 }
        return speed > 0 ? Int(ceil(remaining / speed)) : nil
    }

    static func simulateScenarios(profile: LedgerProfile, realHourly: Double?,
                                  remainingAmount: Double, averageMonthlySavings: Double?,
                                  commuteReductionPercent: Double, overtimeReductionHours: Double,
                                  salaryIncreasePercent: Double) -> (scenarios: [Scenario], cashFastestId: String?, freedomFastestId: String?) {
        let hourly = finiteNonNegative(realHourly ?? 0)
        let remaining = finiteNonNegative(remainingAmount)
        let base = (averageMonthlySavings ?? 0).isFinite ? (averageMonthlySavings ?? 0) : 0
        let commutePct = min(100, finiteNonNegative(commuteReductionPercent))
        let overtimeHours = min(finiteNonNegative(profile.weeklyOvertimeHours), finiteNonNegative(overtimeReductionHours))
        let salaryPct = min(300, finiteNonNegative(salaryIncreasePercent))

        let commuteTime = finiteNonNegative(profile.oneWayCommuteMinutes)
            * 2 * LedgerConstants.workDaysPerMonth / 60 * commutePct / 100
        let overtimeTime = overtimeHours * 52 / 12
        let salaryCash = finiteNonNegative(profile.monthlySalary)
            * finiteNonNegative(profile.payMonths) * salaryPct / 100 / 12

        var scenarios = [
            Scenario(id: "commute", monthlyCashGain: 0,
                     monthlyTimeSaved: round(commuteTime) ?? 0,
                     freedomEquivalentGain: round(commuteTime * hourly) ?? 0,
                     cashProjectedMonths: projectedMonths(remaining: remaining, speed: base),
                     freedomProjectedMonths: projectedMonths(remaining: remaining, speed: base + commuteTime * hourly)),
            Scenario(id: "overtime", monthlyCashGain: 0,
                     monthlyTimeSaved: round(overtimeTime) ?? 0,
                     freedomEquivalentGain: round(overtimeTime * hourly) ?? 0,
                     cashProjectedMonths: projectedMonths(remaining: remaining, speed: base),
                     freedomProjectedMonths: projectedMonths(remaining: remaining, speed: base + overtimeTime * hourly)),
            Scenario(id: "salary", monthlyCashGain: round(salaryCash) ?? 0,
                     monthlyTimeSaved: 0,
                     freedomEquivalentGain: round(salaryCash) ?? 0,
                     cashProjectedMonths: projectedMonths(remaining: remaining, speed: base + salaryCash),
                     freedomProjectedMonths: projectedMonths(remaining: remaining, speed: base + salaryCash))
        ]

        let cashFastest = scenarios
            .filter { $0.monthlyCashGain > 0 }
            .sorted {
                switch ($0.cashProjectedMonths, $1.cashProjectedMonths) {
                case (.some, .none): return true
                case (.none, .some): return false
                case (.some(let a), .some(let b)): return a < b
                default: return false
                }
            }.first
        let freedomFastest = scenarios
            .filter { $0.freedomProjectedMonths != nil }
            .sorted { ($0.freedomProjectedMonths ?? Int.max) < ($1.freedomProjectedMonths ?? Int.max) }
            .first
        return (scenarios, cashFastest?.id, freedomFastest?.id)
    }
}
