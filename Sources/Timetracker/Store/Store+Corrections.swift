import Foundation

/// Corrections: what the user assigned to a Project by hand. The AI classification gets the latest ones as examples.
extension Store {
    static func describe(_ a: Activity) -> String {
        String((a.app + " · " + a.title + (a.url.map { " · " + $0 } ?? "")).prefix(250))
    }

    func recordCorrection(_ text: String, projectId: Int64?) {
        db.run("DELETE FROM correction WHERE text=?", [text])
        db.run("INSERT INTO correction(ts,text,project_id) VALUES(?,?,?)", [now(), text, projectId])
        Log.write("correction", "'\(text.prefix(100))' → \(project(projectId)?.name ?? "no project")")
    }

    func recordCorrection(activity id: Int64, projectId: Int64?) {
        guard let a = db.query("SELECT * FROM activity WHERE id=?", [id]).first.map(Activity.init) else { return }
        recordCorrection(Self.describe(a), projectId: projectId)
    }

    /// The task's name and session, plus its distinct windows.
    func recordCorrection(task t: TaskItem, projectId: Int64) {
        let session = t.sessionId.flatMap(session).map { " · Claude Code session in \($0.cwd)" } ?? ""
        recordCorrection("task \"\(t.name)\"" + session, projectId: projectId)
        let windows = Set(db.query("SELECT * FROM activity WHERE task_id=?", [t.id]).map(Activity.init).map(Self.describe))
        for w in windows.prefix(10) { recordCorrection(w, projectId: projectId) }
    }

    /// The Project the user moved a session task with this Session Summary to; nil when they never did.
    func correctedProject(sessionSummary: String) -> Int64? {
        db.query("SELECT t.project_id FROM task t JOIN session s ON s.id=t.session_id WHERE t.project_edited=1 AND s.summary=? ORDER BY t.id DESC LIMIT 1",
                 [sessionSummary]).first?.optInt("project_id")
    }
    /// The Project the user moved a meeting task with this title to; nil when they never did.
    func correctedProject(meetingTitle: String) -> Int64? {
        db.query("SELECT m.project_id FROM meeting m JOIN task t ON t.id=m.task_id WHERE t.project_edited=1 AND m.title=? ORDER BY m.id DESC LIMIT 1",
                 [meetingTitle]).first?.optInt("project_id")
    }
    /// Keyword in the meeting title or notes, else the user's earlier move of a meeting with this title, else the only
    /// billable Project; with several billable Projects the meeting is No Project until the user picks (no guessing).
    func meetingProject(title: String, notes: String = "") -> Int64? {
        if let m = projectMatching(title + " " + notes) { return m.project.id }
        if let pid = correctedProject(meetingTitle: title) { return pid }
        let billable = billableProjects()
        return billable.count == 1 ? billable[0].id : nil
    }

    /// Newest first.
    func corrections(limit: Int = 60) -> [(text: String, project: String?)] {
        let names = Dictionary(uniqueKeysWithValues: projects(includeHidden: true).map { ($0.id, $0.name) })
        return db.query("SELECT text, project_id FROM correction ORDER BY ts DESC LIMIT ?", [limit])
            .map { ($0.str("text"), $0.optInt("project_id").flatMap { names[$0] }) }
    }
}
