import SwiftUI
import SwiftData
import Charts

struct FreedomView: View {
    @Environment(\.modelContext) private var context
    @Query private var summaries: [MonthlySummaryRecord]
    @Query private var freedoms: [FreedomPlan]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("自由基金").font(.largeTitle.bold())
                    Text("离想做的事，还差多久、差多少。").foregroundStyle(.secondary)
                }
                if let freedom = freedoms.first {
                    overview(freedom)
                    form(freedom)
                    if let points = chartPoints(freedom), points.count >= 2 {
                        chart(points)
                    }
                }
            }
            .padding()
        }
    }

    private func overview(_ freedom: FreedomPlan) -> some View {
        let (avg, _, _) = LedgerMath.recentCompleteMonths(summaries)
        let forecast = LedgerMath.freedomForecast(currentSaved: freedom.currentSaved,
                                                  targetAmount: freedom.targetAmount,
                                                  averageMonthlySavings: avg)
        let safety = LedgerMath.safetyBuffer(currentSaved: freedom.currentSaved,
                                             basicMonthlyCost: freedom.basicMonthlyCost)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                KPIBox(label: "已完成", value: progressText(freedom))
                KPIBox(label: "剩余缺口",
                       value: forecast.achieved ? "已达成" : forecast.remainingAmount.money)
                KPIBox(label: "预计月数",
                       value: forecast.remainingMonths.map(String.init) ?? "待平均转正")
                KPIBox(label: "预计达成",
                       value: forecast.estimatedDate.map(DateSupport.displayDate) ?? "—")
            }
            HStack {
                Text("安全垫")
                if let months = safety.months {
                    Text(String(format: "%.1f 个月", months))
                } else {
                    Text("待设置基本月开销")
                }
                Spacer()
                ForEach(safety.levels, id: \.months) { level in
                    Text("\(level.months) 个月")
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(level.reached
                                                   ? Color.green.opacity(0.2)
                                                   : Color.gray.opacity(0.15)))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    private func form(_ freedom: FreedomPlan) -> some View {
        @Bindable var model = freedom
        return Form {
            Section("目标与现状") {
                LabeledContent("目标金额") { field($model.targetAmount) }
                LabeledContent("当前已攒") { field($model.currentSaved) }
                LabeledContent("基本月开销") { field($model.basicMonthlyCost) }
                LabeledContent("目标月份") {
                    TextField("YYYY-MM", text: Binding(
                        get: { model.targetDate ?? "" },
                        set: { model.targetDate = $0.isEmpty ? nil : $0; save() }))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("起始月份") {
                    TextField("YYYY-MM", text: Binding(
                        get: { model.startMonth ?? "" },
                        set: { model.startMonth = $0.isEmpty ? nil : $0; save() }))
                        .multilineTextAlignment(.trailing)
                }
                TextField("自由理由", text: Binding(
                    get: { model.reason },
                    set: { model.reason = String($0.prefix(300)); save() }),
                    axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .formStyle(.grouped)
    }

    private func field(_ binding: Binding<Double>) -> some View {
        TextField("", value: binding, format: .number)
            .multilineTextAlignment(.trailing)
            .onChange(of: binding.wrappedValue) { _, _ in save() }
    }

    private func progressText(_ freedom: FreedomPlan) -> String {
        guard freedom.targetAmount > 0 else { return "—" }
        return String(format: "%.1f%%", min(1, freedom.currentSaved / freedom.targetAmount) * 100)
    }

    private func chartPoints(_ freedom: FreedomPlan) -> [SavingsPoint]? {
        let filtered = summaries
            .filter { DateSupport.isValidMonthKey($0.monthKey) }
            .sorted { $0.monthKey < $1.monthKey }
        guard !filtered.isEmpty else { return nil }
        let total = filtered.reduce(0.0) { $0 + $1.balance }
        var running = freedom.currentSaved - total
        var points = [SavingsPoint(month: DateSupport.displayMonth(filtered[0].monthKey),
                                   value: running)]
        for (i, item) in filtered.enumerated() {
            running += filtered[i].balance
            points.append(SavingsPoint(month: DateSupport.displayMonth(item.monthKey),
                                       value: running))
        }
        if let target = freedom.targetDate, DateSupport.isValidMonthKey(target) {
            points.append(SavingsPoint(month: "目标 \(DateSupport.displayMonth(target))",
                                       value: freedom.targetAmount))
        }
        return points
    }

    private func chart(_ points: [SavingsPoint]) -> some View {
        Chart(points) { point in
            LineMark(x: .value("月份", point.month),
                     y: .value("金额", point.value))
                .foregroundStyle(Color.accentColor)
        }
        .frame(height: 220)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func save() {
        try? context.save()
    }
}

private struct SavingsPoint: Identifiable {
    let month: String
    let value: Double
    var id: String { month }
}
