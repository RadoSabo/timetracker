import Foundation

/// One day's raw data as plain text, the input for the AI day summary: every window switch, every Claude Code session
/// with its agent runs and prompts, meetings, shell commands, commits. Only consecutive rows of the same window are
/// merged; nothing is grouped or interpreted.
enum DayInput {
    static func build(day: String, store: Store = .shared) -> String {
        let d = Day.interval(day)
        let projects = store.projects()
        let tasks = store.tasks(day: day)
        let name = { (id: Int64?) in id.flatMap { store.project($0)?.name } }
        var s = "Date: \(day)\n\n## Projects\n"
        for p in projects {
            s += "- \(p.name)\(p.billable ? " (billable)" : " (personal)")\(p.keywords.isEmpty ? "" : " keywords: \(p.keywords)")\(p.path.map { " repo: \($0)" } ?? "")\n"
        }

        s += "\n## Claude Code sessions (agent runs = when the agent was working, also while the user was in other windows)\n"
        for t in tasks {
            guard let sid = t.sessionId, let session = store.session(sid) else { continue }
            s += "- session task_id \(t.id) [\(name(t.projectId) ?? "?")] cwd: \(session.cwd)\(session.branch.map { " branch: \($0)" } ?? "")\n"
            s += "  auto label (often wrong): \"\(t.name)\"\n"
            s += "  agent runs: \(ranges(store.runs(session: sid).compactMap { $0.clipped(to: d) }))\n"
            for p in store.prompts(session: sid) where p.ts >= d.start && p.ts < d.end { s += "  > \(time(p.ts)) \(oneLine(p.text, 400))\n" }
        }

        // Tasks that exist only from an earlier summary are left out: the summary regenerates them instead of copying them.
        let other = tasks.filter { $0.sessionId == nil && !$0.fromDraft }
        if !other.isEmpty {
            s += "\n## Other existing tasks (meetings, manual time)\n"
            for t in other { s += "- task_id \(t.id) [\(name(t.projectId) ?? "?")] \"\(t.name)\" time: \(ranges(t.tracked))\n" }
        }

        let meetings = store.db.query("SELECT * FROM meeting WHERE start<? AND COALESCE(end, start)>? ORDER BY start", [d.end, d.start])
        if !meetings.isEmpty {
            s += "\n## Meetings\n"
            for m in meetings { s += "- \(time(m.dbl("start")))–\(m.optDbl("end").map(time) ?? "now") \(oneLine(m.str("title"), 200))\(name(m.optInt("project_id")).map { " [\($0)]" } ?? "")\n" }
        }

        s += "\n## Foreground windows (every switch; [project] = matched by a keyword or rule)\n"
        for a in merged(store.activities(day: day)) {
            let url = a.url.map { " · \(oneLine($0, 200))" } ?? ""
            s += "- \(time(a.interval.start))–\(time(a.interval.end)) \(a.app) · \(oneLine(a.title, 200))\(url)\(name(a.projectId).map { " [\($0)]" } ?? "")\n"
        }

        let cmds = store.shellCommands(day: day)
        if !cmds.isEmpty {
            s += "\n## Shell commands\n"
            for c in cmds { s += "- \(time(c.ts)) \(c.cwd)$ \(oneLine(c.cmd, 200))\n" }
        }

        let commits = projects.compactMap { p in p.path.map { (p.name, Git.commits(in: $0, during: d)) } }.filter { !$0.1.isEmpty }
        if !commits.isEmpty {
            s += "\n## Git commits\n"
            for (name, list) in commits { for c in list { s += "- \(time(c.ts)) [\(name)] \(oneLine(c.subject, 200))\n" } }
        }

        let manual = store.manualEntries(day: day)
        if !manual.isEmpty {
            s += "\n## Manual entries (already final, do not propose them again)\n"
            for m in manual { s += "- \(time(m.interval.start))–\(time(m.interval.end)) [\(name(m.projectId) ?? "?")] \(m.note)\n" }
        }
        return s
    }

    /// Back-to-back rows of the same window (app, title, URL, project) become one row.
    static func merged(_ acts: [Activity]) -> [Activity] {
        var out: [Activity] = []
        for a in acts {
            if let last = out.last, last.app == a.app, last.title == a.title, last.url == a.url, last.projectId == a.projectId,
               a.interval.start - last.interval.end < 5 {
                out[out.count - 1].interval.end = max(last.interval.end, a.interval.end)
            } else { out.append(a) }
        }
        return out
    }

    private static let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f }()
    private static func time(_ ts: Seconds) -> String { fmt.string(from: Date(timeIntervalSince1970: ts)) }
    private static func ranges(_ ivs: [Interval]) -> String {
        ivs.isEmpty ? "none" : ivs.map { "\(time($0.start))–\(time($0.end))" }.joined(separator: ", ")
    }
    private static func oneLine(_ s: String, _ max: Int) -> String {
        String(s.replacingOccurrences(of: "\n", with: " ").prefix(max))
    }
}
