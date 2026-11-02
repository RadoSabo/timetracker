import Foundation

/// "Work performed" for the Excel Export: Claude rewrites each day's evidence (tasks, prompts, windows, commits) into
/// 1–3 short phrases a non-technical client understands. Falls back to the task names when Claude is unavailable.
enum WorkPerformed {
    static let instructions = """
    You fill the "Work performed" column of a contractor's timesheet that a non-technical client will read to see what
    their developer did each day. For every row below write ONE line of 1 to 3 short phrases separated by "; ".

    RULES
    - Plain English a business owner understands: name the feature, screen, document or outcome, not the technique.
      Good: "Worker list import", "Login and password reset", "Contract screen filters", "Weekly project meeting",
      "Hosting and DNS migration plan". Bad: "Rails eager loading optimization", "TanStack Query refactor", "PR #70".
    - Never mention tools, libraries, AI assistants, PR or issue numbers, branch names, file names or code terms.
    - Translate any Slovak into English. Keep the evidence's concrete nouns (worker, employer, contract, invoice…).
    - Order by importance (most time first). Merge related items; drop trivia, admin and browsing.
    - At most about 90 characters per line. Rows with little evidence still get a short honest line
      (e.g. "Project maintenance and small fixes"); never leave a row empty, never invent features not in the evidence.

    Answer with ONLY a JSON array, no prose: [{"day": "YYYY-MM-DD", "project": "<exact project name>", "work": "<line>"}]
    """

    static func input(_ lines: [Report.XlsxLine], store: Store = .shared) -> String {
        var s = ""
        for l in lines {
            let d = Day.interval(l.day)
            let tasks = store.tasks(day: l.day).filter { $0.projectId == l.projectId && $0.name != "General" }
            s += "\n## \(l.day) · \(l.project) · \(hm(l.hours * 3600))\n"
            for t in tasks.sorted(by: { $0.totalSeconds > $1.totalSeconds }) {
                s += "- task \"\(t.name)\" (\(hm(t.totalSeconds)))\n"
                if let sid = t.sessionId {
                    for p in store.prompts(session: sid).filter({ $0.ts >= d.start && $0.ts < d.end }).prefix(6) { s += "  > \(oneLine(p.text, 200))\n" }
                }
            }
            var windows: [String: Seconds] = [:]
            for a in store.activities(day: l.day) where a.projectId == l.projectId { windows[a.app + ": " + a.title, default: 0] += a.interval.duration }
            for (k, v) in windows.filter({ $0.value >= 120 }).sorted(by: { $0.value > $1.value }).prefix(8) { s += "- window \(hm(v)) \(oneLine(k, 150))\n" }
            if let path = store.project(l.projectId)?.path {
                for c in Git.commits(in: path, during: d).prefix(12) { s += "- commit \(oneLine(c.subject, 120))\n" }
            }
        }
        return s
    }

    static func parse(_ text: String) -> [String: String] {
        guard let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"),
              let items = try? JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [[String: Any]] else { return [:] }
        var out: [String: String] = [:]
        for i in items {
            if let day = i["day"] as? String, let project = i["project"] as? String, let work = i["work"] as? String, !work.isEmpty {
                out[key(day, project)] = work
            }
        }
        return out
    }

    /// Lines with their work rewritten from `input` (built on the main thread, this may run in the background);
    /// a line Claude skipped keeps its task names.
    static func rewrite(_ lines: [Report.XlsxLine], input: String) throws -> [Report.XlsxLine] {
        guard !lines.isEmpty else { return lines }
        let text = try DaySummary.runClaude(prompt: instructions + "\n" + input)
        let work = parse(text)
        Log.write("export", "work performed: \(work.count)/\(lines.count) rows rewritten by claude")
        return lines.map { var l = $0; l.work = work[key(l.day, l.project)] ?? l.work; return l }
    }

    private static func key(_ day: String, _ project: String) -> String { day + "|" + project.lowercased() }
    private static func oneLine(_ s: String, _ max: Int) -> String { String(s.replacingOccurrences(of: "\n", with: " ").prefix(max)) }
}
