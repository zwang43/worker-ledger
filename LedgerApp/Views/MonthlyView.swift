import SwiftUI
import SwiftData

struct MonthlyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MonthlySummaryRecord.monthKey, order: .reverse)
    private var summaries: [MonthlySummaryRecord]
    @State private var editing: MonthlySummaryRecord?
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if summaries.isEmpty {
                EmptyHint(text: "还没有月度总结，填上收入与固定/弹性支出后可计算结余。")
            } else {
                List {
                    ForEach(summaries) { item in
                        SummaryRow(item: item) {
                            editing = item
                            showEditor = true
                        } delete: {
                            LedgerActions.delete(item, context: context)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showEditor) {
            SummaryEditor(summary: editing) { month, income, fixed, flexible in
                try? LedgerActions.upsertSummary(context: context,
                                                 monthKey: month,
                                                 income: income,
                                                 fixed: fixed,
                                                 flexible: flexible,
                                                 existing: editing)
                showEditor = false
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text("月度总结").font(.largeTitle.bold())
                    Text("结余不单独保存，每次都由收入减去两类支出现场计算。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editing = nil
                    showEditor = true
                } label: { Label("填写本月账页", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }
            if let average = averageText {
                Text(average).foregroundStyle(.secondary)
            }
        }
    }

    private var averageText: String? {
        let current = DateSupport.localMonthKey()
        let recent = summaries
            .filter { $0.monthKey < current }
            .sorted { $0.monthKey < $1.monthKey }
            .suffix(6)
        let balances = recent.map(\.balance)
        guard !balances.isEmpty else { return nil }
        let avg = balances.reduce(0, +) / Double(balances.count)
        return "最近 6 个完整月平均结余：\(avg.money)"
    }
}

private struct SummaryRow: View {
    let item: MonthlySummaryRecord
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(DateSupport.displayMonth(item.monthKey)).font(.headline)
                Text("收入 \(item.income.money) · 固定 \(item.fixed.money) · 弹性 \(item.flexible.money)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.balance.money)
                .foregroundStyle(item.balance >= 0 ? .green : .red)
                .bold()
            Button("编辑", action: edit)
            Button("删除", role: .destructive, action: delete)
        }
    }
}

private struct SummaryEditor: View {
    @Environment(\.dismiss) private var dismiss
    let summary: MonthlySummaryRecord?
    let onSave: (String, Double, Double, Double) -> Void

    @State private var monthKey: String
    @State private var income = ""
    @State private var fixed = ""
    @State private var flexible = ""

    init(summary: MonthlySummaryRecord?,
         onSave: @escaping (String, Double, Double, Double) -> Void) {
        self.summary = summary
        self.onSave = onSave
        _monthKey = State(initialValue: summary?.monthKey ?? DateSupport.localMonthKey())
        _income = State(initialValue: summary.map { String(format: "%.2f", $0.income) } ?? "")
        _fixed = State(initialValue: summary.map { String(format: "%.2f", $0.fixed) } ?? "")
        _flexible = State(initialValue: summary.map { String(format: "%.2f", $0.flexible) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(summary == nil ? "填写本月账页" : "编辑月度总结")
                .font(.title2.bold())
            Picker("月份", selection: $monthKey) {
                ForEach(recentMonths(), id: \.self) { Text(DateSupport.displayMonth($0)).tag($0) }
            }
            TextField("总收入", text: $income)
            TextField("固定支出", text: $fixed)
            TextField("弹性支出", text: $flexible)
            if let balance = computedBalance {
                Text("自动结余：\(balance.money)")
                    .foregroundStyle(balance >= 0 ? .green : .red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    guard let a = Double(income), let b = Double(fixed),
                          let c = Double(flexible) else { return }
                    onSave(monthKey, max(0, a), max(0, b), max(0, c))
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 380)
    }

    private var computedBalance: Double? {
        guard let a = Double(income), let b = Double(fixed), let c = Double(flexible) else { return nil }
        return a - b - c
    }

    private func recentMonths() -> [String] {
        let current = Date()
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return (0...11).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: current)
                .map(formatter.string(from:))
        }.reversed()
    }
}
