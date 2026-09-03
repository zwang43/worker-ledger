import SwiftUI
import SwiftData

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var bridge: AIBridgeService
    @Query(sort: \ExpenseRecord.dateKey, order: .reverse) private var expenses: [ExpenseRecord]
    @Query private var profiles: [LedgerProfile]

    @State private var showEditor = false
    @State private var editing: ExpenseRecord?
    @State private var aiText = ""
    @State private var aiRecords: [AIRecord] = []
    @State private var aiError: String?
    @State private var aiBusy = false
    @State private var visibleLimit = 30

    private var todayTotal: Double {
        expenses.filter { $0.dateKey == DateSupport.localDateKey() }
            .reduce(0) { $0 + $1.amount }
    }
    private var monthTotal: Double {
        let key = DateSupport.localMonthKey()
        return expenses.filter { $0.dateKey.hasPrefix(key) }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    KPIBox(label: "今日支出", value: todayTotal.money)
                    KPIBox(label: "本月支出", value: monthTotal.money)
                    KPIBox(label: "本月等价工时",
                           value: equivalentText(monthTotal))
                    Spacer()
                }
                HStack {
                    Text("最近记录").font(.title2.bold())
                    Spacer()
                    Button {
                        editing = nil
                        showEditor = true
                    } label: {
                        Label("记一笔", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                aiPanel
                if expenses.isEmpty {
                    EmptyHint(text: "还没有支出记录。")
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(expenses.prefix(visibleLimit)) { item in
                            ExpenseRow(item: item,
                                       equivalent: equivalentText(item.amount)) {
                                editing = item
                                showEditor = true
                            } delete: {
                                LedgerActions.delete(item, context: context)
                            }
                        }
                        if expenses.count > visibleLimit {
                            Button("加载更多（\(min(30, expenses.count - visibleLimit)) 条）") {
                                visibleLimit += 30
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showEditor) {
            ExpenseEditor(expense: editing) { dateKey, amount, category, note in
                save(dateKey: dateKey, amount: amount, category: category, note: note)
                showEditor = false
            }
        }
    }

    private var aiPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("AI 记账", systemImage: "sparkles").font(.headline)
                Spacer()
                if bridge.health?.online == true {
                    Text("oMLX 在线").font(.caption).foregroundStyle(.green)
                } else {
                    Text(bridge.health == nil ? "桥接未就绪" : "oMLX 离线")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            HStack {
                TextField("例如：今天买咖啡花了25，微信支付", text: $aiText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await parseAI() } }
                Button(aiBusy ? "思考中…" : "解析") {
                    Task { await parseAI() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(aiBusy || aiText.isEmpty)
            }
            if let aiError {
                Text(aiError).font(.callout).foregroundStyle(.red)
            }
            if !aiRecords.isEmpty {
                ForEach(aiRecords) { record in
                    HStack {
                        Text(record.category ?? "其他")
                        Text(record.description ?? "")
                        Spacer()
                        Text(record.amount.map { $0.money } ?? "")
                    }
                    .font(.callout)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor)))
                }
                HStack {
                    Spacer()
                    Button("确认记入 \(aiRecords.count) 笔") {
                        confirmAI()
                    }.buttonStyle(.borderedProminent)
                    Button("清空") { aiRecords = []; aiError = nil }
                }
            }
        }
        .cardBackground()
    }

    private func parseAI() async {
        aiError = nil
        aiBusy = true
        defer { aiBusy = false }
        do {
            let response = try await bridge.parse(text: aiText)
            if !response.ok {
                aiError = response.error ?? "解析失败，请重试"
                aiRecords = []
                return
            }
            aiRecords = (response.records ?? []).filter {
                $0.action == "add" && ($0.amount ?? 0) > 0 && ($0.category ?? "") != "收入"
            }
            if aiRecords.isEmpty {
                aiError = "没听懂这笔，换个说法试试（例如「今天买咖啡花了25」）。"
            } else {
                aiText = ""
            }
        } catch {
            aiError = error.localizedDescription
            aiRecords = []
        }
    }

    private func confirmAI() {
        let adds = aiRecords
        for record in adds {
            _ = try? LedgerActions.insertExpense(
                context: context,
                dateKey: validDate(record.date) ? record.date! : DateSupport.localDateKey(),
                amount: record.amount ?? 0,
                category: LedgerConstants.cleanCategory(record.category),
                note: record.description ?? "")
        }
        aiRecords = []
        aiText = ""
        aiError = "已记入 \(adds.count) 笔"
    }

    private func validDate(_ value: String?) -> Bool {
        guard let value else { return false }
        return DateSupport.isValidDateKey(value)
    }

    private func equivalentText(_ amount: Double) -> String {
        guard let profile = profiles.first,
              let hourly = LedgerMath.hourlyProfile(profile: profile).realHourly,
              hourly > 0 else { return "待设置时薪" }
        let hours = amount / hourly
        if hours < 1 {
            return String(format: "%.0f 分钟", hours * 60)
        }
        return String(format: "%.2f 小时", hours)
    }

    private func save(dateKey: String, amount: Double, category: String, note: String) {
        do {
            if let editing {
                editing.dateKey = dateKey
                editing.amount = amount
                editing.category = category
                editing.note = note
                editing.isSample = false
                try context.save()
            } else {
                _ = try LedgerActions.insertExpense(context: context,
                                                    dateKey: dateKey,
                                                    amount: amount,
                                                    category: category,
                                                    note: note)
            }
        } catch {
            // Editor sheet already closed; acceptable for v1 with validated input.
        }
    }
}

private struct ExpenseRow: View {
    let item: ExpenseRecord
    let equivalent: String
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(item.category)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading) {
                Text(item.note.isEmpty ? item.category : item.note)
                Text("\(item.dateKey) · \(equivalent)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.amount.money).bold()
            Button("编辑", action: edit)
            Button("删除", role: .destructive, action: delete)
        }
    }
}

private struct ExpenseEditor: View {
    @Environment(\.dismiss) private var dismiss
    let expense: ExpenseRecord?
    let onSave: (String, Double, String, String) -> Void

    @State private var dateKey: String
    @State private var amount = ""
    @State private var category: String
    @State private var note = ""

    init(expense: ExpenseRecord?, onSave: @escaping (String, Double, String, String) -> Void) {
        self.expense = expense
        self.onSave = onSave
        _dateKey = State(initialValue: expense?.dateKey ?? DateSupport.localDateKey())
        _amount = State(initialValue: expense.map { String(format: "%.2f", $0.amount) } ?? "")
        _category = State(initialValue: expense?.category ?? "餐饮")
        _note = State(initialValue: expense?.note ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(expense == nil ? "记一笔" : "编辑记录").font(.title2.bold())
            DatePicker("日期", selection: Binding(
                get: { DateSupport.parseISO(dateKey + "T00:00:00Z") ?? Date() },
                set: { dateKey = DateSupport.localDateKey($0) }),
                       displayedComponents: .date)
            TextField("金额", text: $amount)
            Picker("分类", selection: $category) {
                ForEach(LedgerConstants.validCategories, id: \.self) { Text($0).tag($0) }
            }
            TextField("备注", text: $note, axis: .vertical)
                .lineLimit(2...5)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    guard let value = Double(amount), value > 0 else { return }
                    onSave(dateKey, value, category, note)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
