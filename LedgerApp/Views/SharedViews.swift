import SwiftUI

struct MoneyText: View {
    let value: Double?
    var font: Font = .body

    var body: some View {
        Text(value.map { "¥" + String(format: "%.2f", $0) } ?? "待设置")
            .font(font)
            .monospacedDigit()
    }
}

struct KPIBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

struct EmptyHint: View {
    let text: String

    var body: some View {
        ContentUnavailableView {
            Label("暂无记录", systemImage: "tray")
        } description: {
            Text(text)
        }
        .padding()
    }
}

extension Double {
    var money: String { "¥" + String(format: "%.2f", self) }
}

extension View {
    func cardBackground() -> some View {
        self.padding()
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor)))
    }
}
