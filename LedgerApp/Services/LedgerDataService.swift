import Foundation
import SwiftData

@MainActor
final class LedgerDataService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Singletons

    func profile() throws -> LedgerProfile {
        let list = try context.fetch(FetchDescriptor<LedgerProfile>())
        if let first = list.first { return first }
        let p = LedgerProfile()
        context.insert(p)
        try context.save()
        return p
    }

    func freedom() throws -> FreedomPlan {
        let list = try context.fetch(FetchDescriptor<FreedomPlan>())
        if let first = list.first { return first }
        let p = FreedomPlan()
        context.insert(p)
        try context.save()
        return p
    }

    func settings() throws -> LedgerSettings {
        let list = try context.fetch(FetchDescriptor<LedgerSettings>())
        if let first = list.first { return first }
        let p = LedgerSettings()
        context.insert(p)
        try context.save()
        return p
    }

    func hasAnyData() -> Bool {
        guard let count = try? context.fetchCount(FetchDescriptor<ExpenseRecord>()) else { return true }
        if count > 0 { return true }
        guard let summaryCount = try? context.fetchCount(FetchDescriptor<MonthlySummaryRecord>()) else { return true }
        return summaryCount > 0
    }

    // MARK: Import / replace

    func replaceAll(with state: ImportedState) throws {
        try context.delete(model: ExpenseRecord.self)
        try context.delete(model: MonthlySummaryRecord.self)
        try context.delete(model: LedgerProfile.self)
        try context.delete(model: FreedomPlan.self)
        try context.delete(model: LedgerSettings.self)
        try context.delete(model: MonthlyReportRecord.self)

        let profile = LedgerProfile()
        profile.monthlySalary = state.profile.monthlySalary
        profile.payMonths = state.profile.payMonths
        profile.monthlyWorkCost = state.profile.monthlyWorkCost
        profile.dailyOfficeHours = state.profile.dailyOfficeHours
        profile.oneWayCommuteMinutes = state.profile.oneWayCommuteMinutes
        profile.weeklyOvertimeHours = state.profile.weeklyOvertimeHours
        profile.isSample = state.profile.isSample ?? false
        context.insert(profile)

        for item in state.expenses {
            let record = ExpenseRecord(
                id: item.id,
                dbId: item._dbId,
                dateKey: item.date,
                amount: item.amount,
                category: item.category,
                note: item.note,
                createdAt: DateSupport.parseISO(item.createdAt) ?? Date(),
                isSample: item.isSample ?? false
            )
            context.insert(record)
        }

        for item in state.summaries {
            let record = MonthlySummaryRecord(
                monthKey: item.month,
                dbId: item._dbId,
                income: item.income,
                fixed: item.fixed,
                flexible: item.flexible,
                updatedAt: DateSupport.parseISO(item.updatedAt) ?? Date(timeIntervalSince1970: 0),
                isSample: item.isSample ?? false
            )
            context.insert(record)
        }

        let freedom = FreedomPlan()
        freedom.targetAmount = state.freedom.targetAmount
        freedom.targetDate = state.freedom.targetDate
        freedom.reason = state.freedom.reason
        freedom.currentSaved = state.freedom.currentSaved
        freedom.basicMonthlyCost = state.freedom.basicMonthlyCost
        freedom.startMonth = state.freedom.startMonth
        freedom.isSample = state.freedom.isSample ?? false
        context.insert(freedom)

        let settings = LedgerSettings()
        settings.themeRaw = state.settings.theme
        settings.sampleStateRaw = state.settings.sampleState
        context.insert(settings)

        try context.save()
    }

    func clearSamples(keepTheme: String? = nil) throws {
        let theme = try? settings().themeRaw
        let expenses = try context.fetch(FetchDescriptor<ExpenseRecord>(
            predicate: #Predicate { $0.isSample }))
        for e in expenses { context.delete(e) }
        let summaries = try context.fetch(FetchDescriptor<MonthlySummaryRecord>(
            predicate: #Predicate { $0.isSample }))
        for s in summaries { context.delete(s) }
        let profile = try profile()
        let freedom = try freedom()
        if profile.isSample {
            profile.isSample = false
            profile.monthlySalary = 0
            profile.payMonths = LedgerConstants.defaultPayMonths
            profile.monthlyWorkCost = 0
            profile.dailyOfficeHours = LedgerConstants.defaultOfficeHours
            profile.oneWayCommuteMinutes = 0
            profile.weeklyOvertimeHours = 0
        }
        if freedom.isSample {
            freedom.isSample = false
            freedom.targetAmount = 0
            freedom.targetDate = nil
            freedom.reason = ""
            freedom.currentSaved = 0
            freedom.basicMonthlyCost = 0
            freedom.startMonth = nil
        }
        let st = try settings()
        st.sampleStateRaw = "cleared"
        if let theme { st.themeRaw = theme }
        try context.save()
    }

    func exportData(profile: LedgerProfile, expenses: [ExpenseRecord],
                    summaries: [MonthlySummaryRecord], freedom: FreedomPlan,
                    settings: LedgerSettings) throws -> Data {
        let state = ImportValidator.makeState(profile: profile, expenses: expenses,
                                              summaries: summaries, freedom: freedom,
                                              settings: settings)
        let payload = ImportPayloadDTO(appId: LedgerConstants.appId,
                                       version: LedgerConstants.currentVersion,
                                       state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}
