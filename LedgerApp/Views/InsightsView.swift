import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExpenseRecord.dateKey, order: .reverse) private var expenses: [ExpenseRecord]
    @Query private var summaries: [MonthlySummaryRecord]
    @Query private var profiles: [LedgerProfile]
    @Query private var freedoms: [FreedomPlan]

    @State private var commuteReduction = 20.0
    @State private var overtimeReduction = 2.0
    @State private var salaryIncrease = 10.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("有趣发现").font(.largeTitle.bold())
                    Text("少一点抽象焦虑，多一点可以动手调整的变量。")
                        .foregroundStyle(.secondary)
                }
                if let profile = profiles.first {
                    unpaidInsights(profile)
                    scenarioForm(profile)
                    ranking
                }
            }
            .padding()
        }
    }

    private func unpaidInsights(_ profile: LedgerProfile) -> some View {
        let hourly = LedgerMath.hourlyProfile(profile: profile)
        let monthTotal = expenses
            .filter { $0.dateKey.hasPrefix(DateSupport.localMonthKey()) }
            .reduce(0.0) { $0 + $1.amount }
        let commute = hourly.monthlyCommuteHours
        let overtime = hourly.monthlyOvertimeHours
        let unpaid = ((commute + overtime) * 10).rounded() / 10
        return HStack {
            KPIBox(label: "本月白干时间",
                   value: String(format: "%.1f 小时", unpaid))
            KPIBox(label: "通勤+加班价值",
                   value: String(format: "%.1f / %.1f 小时", commute, overtime))
            KPIBox(label: "本月支出折算",
                   value: hourly.realHourly.map {
                       String(format: "%.1f 个工作日", monthTotal / $0 / 8)
                   } ?? "待设置")
            Spacer()
        }
    }

    private func scenarioForm(_ profile: LedgerProfile) -> some View {
        let hourly = LedgerMath.hourlyProfile(profile: profile)
        let (avg, _, _) = LedgerMath.recentCompleteMonths(summaries)
        let freedom = freedoms.first
        let forecast = LedgerMath.freedomForecast(currentSaved: freedom?.currentSaved ?? 0,
                                                  targetAmount: freedom?.targetAmount ?? 0,
                                                  averageMonthlySavings: avg)
        let result = LedgerMath.simulateScenarios(
            profile: profile,
            realHourly: hourly.realHourly,
            remainingAmount: forecast.remainingAmount,
            averageMonthlySavings: avg,
            commuteReductionPercent: commuteReduction,
            overtimeReductionHours: overtimeReduction,
            salaryIncreasePercent: salaryIncrease)

        return VStack(alignment: .leading, spacing: 14) {
            Text("三情景模拟").font(.headline)
            LabeledContent("通勤减少比例") {
                Slider(value: $commuteReduction, in: 0...100, step: 5)
                Text("\(Int(commuteReduction))%").frame(width: 45)
            }
            LabeledContent("每周少加班小时") {
                Slider(value: $overtimeReduction,
                       in: 0...20, step: 0.5)
                Text(String(format: "%.1f", overtimeReduction)).frame(width: 45)
            }
            LabeledContent("涨薪比例") {
                Slider(value: $salaryIncrease, in: 0...300, step: 5)
                Text("\(Int(salaryIncrease))%").frame(width: 45)
            }
            ForEach(result.scenarios, id: \.id) { scenario in
                HStack {
                    Text(scenarioLabel(scenario.id)).bold()
                    Text("现金增益 \(scenario.monthlyCashGain.money)")
                    Text("时间节省 \(String(format: "%.1f h", scenario.monthlyTimeSaved))")
                    Text("自由等效 \(scenario.freedomEquivalentGain.money)")
                    Text(scenario.freedomProjectedMonths.map { "预计 \($0) 个月" } ?? "不可预测")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor)))
            }
        }
        .cardBackground()
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("存款月份排行").font(.headline)
            let ranked = summaries
                .map { (month: $0.monthKey, balance: $0.balance) }
                .sorted { $0.balance > $1.balance }
            if ranked.isEmpty {
                Text("补充月度总结后显示").foregroundStyle(.secondary)
            } else {
                ForEach(Array(ranked.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1). \(DateSupport.displayMonth(item.month))")
                        Spacer()
                        Text(item.balance.money)
                            .foregroundStyle(item.balance >= 0 ? .green : .red)
                    }
                    .font(.callout)
                }
            }
        }
        .cardBackground()
    }

    private func scenarioLabel(_ id: String) -> String {
        switch id {
        case "commute": return "通勤"
        case "overtime": return "加班"
        case "salary": return "涨薪"
        default: return id
        }
    }
}
