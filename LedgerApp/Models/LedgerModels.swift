import Foundation
import SwiftData

// MARK: - Categories

enum LedgerConstants {
    static let appId = "worker-ledger"
    static let currentVersion = 1
    static let maxExpenses = 2000
    static let maxSummaries = 240
    static let maxImportBytes = 2_000_000
    static let workDaysPerMonth = 21.75
    static let defaultOfficeHours = 8.0
    static let defaultPayMonths = 12.0

    /// Page categories（与云端 19 类一致；收入不进入支出流水）
    static let pageCategories = [
        "餐饮", "交通", "购物", "房租/水电", "通讯/网络", "娱乐", "医疗", "教育",
        "旅行", "人情", "工作", "宠物", "健身", "美妆", "快递/物流", "投资", "储蓄", "其他"
    ]
    /// 历史 6 类兼容
    static let legacyCategories = ["吃饭", "房租"]

    static var validCategories: [String] { pageCategories + legacyCategories }

    static func cleanCategory(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return validCategories.contains(trimmed) ? trimmed : "其他"
    }
}

// MARK: - SwiftData Entities

@Model
final class ExpenseRecord {
    @Attribute(.unique) var id: String
    var dbId: String?
    var dateKey: String      // YYYY-MM-DD，按本地日历
    var amount: Double
    var category: String
    var note: String
    var createdAt: Date
    var isSample: Bool

    init(id: String, dbId: String? = nil, dateKey: String, amount: Double,
         category: String, note: String, createdAt: Date, isSample: Bool) {
        self.id = id
        self.dbId = dbId
        self.dateKey = dateKey
        self.amount = amount
        self.category = category
        self.note = note
        self.createdAt = createdAt
        self.isSample = isSample
    }
}

@Model
final class MonthlySummaryRecord {
    @Attribute(.unique) var monthKey: String   // YYYY-MM
    var dbId: String?
    var income: Double
    var fixed: Double
    var flexible: Double
    var updatedAt: Date
    var isSample: Bool

    init(monthKey: String, dbId: String? = nil, income: Double, fixed: Double,
         flexible: Double, updatedAt: Date, isSample: Bool) {
        self.monthKey = monthKey
        self.dbId = dbId
        self.income = income
        self.fixed = fixed
        self.flexible = flexible
        self.updatedAt = updatedAt
        self.isSample = isSample
    }

    var balance: Double { income - fixed - flexible }
}

@Model
final class LedgerProfile {
    @Attribute(.unique) var id: String
    var monthlySalary: Double
    var payMonths: Double
    var monthlyWorkCost: Double
    var dailyOfficeHours: Double
    var oneWayCommuteMinutes: Double
    var weeklyOvertimeHours: Double
    var isSample: Bool

    init(id: String = "profile") {
        self.id = id
        self.monthlySalary = 0
        self.payMonths = LedgerConstants.defaultPayMonths
        self.monthlyWorkCost = 0
        self.dailyOfficeHours = LedgerConstants.defaultOfficeHours
        self.oneWayCommuteMinutes = 0
        self.weeklyOvertimeHours = 0
        self.isSample = false
    }
}

@Model
final class FreedomPlan {
    @Attribute(.unique) var id: String
    var targetAmount: Double
    var targetDate: String?    // YYYY-MM
    var reason: String
    var currentSaved: Double
    var basicMonthlyCost: Double
    var startMonth: String?    // YYYY-MM
    var isSample: Bool

    init(id: String = "freedom") {
        self.id = id
        self.targetAmount = 0
        self.targetDate = nil
        self.reason = ""
        self.currentSaved = 0
        self.basicMonthlyCost = 0
        self.startMonth = nil
        self.isSample = false
    }
}

@Model
final class LedgerSettings {
    @Attribute(.unique) var id: String
    var themeRaw: String        // light | dark
    var sampleStateRaw: String  // active | cleared | custom

    init(id: String = "settings") {
        self.id = id
        self.themeRaw = "light"
        self.sampleStateRaw = "custom"
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .light }
        set { themeRaw = newValue.rawValue }
    }
    var sampleState: SampleState {
        get { SampleState(rawValue: sampleStateRaw) ?? .custom }
        set { sampleStateRaw = newValue.rawValue }
    }
}

@Model
final class MonthlyReportRecord {
    @Attribute(.unique) var id: String
    var title: String
    var year: Int
    var month: Int
    var content: String
    var createdAt: Date

    init(id: String, title: String, year: Int, month: Int, content: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.year = year
        self.month = month
        self.content = content
        self.createdAt = createdAt
    }
}

enum AppTheme: String, CaseIterable {
    case light, dark
}

enum SampleState: String, CaseIterable {
    case active, cleared, custom
}
