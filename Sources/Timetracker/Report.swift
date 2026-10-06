import Foundation

/// Report for one billable Project over a period: days → tasks → hours, rounded per day, priced by Rate.
struct Report {
    struct DayLine { var day: String; var tasks: [TaskItem]; var exactSeconds: Seconds; var roundedSeconds: Seconds }
    var project: Project
    var from: Date
    var to: Date
    var days: [DayLine]
    var totalSeconds: Seconds { days.reduce(0) { $0 + $1.roundedSeconds } }
    var amount: Double { totalSeconds / 3600 * project.rate }

    static func round(_ seconds: Seconds, minutes: Int) -> Seconds {
        guard minutes > 0 else { return seconds }
        let unit = Double(minutes) * 60
        return (seconds / unit).rounded() * unit
    }

    static func build(project: Project, from: Date, to: Date, store: Store = .shared) -> Report {
        let policy = Settings.overlapPolicy
        let rounding = Settings.roundingMinutes
        var lines: [DayLine] = []
        for day in Day.keys(from: from, to: to) {
            let all = store.tasks(day: day)
            let mine = all.filter { $0.projectId == project.id }
            guard !mine.isEmpty else { continue }
            var intervals = store.projectIntervals(project.id, day: day, tasks: all)
            if policy == .exclusive {
                // Exclusive: other billable projects' foreground time wins over our background (Claude/meeting) time.
                let otherBillable = Set(store.billableProjects().map(\.id)).subtracting([project.id])
                let d = Day.interval(day)
                let theirForeground: [Interval] = store.activities(day: day)
                    .filter { $0.projectId.map(otherBillable.contains) == true }
                    .compactMap { $0.interval.clipped(to: d) }
                let ourForeground = store.activities(day: day).filter { $0.projectId == project.id }.compactMap { $0.interval.clipped(to: d) }
                intervals = (intervals.subtracting(theirForeground) + ourForeground).union()
            }
            let exact = intervals.total + mine.reduce(0) { $0 + $1.adjustment }
            lines.append(DayLine(day: day, tasks: mine, exactSeconds: exact, roundedSeconds: Report.round(exact, minutes: rounding)))
        }
        return Report(project: project, from: from, to: to, days: lines)
    }

    var markdown: String {
        var s = "# \(project.name) — \(Day.key(from)) to \(Day.key(to))\n\n"
        for d in days {
            s += "## \(d.day) — \(hours(d.roundedSeconds))\n"
            for t in d.tasks { s += "- \(t.name) (\(hours(t.totalSeconds)))\n" }
            s += "\n"
        }
        s += "**Total: \(hours(totalSeconds)) × \(project.rate) € = \(Format.euro(amount, decimals: 2))**\n"
        return s
    }

    var csv: String {
        var s = "date,task,task_hours,day_hours_rounded,rate,amount\n"
        for d in days {
            for t in d.tasks {
                s += "\(d.day),\"\(t.name.replacingOccurrences(of: "\"", with: "\"\""))\",\(String(format: "%.2f", t.totalSeconds / 3600)),\(String(format: "%.2f", d.roundedSeconds / 3600)),\(project.rate),\(String(format: "%.2f", d.roundedSeconds / 3600 * project.rate))\n"
            }
        }
        s += ",TOTAL,,\(String(format: "%.2f", totalSeconds / 3600)),\(project.rate),\(String(format: "%.2f", amount))\n"
        return s
    }

    /// Prompt + condensed raw data for pasting into Claude.
    func claudePrompt(store: Store = .shared) -> String {
        var s = """
        You are helping a contractor write a timesheet. Below is raw activity data for project "\(project.name)" \
        from \(Day.key(from)) to \(Day.key(to)). Produce a clean report: for each day, a short list of tasks worked on \
        (one line each, merge related items, ignore trivial browsing unless it is clearly part of a task) and the day's \
        hours (\(hours(0)) style, already rounded values are given). Keep it factual and concise. Write it in English.\n\n
        """
        for d in days {
            s += "## \(d.day) — rounded \(hours(d.roundedSeconds)) (exact \(hours(d.exactSeconds)))\n"
            for t in d.tasks {
                s += "### Task: \(t.name) — tracked \(hm(t.trackedSeconds)), manual \(hm(t.manualSeconds))\n"
                if let sid = t.sessionId {
                    let prompts = store.prompts(session: sid)
                    if let sess = store.session(sid), let b = sess.branch { s += "branch: \(b)\n" }
                    let limit = Settings.fullPromptsInExport ? Int.max : 300
                    for p in prompts.prefix(Settings.fullPromptsInExport ? 1000 : 15) {
                        s += "- [\(clock(p.ts))] \(String(p.text.replacingOccurrences(of: "\n", with: " ").prefix(limit)))\n"
                    }
                }
            }
            let acts = store.activities(day: d.day).filter { $0.projectId == project.id }
            var byKey: [String: Seconds] = [:]
            for a in acts {
                let key = a.app + ": " + (a.url.flatMap { URL(string: $0)?.host }.map { "\($0) — " } ?? "") + a.title
                byKey[key, default: 0] += a.interval.duration
            }
            let top = byKey.filter { $0.value >= 120 }.sorted { $0.value > $1.value }.prefix(25)
            if !top.isEmpty {
                s += "Foreground windows:\n"
                for (k, v) in top { s += "- \(hm(v)) \(k)\n" }
            }
            let cmds = store.shellCommands(day: d.day).filter { Git.root(of: $0.cwd) == project.path }
            if !cmds.isEmpty { s += "Shell: " + cmds.prefix(40).map { $0.cmd }.joined(separator: "; ") + "\n" }
            s += "\n"
        }
        return s
    }
}
