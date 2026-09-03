import Foundation

enum DateSupport {
    static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseISO(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return isoFractional.date(from: value) ?? isoPlain.date(from: value)
    }

    static func isoString(_ date: Date) -> String {
        isoFractional.string(from: date)
    }

    static func localDateKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func localMonthKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    static func dateKey(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func monthKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    static func isValidDateKey(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[1] >= 1, parts[1] <= 12, parts[2] >= 1, parts[2] <= 31 else {
            return false
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = cal.date(from: comps) else { return false }
        let check = cal.dateComponents([.year, .month, .day], from: date)
        return check.year == parts[0] && check.month == parts[1] && check.day == parts[2]
    }

    static func isValidMonthKey(_ value: String) -> Bool {
        guard value.count == 7 else { return false }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        return parts.count == 2 && parts[0] >= 1900 && parts[1] >= 1 && parts[1] <= 12
    }

    /// “上一个已结束自然月”的 YYYY-MM
    static func previousMonthKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: now) else {
            return localMonthKey(now, calendar: calendar)
        }
        return localMonthKey(prev, calendar: calendar)
    }

    static func monthRange(for monthKey: String) -> (start: String, end: String)? {
        let parts = monthKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let (y, m) = (parts[0], parts[1])
        let start = dateKey(year: y, month: m, day: 1)
        let next: (Int, Int)
        if m == 12 { next = (y + 1, 1) } else { next = (y, m + 1) }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = DateComponents(year: next.0, month: next.1, day: 0)
        guard let last = cal.date(from: comps) else { return nil }
        let d = cal.dateComponents([.year, .month, .day], from: last)
        return (start, dateKey(year: d.year ?? y, month: d.month ?? m, day: d.day ?? 28))
    }

    static func monthDiff(from: String, to: String) -> Int? {
        guard isValidMonthKey(from), isValidMonthKey(to) else { return nil }
        let a = from.split(separator: "-").compactMap { Int($0) }
        let b = to.split(separator: "-").compactMap { Int($0) }
        return (b[0] - a[0]) * 12 + (b[1] - a[1])
    }

    static func displayMonth(_ key: String) -> String {
        guard isValidMonthKey(key) else { return key }
        let p = key.split(separator: "-").compactMap { Int($0) }
        return "\(p[0])年\(p[1])月"
    }

    static func displayDate(_ key: String) -> String {
        guard isValidDateKey(key) else { return key }
        let p = key.split(separator: "-").compactMap { Int($0) }
        return "\(p[0])年\(p[1])月\(p[2])日"
    }
}
