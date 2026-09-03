import SwiftUI
import SwiftData

struct HourlyView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [LedgerProfile]

    private var profile: LedgerProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("真实时薪").font(.largeTitle.bold())
                    Text("把通勤、加班和工作成本算进去后，一小时真正换来多少。")
                        .foregroundStyle(.secondary)
                }
                if let profile {
                    results(profile)
                    form(profile)
                } else {
                    Text("正在准备参数…")
                }
            }
            .padding()
        }
    }

    private func results(_ profile: LedgerProfile) -> some View {
        let breakdown = LedgerMath.hourlyProfile(profile: profile)
        return HStack {
            KPIBox(label: "名义时薪", value: breakdown.nominalHourly?.money ?? "待设置")
            KPIBox(label: "真实时薪", value: breakdown.realHourly?.money ?? "待设置")
            KPIBox(label: "差值方向",
                   value: breakdown.gapDirection == "lower" ? "实际更低" :
                          breakdown.gapDirection == "higher" ? "实际更高" :
                          breakdown.gapDirection == "equal" ? "基本持平" : "待设置")
            KPIBox(label: "每年投入时间",
                   value: String(format: "%.1f 小时", breakdown.annualInvestedHours))
        }
    }

    private func form(_ profile: LedgerProfile) -> some View {
        Form {
            Section("参数") {
                LabeledContent("月薪") {
                    TextField("", value: Binding(
                        get: { profile.monthlySalary },
                        set: { profile.monthlySalary = max(0, $0); save() }),
                    format: .number)
                    .multilineTextAlignment(.trailing)
                }
                LabeledContent("发薪月数") {
                    TextField("", value: Binding(
                        get: { profile.payMonths },
                        set: { profile.payMonths = max(0, $0); save() }),
                    format: .number)
                    .multilineTextAlignment(.trailing)
                }
                LabeledContent("每月工作成本") {
                    TextField("", value: Binding(
                        get: { profile.monthlyWorkCost },
                        set: { profile.monthlyWorkCost = max(0, $0); save() }),
                    format: .number)
                    .multilineTextAlignment(.trailing)
                }
                LabeledContent("每天办公小时") {
                    TextField("", value: Binding(
                        get: { profile.dailyOfficeHours },
                        set: { profile.dailyOfficeHours = max(0, $0); save() }),
                    format: .number)
                    .multilineTextAlignment(.trailing)
                }
                LabeledContent("单程通勤分钟") {
                    TextField("", value: Binding(
                        get: { profile.oneWayCommuteMinutes },
                        set: { profile.oneWayCommuteMinutes = max(0, $0); save() }),
                    format: .number)
                    .multilineTextAlignment(.trailing)
                }
                LabeledContent("每周加班小时") {
                    TextField("", value: Binding(
                        get: { profile.weeklyOvertimeHours },
                        set: { profile.weeklyOvertimeHours = max(0, $0); save() }),
                    format: .number)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func save() {
        try? context.save()
    }
}
