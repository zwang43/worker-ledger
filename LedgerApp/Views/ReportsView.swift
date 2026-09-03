import SwiftUI
import SwiftData

struct ReportsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MonthlyReportRecord.createdAt, order: .reverse)
    private var reports: [MonthlyReportRecord]
    @Query private var expenses: [ExpenseRecord]
    @Query private var summaries: [MonthlySummaryRecord]

    @State private var selectedReport: MonthlyReportRecord?
    @State private var manualYear = MonthlyReportService.defaultMonth().year
    @State private var manualMonth = MonthlyReportService.defaultMonth().month
    @State private var message: String?

    var body: some View {
        NavigationSplitView {
            List(reports, selection: $selectedReport) { report in
                VStack(alignment: .leading) {
                    Text(report.title).font(.headline)
                    Text("生成于 \(report.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .tag(report)
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                generatePanel
                if let selectedReport {
                    Divider()
                    Text(selectedReport.content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    EmptyHint(text: "从左侧选择历史报告，或先生成一份。")
                }
            }
            .padding()
        }
    }

    private var generatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("生成月度账单报告").font(.headline)
            HStack {
                Picker("年", selection: $manualYear) {
                    ForEach(2020...2035, id: \.self) { Text("\($0)年").tag($0) }
                }
                .frame(width: 110)
                Picker("月", selection: $manualMonth) {
                    ForEach(1...12, id: \.self) { Text("\($0)月").tag($0) }
                }
                .frame(width: 90)
                Button("生成默认（上一个月）") {
                    let d = MonthlyReportService.defaultMonth()
                    manualYear = d.year
                    manualMonth = d.month
                }
                Spacer()
                Button("生成并保存") { generate() }
                    .buttonStyle(.borderedProminent)
            }
            if let message {
                Text(message).foregroundStyle(.secondary)
            }
        }
        .cardBackground()
    }

    private func generate() {
        do {
            let summary = summaries.first { $0.monthKey == DateSupport.monthKey(year: manualYear, month: manualMonth) }
            let report = try MonthlyReportService.generate(year: manualYear,
                                                           month: manualMonth,
                                                           expenses: expenses,
                                                           summary: summary)
            if let existing = reports.first(where: {
                $0.year == manualYear && $0.month == manualMonth
            }) {
                existing.content = report.content
                existing.title = report.title
                existing.createdAt = report.createdAt
            } else {
                let record = MonthlyReportRecord(id: "monthly_report_\(manualYear)_\(manualMonth)",
                                                 title: report.title,
                                                 year: report.year,
                                                 month: report.month,
                                                 content: report.content,
                                                 createdAt: report.createdAt)
                context.insert(record)
            }
            try context.save()
            selectedReport = reports.first {
                $0.year == manualYear && $0.month == manualMonth
            }
            message = "已生成 \(manualYear)年\(manualMonth)月报告"
        } catch {
            message = error.localizedDescription
        }
    }
}
