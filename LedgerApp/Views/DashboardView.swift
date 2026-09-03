import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExpenseRecord.dateKey, order: .reverse) private var expenses: [ExpenseRecord]
    @Query private var summaries: [MonthlySummaryRecord]
    @Query private var profiles: [LedgerProfile]
    @Query private var freedoms: [FreedomPlan]
    @Query private var settingsList: [LedgerSettings]

    @State private var quickAmount = ""
    @State private var quickCategory = "餐饮"
    @State private var quickNote = ""
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                HStack {
                    KPIBox(label: "今日支出",
                           value: sum(date: DateSupport.localDateKey()).money)
                    KPIBox(label: "本月支出",
                           value: monthTotal.money)
                    KPIBox(label: "真实时薪",
                           value: realHourlyText)
                    KPIBox(label: "自由基金进度",
                           value: progressText)
                }
                quickForm
                recent
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今天也要算清楚").font(.largeTitle.bold())
            Text("不是为了苛责每一笔钱，而是让每一小时更接近你想要的生活。")
                .foregroundStyle(.secondary)
        }
    }

    private var monthTotal: Double {
        let prefix = DateSupport.localMonthKey()
        return expenses.filter { $0.dateKey.hasPrefix(prefix) }
            .reduce(0) { $0 + $1.amount }
    }

    private var realHourlyText: String {
        guard let profile = profiles.first,
              let hourly = LedgerMath.hourlyProfile(profile: profile).realHourly else {
            return "待设置"
        }
        return hourly.money
    }

    private var progressText: String {
        guard let freedom = freedoms.first, freedom.targetAmount > 0 else { return "—" }
        let p = freedom.currentSaved / freedom.targetAmount
        return String(format: "%.1f%%", p * 100)
    }

    private var quickForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("现在记一笔").font(.headline)
            HStack {
                TextField("金额", text: $quickAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                Picker("分类", selection: $quickCategory) {
                    ForEach(LedgerConstants.pageCategories, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .frame(width: 150)
                TextField("备注（可选）", text: $quickNote)
                    .textFieldStyle(.roundedBorder)
                Button("记一笔") { saveQuick() }
                    .buttonStyle(.borderedProminent)
            }
            if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
        }
        .cardBackground()
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近记录").font(.headline)
            if expenses.isEmpty {
                EmptyHint(text: "还没有支出记录，先记下第一笔吧。")
            } else {
                ForEach(Array(expenses.prefix(4))) { item in
                    HStack {
                        Text(item.category)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        Text(item.note.isEmpty ? item.category : item.note).lineLimit(1)
                        Spacer()
                        Text(item.dateKey).foregroundStyle(.secondary)
                        Text(item.amount.money).bold()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor)))
                }
            }
        }
        .cardBackground()
    }

    private func sum(date: String) -> Double {
        expenses.filter { $0.dateKey == date }.reduce(0) { $0 + $1.amount }
    }

    private func saveQuick() {
        guard let amount = Double(quickAmount), amount > 0 else {
            message = "请输入有效金额"
            return
        }
        do {
            try LedgerActions.insertExpense(context: context,
                                            dateKey: DateSupport.localDateKey(),
                                            amount: amount,
                                            category: quickCategory,
                                            note: quickNote)
            quickAmount = ""
            quickNote = ""
            message = "记好啦，这笔时间已收进账本。"
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
    }
}
