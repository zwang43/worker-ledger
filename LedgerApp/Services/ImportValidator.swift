import Foundation

enum ImportValidator {
    static func decodeImportedState(data: Data) throws -> ImportedState {
        guard data.count <= LedgerConstants.maxImportBytes else {
            throw ImportError.tooLarge
        }
        // 优先解析正式导出包装 {appId, version, state}
        if let payload = try? JSONDecoder().decode(ImportPayloadDTO.self, from: data) {
            guard payload.appId == LedgerConstants.appId else { throw ImportError.appIdMismatch }
            guard payload.version >= 1 else { throw ImportError.badVersion }
            guard payload.version <= LedgerConstants.currentVersion else { throw ImportError.futureVersion }
            return try clean(payload.state)
        }
        // 其次解析旧备份裸 state JSON
        guard let state = try? JSONDecoder().decode(LedgerStateDTO.self, from: data) else {
            throw ImportError.notObject
        }
        return try clean(state)
    }

    static func clean(_ state: LedgerStateDTO) throws -> ImportedState {
        let profile = try cleanProfile(state.profile)
        let expenses = try cleanExpenses(state.expenses)
        let summaries = try cleanSummaries(state.monthlySummaries)
        let freedom = try cleanFreedom(state.freedom)
        let settings = cleanSettings(state.settings)
        return ImportedState(profile: profile, expenses: expenses,
                             summaries: summaries, freedom: freedom,
                             settings: settings)
    }

    private static func nonNegative(_ value: Double, fallback: Double = 0) -> Double {
        guard value.isFinite, value >= 0 else { return fallback }
        return (value * 100).rounded() / 100
    }

    private static func text(_ value: String?, maxLength: Int, fallback: String = "") -> String {
        let s = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.count <= maxLength ? s : String(s.prefix(maxLength))
    }

    private static func cleanProfile(_ value: ProfileDTO) throws -> ProfileDTO {
        let fallback = ProfileDTO(monthlySalary: 0, payMonths: LedgerConstants.defaultPayMonths,
                                  monthlyWorkCost: 0, dailyOfficeHours: LedgerConstants.defaultOfficeHours,
                                  oneWayCommuteMinutes: 0, weeklyOvertimeHours: 0, isSample: false)
        guard value.monthlySalary.isFinite, value.payMonths.isFinite,
              value.monthlyWorkCost.isFinite, value.dailyOfficeHours.isFinite,
              value.oneWayCommuteMinutes.isFinite, value.weeklyOvertimeHours.isFinite else {
            throw ImportError.invalidProfile("包含非数字字段")
        }
        return ProfileDTO(
            monthlySalary: nonNegative(value.monthlySalary),
            payMonths: nonNegative(value.payMonths, fallback: fallback.payMonths),
            monthlyWorkCost: nonNegative(value.monthlyWorkCost),
            dailyOfficeHours: nonNegative(value.dailyOfficeHours, fallback: fallback.dailyOfficeHours),
            oneWayCommuteMinutes: nonNegative(value.oneWayCommuteMinutes),
            weeklyOvertimeHours: nonNegative(value.weeklyOvertimeHours),
            isSample: value.isSample == true
        )
    }

    private static func cleanExpenses(_ list: [ExpenseDTO]) throws -> [ExpenseDTO] {
        guard list.count <= LedgerConstants.maxExpenses else {
            throw ImportError.invalidExpenses("记录数超过 \(LedgerConstants.maxExpenses)")
        }
        var ids = Set<String>()
        return try list.map { item in
            let id = text(item.id, maxLength: 100, fallback: "")
            guard !id.isEmpty, !ids.contains(id) else {
                throw ImportError.invalidExpenses("存在重复或空 ID")
            }
            ids.insert(id)
            guard DateSupport.isValidDateKey(item.date) else {
                throw ImportError.invalidExpenses("日期非法：\(item.date)")
            }
            guard DateSupport.parseISO(item.createdAt) != nil else {
                throw ImportError.invalidExpenses("创建时间非法")
            }
            return ExpenseDTO(
                id: id,
                _dbId: item._dbId == nil ? nil : String(item._dbId!),
                date: item.date,
                amount: nonNegative(item.amount),
                category: LedgerConstants.cleanCategory(item.category),
                note: text(item.note, maxLength: 300),
                createdAt: item.createdAt,
                isSample: item.isSample == true
            )
        }
    }

