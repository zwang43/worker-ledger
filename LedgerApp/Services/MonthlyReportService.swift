import Foundation

struct GeneratedReport {
    let title: String
    let year: Int
    let month: Int
    let content: String
    let createdAt: Date
}

enum MonthlyReportService {
    static func defaultMonth(now: Date = Date()) -> (year: Int, month: Int) {
        let key = DateSupport.previousMonthKey(now: now)
        let p = key.split(separator: "-").compactMap { Int($0) }
        return (p[0], p[1])
    }

    static func generate(year: Int, month: Int,
                         expenses: [ExpenseRecord],
                         summary: MonthlySummaryRecord?) throws -> GeneratedReport {
        guard (1...12).contains(month) else { throw ReportError.invalidMonth }
        let monthKey = DateSupport.monthKey(year: year, month: month)
        guard let range = DateSupport.monthRange(for: monthKey) else { throw ReportError.invalidMonth }

        let monthExpenses = expenses
            .filter { $0.dateKey >= range.start && $0.dateKey <= range.end }
            .sorted { $0.dateKey < $1.dateKey }

        let income: Double
        let fixed: Double
        let flexible: Double
        var note = ""
        if let summary {
            income = summary.income
            fixed = summary.fixed
            flexible = summary.flexible
        } else {
            let fixedCats = ["房租/水电", "房租"]
            fixed = monthExpenses.filter { fixedCats.contains($0.category) }
                .reduce(0) { $0 + $1.amount }
            flexible = monthExpenses.reduce(0) { $0 + $1.amount } - fixed
            income = 0
            note = "> 注意：该月未填写“月度总结”，收入按 0 计，固定/弹性支出由流水按分类估算。\n\n"
        }

        let balance = income - fixed - flexible
        let savingsRate = income > 0 ? (income - fixed - flexible) / income * 100 : 0
        let categoryMap = Dictionary(grouping: monthExpenses) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .sorted { $0.key < $1.key }

        var lines: [String] = []
        lines.append("# 月度账单报告 - \(year)年\(month)月")
        lines.append("")
        lines.append("## 基本信息")
        lines.append("- **报告月份**：\(year)年\(month)月")
        lines.append("- **生成时间**：\(DateFormatter.cn.string(from: Date()))")
        lines.append("- **统计周期**：\(DateSupport.displayDate(range.start)) 至 \(DateSupport.displayDate(range.end))")
        lines.append("")
        lines.append("## 收支统计")
        lines.append("- **总收入**：¥\(money(income))")
        lines.append("- **固定支出**：¥\(money(fixed))")
        lines.append("- **弹性支出**：¥\(money(flexible))")
        lines.append("- **本月结余**：¥\(money(balance))")
        lines.append("- **储蓄率**：\(String(format: "%.1f%%", savingsRate))")
        lines.append("- **交易笔数**：\(monthExpenses.count) 笔")
        lines.append("")
        lines.append("## 支出明细")
        if monthExpenses.isEmpty {
            lines.append("本月暂无交易记录")
        } else {
            lines.append("| 日期 | 分类 | 金额 | 备注 |")
            lines.append("| --- | --- | --- | --- |")
            for item in monthExpenses {
                let noteText = item.note.replacingOccurrences(of: "|", with: "｜")
                lines.append("| \(item.dateKey) | \(item.category) | ¥\(money(item.amount)) | \(noteText) |")
            }
        }
        lines.append("")
        lines.append("## 分类统计")
        if categoryMap.isEmpty {
            lines.append("暂无分类统计")
        } else {
            for (category, amount) in categoryMap {
                lines.append("- **\(category)**：¥\(money(amount))")
            }
        }
        lines.append("")
        lines.append("## 月度分析")
        lines.append("- **日均支出**：\(monthExpenses.isEmpty ? "0" : String(format: "%.2f", (fixed + flexible) / Double(daysInMonth(year: year, month: month))))")
        lines.append("- **储蓄率**：\(String(format: "%.1f%%", savingsRate))")
        lines.append("- **收支状况**：\(balance >= 0 ? "收支平衡" : "收支赤字")")
        lines.append("")
        lines.append("## 改进建议")
        if savingsRate < 10 && income > 0 {
            lines.append("- 储蓄率较低，建议制定预算计划。")
        }
        if categoryMap.first(where: { $0.key == "娱乐" })?.value ?? 0 > income * 0.15 {
            lines.append("- 娱乐支出占比较高，建议适当控制。")
        }
        if categoryMap.first(where: { $0.key == "购物" })?.value ?? 0 > income * 0.2 {
            lines.append("- 购物支出占比较高，建议理性消费。")
        }
        if lines.filter({ $0.hasPrefix("- 建议") || $0.hasPrefix("- 储蓄率") }).isEmpty {
            lines.append("- 当前收支状况健康，继续保持。")
        }
        lines.append("")
        lines.append("---")
        lines.append("*本报告由打工人小账本自动生成*")

        let title = "月度账单报告 - \(year)年\(month)月"
        let content = note + lines.joined(separator: "\n")
        return GeneratedReport(title: title, year: year, month: month,
                               content: content, createdAt: Date())
    }

    private static func money(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func daysInMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents(year: year, month: month + 1, day: 0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = cal.date(from: comps) else { return 30 }
        return cal.component(.day, from: date)
    }
}

enum ReportError: LocalizedError {
    case invalidMonth
    var errorDescription: String? { "报告月份无效" }
}

private extension DateFormatter {
    static let cn: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f
    }()
}
