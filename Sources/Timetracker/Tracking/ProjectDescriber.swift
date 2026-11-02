import Foundation

/// Writes a Project's description for the Classification from what is known about it: its folder's README and
/// CLAUDE.md, its tasks and Claude Session labels, its busiest windows, the user's Corrections. Empty descriptions are
/// filled before each Classification; the user edits or regenerates them in Settings.
final class ProjectDescriber {
    static let shared = ProjectDescriber()
    private let store = Store.shared
    private var db: DB { store.db }
    private(set) var running: Set<Int64> = []

    func fillEmpty() {
        for p in store.projects(includeHidden: true) where p.description.isEmpty { generate(p.id, overwrite: false) }
    }

    /// `overwrite` false keeps whatever the user typed in the meantime.
    func generate(_ id: Int64, overwrite: Bool, done: @escaping () -> Void = {}) {
        guard !running.contains(id), let p = store.project(id) else { return done() }
        let evidence = evidence(p)
        guard !evidence.isEmpty else { return done() }
        let others = store.projects(includeHidden: true).filter { $0.id != id }
            .map { "- \($0.name)" + ($0.description.isEmpty ? "" : ": \($0.description)") }.joined(separator: "\n")
        let prompt = """
            Write a description of the project "\(p.name)" for an AI that assigns a contractor's computer activity \
            (window titles, URLs, Claude Code prompts) to projects. 1–3 English sentences, at most 350 characters: the \
            product and client, its domain, main technologies, typical topics, URLs and domains. Say what sets it apart \
            from the other projects below, especially ones with similar names. Answer with the description only.

            ## Other projects
            \(others.isEmpty ? "none" : others)

            ## What is known about \(p.name)
            \(evidence)
            """
        running.insert(id)
        Log.write("describe", "\(p.name): sending \(prompt.count) chars to claude -p")
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try DaySummary.runClaude(prompt: prompt) }
            DispatchQueue.main.async {
                self.running.remove(id)
                defer { done() }
                guard case .success(let raw) = result else { return Log.write("describe", "\(p.name) failed: \(result)") }
                let text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
                guard !text.isEmpty else { return }
                self.db.run("UPDATE project SET description=? WHERE id=?\(overwrite ? "" : " AND description=''")", [text, id])
                Log.write("describe", "\(p.name) → \(text)")
                self.store.reclassifyToday()
                self.store.refresh()
            }
        }
    }

    private func evidence(_ p: Project) -> String {
        var s = ""
        if !p.keywords.isEmpty { s += "Keywords: \(p.keywords)\n" }
        if let path = p.path {
            s += "Folder: \(path)\n"
            for f in ["README.md", "CLAUDE.md", "CONTEXT.md"] {
                if let text = try? String(contentsOfFile: path + "/" + f, encoding: .utf8) { s += "\n### \(f)\n\(text.prefix(2500))\n" }
            }
        }
        let tasks = db.query("SELECT name FROM task WHERE project_id=? GROUP BY name ORDER BY MAX(id) DESC LIMIT 40", [p.id]).map { $0.str("name") }
        if !tasks.isEmpty { s += "\n### Tasks\n" + tasks.map { "- \($0)" }.joined(separator: "\n") + "\n" }
        let windows = db.query("""
            SELECT app, title, url FROM activity WHERE project_id=? GROUP BY app, title ORDER BY SUM(end-start) DESC LIMIT 40
            """, [p.id]).map(Activity.init).map(Store.describe)
        if !windows.isEmpty { s += "\n### Busiest windows\n" + windows.map { "- \($0)" }.joined(separator: "\n") + "\n" }
        let fixes = store.corrections(limit: 200).filter { $0.project == p.name }.prefix(20)
        if !fixes.isEmpty { s += "\n### The user put these here by hand\n" + fixes.map { "- \($0.text)" }.joined(separator: "\n") + "\n" }
        return s
    }
}
