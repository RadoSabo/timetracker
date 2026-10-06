import Foundation

/// Which Project a foreground window belongs to.
extension Store {
    func rules() -> [Rule] { db.query("SELECT * FROM rule ORDER BY id").map(Rule.init) }
    func addRule(pattern: String, projectId: Int64) { db.run("INSERT INTO rule(pattern,project_id) VALUES(?,?)", [pattern, projectId]); refresh() }
    func deleteRule(_ id: Int64) { db.run("DELETE FROM rule WHERE id=?", [id]); refresh() }

    /// Only certain signals: rule → project name or keyword in title/URL → nil. Everything else stays unassigned
    /// as raw data for the AI day summary (no guessing from time proximity).
    /// Returns the project and a human-readable reason, which is stored on the activity and logged.
    func assignProject(app: String, title: String, url: String?, at ts: Seconds) -> (projectId: Int64?, reason: String) {
        let result = decideProject(app: app, title: title, url: url)
        Log.write("assign", "\(app) | \(title) | \(url ?? "-") → \(project(result.projectId)?.name ?? "unassigned") (\(result.reason))")
        return result
    }

    private func decideProject(app: String, title: String, url: String?) -> (projectId: Int64?, reason: String) {
        let hay = "\(app) | \(title) | \(url ?? "")"
        if let r = rules().first(where: { $0.matches(hay) }) { return (r.projectId, "rule '\(r.pattern)'") }
        if let m = projectMatching("\(title) \(url ?? "")") { return (m.project.id, "keyword '\(m.word)' in title/url") }
        return (nil, "no certain signal")
    }
}
