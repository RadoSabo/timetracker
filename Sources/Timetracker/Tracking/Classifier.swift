import Foundation

/// Project classification: every 20 minutes, today's windows and Claude Sessions without a certain signal go to
/// `claude -p` with the projects and the user's Corrections. Each gets a Project, or stays without one and is marked as
/// work ("ai unknown") or personal ("ai personal"); both stay raw data. User-set ones are never touched.
final class Classifier {
    static let shared = Classifier()
    private let store = Store.shared
    private var db: DB { store.db }
    private var running = false
    static let interval: TimeInterval = 20 * 60
    /// The busiest windows go first; the rest wait for the next round.
    static let maxWindows = 150

    func startSchedule() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in self?.run() }
        Timer.scheduledTimer(withTimeInterval: Classifier.interval, repeats: true) { [weak self] _ in self?.run() }
    }

    func run() {
        ProjectDescriber.shared.fillEmpty()
        let projects = store.projects()
        guard !running, !projects.isEmpty else { return }
        let start = Day.interval(Day.key(Date())).start
        let windows = Dictionary(grouping: db.query("""
            SELECT * FROM activity WHERE project_id IS NULL AND user_set=0 AND COALESCE(reason,'') NOT LIKE 'ai%' AND end>? AND end-start>=2
            """, [start]).map(Activity.init), by: Store.describe)
            .map { (text: $0.key, ids: $0.value.map(\.id), seconds: $0.value.reduce(0) { $0 + $1.interval.duration }) }
            .sorted { $0.seconds > $1.seconds }.prefix(Classifier.maxWindows)
        let sessions = db.query("""
            SELECT DISTINCT s.* FROM session s JOIN run r ON r.session_id=s.id
            WHERE s.project_id IS NULL AND s.ignored=0 AND s.ai_reason IS NULL AND COALESCE(r.end, r.start)>?
            """, [start]).map(ClaudeSession.init)
        guard !windows.isEmpty || !sessions.isEmpty else { return }

        var items = windows.enumerated().map { ClassifierPrompt.Item(id: "w\($0.offset)", line: "\(hm($0.element.seconds)) · \($0.element.text)") }
        items += sessions.enumerated().map { i, s in
            let prompts = store.prompts(session: s.id).prefix(8).map { "\"\($0.text.replacingOccurrences(of: "\n", with: " ").prefix(200))\"" }
            return ClassifierPrompt.Item(id: "s\(i)", line: "Claude Code session in \(s.cwd)\(s.summary.map { " · label: \($0)" } ?? "") · prompts: \(prompts.joined(separator: " | "))")
        }
        let prompt = ClassifierPrompt.build(projects: projects, corrections: store.corrections(), items: items)
        running = true
        Log.write("classify", "sending \(windows.count) windows, \(sessions.count) sessions (\(prompt.count) chars) to claude -p")
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try DaySummary.runClaude(prompt: prompt) }
            DispatchQueue.main.async {
                self.running = false
                guard case .success(let text) = result, let decisions = ClassifierPrompt.parse(text, projects: projects) else {
                    return Log.write("classify", "failed: \((try? result.get())?.prefix(300) ?? "\(result)")")
                }
                for (i, w) in windows.enumerated() { if let d = decisions["w\(i)"] { self.apply(d, windows: w.ids, text: w.text) } }
                for (i, s) in sessions.enumerated() { if let d = decisions["s\(i)"] { self.apply(d, session: s) } }
                self.store.refresh()
            }
        }
    }

    private func apply(_ d: ClassifierPrompt.Decision, windows ids: [Int64], text: String) {
        let reason = (d.projectId != nil ? "ai: " : d.work ? "ai unknown: " : "ai personal: ") + d.why
        for id in ids {
            db.run("UPDATE activity SET project_id=?, reason=? WHERE id=? AND project_id IS NULL AND user_set=0", [d.projectId, reason, id])
        }
        Log.write("classify", "\(text.prefix(120)) → \(store.project(d.projectId)?.name ?? "none") (\(reason))")
    }

    private func apply(_ d: ClassifierPrompt.Decision, session s: ClaudeSession) {
        let reason = (d.projectId != nil ? "" : d.work ? "unknown: " : "personal: ") + d.why
        db.run("UPDATE session SET project_id=?, ai_reason=? WHERE id=? AND project_id IS NULL", [d.projectId, reason, s.id])
        Log.write("classify", "session \(s.id.prefix(8)) \(s.cwd) → \(store.project(d.projectId)?.name ?? "none") (\(reason))")
    }
}
