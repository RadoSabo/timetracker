import Foundation

func now() -> Seconds { Date().timeIntervalSince1970 }

/// Day keys ("yyyy-MM-dd", local time) and the intervals they cover.
enum Day {
    private static let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
    static func key(_ date: Date) -> String { fmt.string(from: date) }
    static func key(_ ts: Seconds) -> String { key(Date(timeIntervalSince1970: ts)) }
    static func date(_ key: String) -> Date { fmt.date(from: key) ?? Date() }
    static func interval(_ key: String) -> Interval {
        let s = Calendar.current.startOfDay(for: date(key))
        let e = Calendar.current.date(byAdding: .day, value: 1, to: s)!
        return Interval(start: s.timeIntervalSince1970, end: e.timeIntervalSince1970)
    }
    /// "8:00" or "08:00" on the given day → timestamp; nil when unparsable.
    static func time(_ key: String, _ hhmm: String) -> Seconds? {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, (0..<24).contains(p[0]), (0..<60).contains(p[1]) else { return nil }
        return interval(key).start + Double(p[0] * 3600 + p[1] * 60)
    }
    static func keys(from: Date, to: Date) -> [String] {
        var out: [String] = []
        var d = Calendar.current.startOfDay(for: from)
        let end = Calendar.current.startOfDay(for: to)
        while d <= end { out.append(key(d)); d = Calendar.current.date(byAdding: .day, value: 1, to: d)! }
        return out
    }
    static func weekStart(_ d: Date) -> Date {
        var cal = Calendar.current; cal.firstWeekday = 2
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d))!
    }
}

enum Format {
    private static let clockFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    /// "1:05" style hours:minutes.
    static func hm(_ seconds: Seconds) -> String {
        let m = Int((seconds / 60).rounded())
        return String(format: "%d:%02d", m / 60, m % 60)
    }
    static func hours(_ seconds: Seconds) -> String { String(format: "%.2f h", seconds / 3600) }
    static func clock(_ ts: Seconds) -> String { clockFmt.string(from: Date(timeIntervalSince1970: ts)) }
    static func euro(_ amount: Double, decimals: Int = 0) -> String { String(format: "%.\(decimals)f €", amount) }
    static func date(_ d: Date, _ pattern: String) -> String { let f = DateFormatter(); f.dateFormat = pattern; return f.string(from: d) }
}

func hm(_ seconds: Seconds) -> String { Format.hm(seconds) }
func hours(_ seconds: Seconds) -> String { Format.hours(seconds) }
func clock(_ ts: Seconds) -> String { Format.clock(ts) }
