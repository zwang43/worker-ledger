import Foundation
import SwiftData

@MainActor
enum LedgerActions {
    static func insertExpense(context: ModelContext,
                              id: String = UUID().uuidString,
                              dbId: String? = nil,
                              dateKey: String,
                              amount: Double,
                              category: String,
                              note: String,
                              createdAt: Date = Date(),
                              isSample: Bool = false) throws -> ExpenseRecord {
        let record = ExpenseRecord(id: id, dbId: dbId, dateKey: dateKey,
                                   amount: amount, category: category,
                                   note: note, createdAt: createdAt,
                                   isSample: isSample)
        context.insert(record)
        try context.save()
        return record
    }

    static func upsertSummary(context: ModelContext, monthKey: String,
                              income: Double, fixed: Double, flexible: Double,
                              existing: MonthlySummaryRecord?,
                              isSample: Bool = false) throws {
        if let existing {
            existing.income = income
            existing.fixed = fixed
            existing.flexible = flexible
            existing.isSample = isSample
            existing.updatedAt = Date()
        } else {
            let record = MonthlySummaryRecord(
                monthKey: monthKey,
                dbId: existing?.dbId,
                income: income,
                fixed: fixed,
                flexible: flexible,
                updatedAt: Date(),
                isSample: isSample)
            context.insert(record)
        }
        try context.save()
    }

    static func delete(_ expense: ExpenseRecord, context: ModelContext) {
        context.delete(expense)
        try? context.save()
    }

    static func delete(_ summary: MonthlySummaryRecord, context: ModelContext) {
        context.delete(summary)
        try? context.save()
    }
}
