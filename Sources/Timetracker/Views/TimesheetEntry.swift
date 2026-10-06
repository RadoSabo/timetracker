import AppKit

/// What the Timesheet column lays out on the clock: one card per stretch of a task or AI draft (gaps under
/// `segmentGap` closed) and Breaks, sorted by start, so parallel work sits side by side at its real time.
struct TimesheetEntry {
    enum Kind { case task(TaskItem), draft(Draft), pause(Break) }
    var start: Seconds
    var end: Seconds
    /// Worked seconds inside this stretch.
    var length: Seconds
    /// Stretches the task or draft has in total; cards of a split task show the whole total too.
    var parts: Int = 1
    var kind: Kind
    /// Wide cards fit title, time and menu on one row (two rows in all); narrow ones stack duration, title, time and project.
    func minHeight(width: CGFloat) -> CGFloat {
        let title: String
        switch kind {
        case .pause: return width < 200 ? 62 : 46
        case .task(let t): title = t.name
        case .draft(let d): title = d.name
        }
        let titleWidth = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]).width
        return titleWidth + 16 + 5 + (parts > 1 ? 75 : 40) + 22 <= width ? 46 : 80
    }

    static let segmentGap: Seconds = 10 * 60

    /// A pending draft stands in for the task it would replace (its task_id, or same project and name), and tasks only an
    /// earlier summary created are hidden, so the column previews the regenerated timesheet instead of showing both.
    static func build(tasks: [TaskItem], drafts: [Draft], breaks: [Break], fallback: Seconds) -> [TimesheetEntry] {
        let replaced = tasks.filter { t in
            (!drafts.isEmpty && t.fromDraft) || drafts.contains { $0.taskId == t.id || ($0.taskId == nil && $0.projectId == t.projectId && $0.name == t.name) }
        }.map(\.id)
        let t = tasks.filter { !replaced.contains($0.id) }.flatMap { t in
            split(t.allIntervals, kind: .task(t)) ?? [TimesheetEntry(start: fallback + 8 * 3600, end: fallback + 8 * 3600, length: t.totalSeconds, kind: .task(t))]
        }
        let d = drafts.flatMap { split($0.ranges, kind: .draft($0)) ?? [] }
        let b = breaks.map { TimesheetEntry(start: $0.interval.start, end: $0.interval.end, length: $0.interval.duration, kind: .pause($0)) }
        return (t + d + b).sorted { $0.start < $1.start }
    }

    private static func split(_ ivs: [Interval], kind: Kind) -> [TimesheetEntry]? {
        let segs = ivs.filled(maxGap: segmentGap)
        guard !segs.isEmpty else { return nil }
        return segs.map { s in
            TimesheetEntry(start: s.start, end: s.end, length: ivs.compactMap { $0.clipped(to: s) }.union().total, parts: segs.count, kind: kind)
        }
    }
}
