import Foundation

/// A gap in a project's day too long to close silently and too short to be the end of work; billed only if the user says so.
struct Break: Identifiable, Hashable {
    var projectId: Int64
    var interval: Interval
    var billable: Bool
    var id: String { "\(projectId)-\(interval.start)" }
}

/// Project Time shaping: short gaps closed, Breaks offered, Day Start stretched.
extension Store {
    /// Project Time of every project with tasks that day.
    func projectTime(day: String, tasks: [TaskItem]? = nil) -> [Int64: [Interval]] {
        let ts = tasks ?? self.tasks(day: day)
        return Dictionary(uniqueKeysWithValues: Set(ts.map(\.projectId)).map { ($0, projectIntervals($0, day: day, tasks: ts)) })
    }

    /// Measured intervals of the project with short gaps closed, the first one stretched to Day Start, plus billed Breaks.
    func projectIntervals(_ pid: Int64, day: String, tasks: [TaskItem]) -> [Interval] {
        var base = tasks.filter { $0.projectId == pid }.flatMap(\.allIntervals).filled(maxGap: Settings.fillGapSeconds)
        if let s = dayStart(pid, day: day), !base.isEmpty, s < base[0].start { base[0].start = s }
        return (base + breaks(pid, base, others: otherWork(pid, tasks)).filter(\.billable).map(\.interval)).union()
    }

    /// One Break per pause, offered to the project worked on right before it (every project idle then has the same gap).
    func breaks(day: String, tasks: [TaskItem]) -> [Break] {
        let all = Set(tasks.map(\.projectId)).sorted().flatMap { pid in
            breaks(pid, tasks.filter { $0.projectId == pid }.flatMap(\.allIntervals).filled(maxGap: Settings.fillGapSeconds), others: otherWork(pid, tasks))
        }
        let lastBefore = { (b: Break) in tasks.filter { $0.projectId == b.projectId }.flatMap(\.allIntervals).map(\.end).filter { $0 <= b.interval.start }.max() ?? 0 }
        return Dictionary(grouping: all, by: \.interval).values.compactMap { $0.max { lastBefore($0) < lastBefore($1) } }
            .sorted { $0.interval.start < $1.interval.start }
    }
    private func otherWork(_ pid: Int64, _ tasks: [TaskItem]) -> [Interval] {
        tasks.filter { $0.projectId != pid }.flatMap(\.allIntervals).union()
    }
    /// A Break is time with no work on any project: a gap in this project minus other projects' work, still 30+ minutes.
    // ponytail: a break is keyed by its start; if new activity shifts the gap, the billing choice is forgotten.
    private func breaks(_ pid: Int64, _ base: [Interval], others: [Interval]) -> [Break] {
        let billed = Set(db.query("SELECT start FROM pause WHERE project_id=? AND billable=1", [pid]).map { $0.dbl("start") })
        return base.gaps(Settings.fillGapSeconds..<Settings.breakMaxSeconds)
            .flatMap { [$0].subtracting(others) }
            .filter { $0.duration >= Settings.fillGapSeconds }
            .map { Break(projectId: pid, interval: $0, billable: billed.contains($0.start)) }
    }
    func setBreakBillable(_ b: Break, _ billable: Bool) {
        db.run("INSERT OR REPLACE INTO pause(project_id,start,billable) VALUES(?,?,?)", [b.projectId, b.interval.start, billable ? 1 : 0])
        Log.write("break", "project #\(b.projectId) \(clock(b.interval.start))–\(clock(b.interval.end)) billable=\(billable)")
        refresh()
    }

    func dayStart(_ pid: Int64, day: String) -> Seconds? {
        db.query("SELECT start FROM day_start WHERE project_id=? AND day=?", [pid, day]).first?.dbl("start")
    }
    func setDayStart(_ pid: Int64, day: String, start: Seconds?) {
        if let start { db.run("INSERT OR REPLACE INTO day_start(project_id,day,start) VALUES(?,?,?)", [pid, day, start]) }
        else { db.run("DELETE FROM day_start WHERE project_id=? AND day=?", [pid, day]) }
        Log.write("daystart", "project #\(pid) \(day) start=\(start.map(clock) ?? "cleared")")
        refresh()
    }
}
