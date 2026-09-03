import Foundation

// 与旧 localStorage/导出完全一致的原始 DTO。
struct LedgerStateDTO: Codable {
    var profile: ProfileDTO
    var expenses: [ExpenseDTO]
    var monthlySummaries: [MonthlySummaryDTO]
    var freedom: FreedomDTO
    var settings: SettingsDTO
}

struct ImportPayloadDTO: Codable {
    var appId: String
    var version: Int
    var state: LedgerStateDTO
}

struct ExpenseDTO: Codable {
    var id: String
    var _dbId: String?
    var date: String
    var amount: Double
    var category: String
    var note: String
    var createdAt: String
    var isSample: Bool?
}

struct MonthlySummaryDTO: Codable {
    var month: String
    var _dbId: String?
    var income: Double
    var fixed: Double
    var flexible: Double
    var updatedAt: String
    var isSample: Bool?
}

struct ProfileDTO: Codable {
    var monthlySalary: Double
    var payMonths: Double
    var monthlyWorkCost: Double
    var dailyOfficeHours: Double
    var oneWayCommuteMinutes: Double
    var weeklyOvertimeHours: Double
    var isSample: Bool?
}

struct FreedomDTO: Codable {
    var targetAmount: Double
    var targetDate: String?
    var reason: String
    var currentSaved: Double
    var basicMonthlyCost: Double
    var startMonth: String?
    var isSample: Bool?
}

struct SettingsDTO: Codable {
    var theme: String
    var sampleState: String
}

struct ImportedState {
    let profile: ProfileDTO
    let expenses: [ExpenseDTO]
    let summaries: [MonthlySummaryDTO]
    let freedom: FreedomDTO
    let settings: SettingsDTO
}

enum ImportError: LocalizedError {
    case notObject
    case tooLarge
    case appIdMismatch
    case badVersion
    case futureVersion
    case missingState
    case invalidExpenses(String)
    case invalidSummaries(String)
    case invalidProfile(String)
    case invalidFreedom(String)

    var errorDescription: String? {
        switch self {
        case .notObject: return "导入包格式无效"
        case .tooLarge: return "导入文件过大（超过 2 MB）"
        case .appIdMismatch: return "应用标识不匹配"
        case .badVersion: return "导入版本无效"
        case .futureVersion: return "导入版本高于当前版本"
        case .missingState: return "导入状态无效"
        case .invalidExpenses(let m): return "支出记录无效：\(m)"
        case .invalidSummaries(let m): return "月度总结无效：\(m)"
        case .invalidProfile(let m): return "个人设置无效：\(m)"
        case .invalidFreedom(let m): return "自由基金设置无效：\(m)"
        }
    }
}