    private static func cleanSummaries(_ list: [MonthlySummaryDTO]) throws -> [MonthlySummaryDTO] {
        guard list.count <= LedgerConstants.maxSummaries else {
            throw ImportError.invalidSummaries("记录数超过 \(LedgerConstants.maxSummaries)")
        }
        var months = Set<String>()
        return try list.map { item in
            guard DateSupport.isValidMonthKey(item.month), !months.contains(item.month) else {
                throw ImportError.invalidSummaries("月份非法或重复：\(item.month)")
            }
            months.insert(item.month)
            return MonthlySummaryDTO(
                month: item.month,
                _dbId: item._dbId == nil ? nil : String(item._dbId!),
                income: nonNegative(item.income),
                fixed: nonNegative(item.fixed),
                flexible: nonNegative(item.flexible),
                updatedAt: item.updatedAt,
                isSample: item.isSample == true
            )
        }
    }

    private static func cleanFreedom(_ value: FreedomDTO) throws -> FreedomDTO {
        if let target = value.targetDate, !target.isEmpty, !DateSupport.isValidMonthKey(target) {
            throw ImportError.invalidFreedom("目标月份非法")
        }
        if let start = value.startMonth, !start.isEmpty, !DateSupport.isValidMonthKey(start) {
            throw ImportError.invalidFreedom("起始月份非法")
        }
        return FreedomDTO(
            targetAmount: nonNegative(value.targetAmount),
            targetDate: (value.targetDate ?? "").isEmpty ? nil : value.targetDate,
            reason: text(value.reason, maxLength: 300),
            currentSaved: nonNegative(value.currentSaved),
            basicMonthlyCost: nonNegative(value.basicMonthlyCost),
            startMonth: (value.startMonth ?? "").isEmpty ? nil : value.startMonth,
            isSample: value.isSample == true
        )
    }

    private static func cleanSettings(_ value: SettingsDTO) -> SettingsDTO {
        let theme = value.theme == "dark" ? "dark" : "light"
        let state = ["active", "cleared", "custom"].contains(value.sampleState)
            ? value.sampleState : "custom"
        return SettingsDTO(theme: theme, sampleState: state)
    }

    /// 由内存中的实体状态生成导出 DTO。
    static func makeState(profile: LedgerProfile, expenses: [ExpenseRecord],
                          summaries: [MonthlySummaryRecord], freedom: FreedomPlan,
                          settings: LedgerSettings) -> LedgerStateDTO {
        LedgerStateDTO(
            profile: ProfileDTO(
                monthlySalary: profile.monthlySalary,
                payMonths: profile.payMonths,
                monthlyWorkCost: profile.monthlyWorkCost,
                dailyOfficeHours: profile.dailyOfficeHours,
                oneWayCommuteMinutes: profile.oneWayCommuteMinutes,
                weeklyOvertimeHours: profile.weeklyOvertimeHours,
                isSample: profile.isSample),
            expenses: expenses.sorted { $0.dateKey > $1.dateKey }.map {
                ExpenseDTO(id: $0.id, _dbId: $0.dbId, date: $0.dateKey,
                           amount: $0.amount, category: $0.category, note: $0.note,
                           createdAt: DateSupport.isoString($0.createdAt), isSample: $0.isSample)
            },
            monthlySummaries: summaries.sorted { $0.monthKey > $1.monthKey }.map {
                MonthlySummaryDTO(month: $0.monthKey, _dbId: $0.dbId,
                                  income: $0.income, fixed: $0.fixed, flexible: $0.flexible,
                                  updatedAt: DateSupport.isoString($0.updatedAt), isSample: $0.isSample)
            },
            freedom: FreedomDTO(targetAmount: freedom.targetAmount,
                                targetDate: freedom.targetDate,
                                reason: freedom.reason,
                                currentSaved: freedom.currentSaved,
                                basicMonthlyCost: freedom.basicMonthlyCost,
                                startMonth: freedom.startMonth,
                                isSample: freedom.isSample),
            settings: SettingsDTO(theme: settings.themeRaw, sampleState: settings.sampleStateRaw)
        )
    }
}
