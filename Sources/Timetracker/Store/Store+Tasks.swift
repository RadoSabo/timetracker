import Foundation

/// Tasks: one per Claude Session per day, one per meeting, "General" for the rest; Project Time is their union.
/// A Task without a Project (No Project) waits for the user to pick one.
extension Store {
    func task(_ id: Int64) -> TaskItem? { db.query("SELECT * FROM task WHERE id=?", [id]).first.map(TaskItem.init) }

    @discardableResult
    func ensureTask(projectId: Int64?, day: String, name: String, sessionId: String?) -> Int64 {
        let existing = sessionId.map { db.query("SELECT id FROM task WHERE session_id=? AND day=?", [$0, day]) }
            ?? db.query("SELECT id FROM task WHERE project_id IS ? AND day=? AND name=? AND session_id IS NULL", [projectId, day, name])
        if let r = existing.first { return r.int("id") }
        return db.run("INSERT INTO task(project_id,day,name,session_id) VALUES(?,?,?,?)", [projectId, day, name, sessionId])
    }
    func renameTask(_ id: Int64, _ name: String) { db.run("UPDATE task SET name=?, name_edited=1 WHERE id=?", [name, id]); refresh() }
    func setAdjustment(_ id: Int64, seconds: Seconds, note: String) {
        db.run("UPDATE task SET adjustment=?, adjustment_note=? WHERE id=?", [seconds, note, id]); refresh()
    }
    func moveTask(_ id: Int64, toProject pid: Int64) {
        if let t = task(id) { recordCorrection(task: t, projectId: pid) }
        db.run("UPDATE task SET project_id=?, project_edited=1 WHERE id=?", [pid, id])
        for table in ["activity", "manual", "meeting"] { db.run("UPDATE \(table) SET project_id=? WHERE task_id=?", [pid, id]) }
        refresh()
    }
    /// The user says this isn't work: its windows lose their Project for good (no rule, keyword or AI brings them back),
    /// its Claude Session stops making a task.
    func deleteTask(_ id: Int64) {
        if let sid = task(id)?.sessionId { db.run("UPDATE session SET ignored=1 WHERE id=?", [sid]) }
        db.run("UPDATE activity SET project_id=NULL, task_id=NULL, user_set=1, reason='task deleted' WHERE task_id=?", [id])
        Log.write("task", "user deleted task #\(id)")
        dropTask(id)
    }
    /// Removes the task only; its windows keep their Project and get re-tasked on the next rebuild.
    func dropTask(_ id: Int64) {
        db.run("UPDATE activity SET task_id=NULL WHERE task_id=?", [id])
        db.run("DELETE FROM manual WHERE task_id=?", [id])
        db.run("DELETE FROM task_range WHERE task_id=?", [id])
        db.run("DELETE FROM task WHERE id=?", [id]); refresh()
    }

    /// The day's tasks with tracked and manual intervals filled in. Rebuilds task membership first unless told not to.
    func tasks(day: String, rebuild: Bool = true) -> [TaskItem] {
        if rebuild, let c = taskCache[day], c.tick == tick { return c.tasks }
        let result = loadTasks(day: day, rebuild: rebuild)
        if rebuild { taskCache[day] = (tick, result) }
        return result
    }

    private func loadTasks(day: String, rebuild: Bool) -> [TaskItem] {
        if rebuild { rebuildTasks(day: day) }
        let d = Day.interval(day)
        var tasks = db.query("SELECT * FROM task WHERE day=? ORDER BY id", [day]).map(TaskItem.init)
        for i in tasks.indices {
            let t = tasks[i]
            var tracked = intervals("SELECT start,end FROM activity WHERE task_id=?", [t.id])
            tracked += intervals("SELECT start,end FROM meeting WHERE task_id=?", [t.id])
            if let sid = t.sessionId { tracked += runs(session: sid) }
            if let until = t.rangesUntil {
                let live = Interval(start: until, end: d.end)
                tracked = intervals("SELECT start,end FROM task_range WHERE task_id=?", [t.id]) + tracked.compactMap { $0.clipped(to: live) }
            }
            tasks[i].tracked = tracked.compactMap { $0.clipped(to: d) }.union()
            tasks[i].fromDraft = t.sessionId == nil && t.adjustment == 0
                && db.scalar("SELECT COUNT(*) FROM draft WHERE task_id=? AND status='approved'", [t.id]) > 0
                && db.scalar("SELECT (SELECT COUNT(*) FROM meeting WHERE task_id=?) + (SELECT COUNT(*) FROM manual WHERE task_id=?)", [t.id, t.id]) == 0
            tasks[i].manual = intervals("SELECT start,end FROM manual WHERE task_id=?", [t.id]).compactMap { $0.clipped(to: d) }.union()
        }
        return tasks.filter { $0.totalSeconds > 0 || $0.adjustment != 0 || $0.sessionId != nil }
    }

    private func intervals(_ sql: String, _ args: [Any?]) -> [Interval] {
        db.query(sql, args).map { Interval(start: $0.dbl("start"), end: $0.optDbl("end") ?? now()) }
    }

    private func rebuildTasks(day: String) {
        let d = Day.interval(day)
        // 1. one task per Claude Session that ran today
        for s in db.query("""
            SELECT DISTINCT s.* FROM session s JOIN run r ON r.session_id=s.id
            WHERE s.ignored=0 AND r.start<? AND COALESCE(r.end, r.start+?)>?
            """, [d.end, Settings.maxRunSeconds, d.start]).map(ClaudeSession.init) {
            let pid = sessionProject(s)
            let name = s.summary ?? firstPromptName(s.id)
            let tid = ensureTask(projectId: pid, day: day, name: name, sessionId: s.id)
            followSessionProject(tid, pid)
            db.run("UPDATE task SET name=? WHERE id=? AND name_edited=0", [name, tid])
        }
        // 2. one task per meeting; a meeting without a Project becomes a No Project task for the user to place
        for m in db.query("SELECT * FROM meeting WHERE task_id IS NULL AND start<? AND COALESCE(end,?)>?", [d.end, d.end, d.start]) {
            let tid = ensureTask(projectId: m.optInt("project_id"), day: day, name: "Meeting: " + m.str("title"), sessionId: nil)
            db.run("UPDATE meeting SET task_id=? WHERE id=?", [tid, m.int("id")])
        }
        // 3. activities with a project but no task; the rest stays raw data, a "No project · General" says nothing
        let sessionTasks = db.query("SELECT * FROM task WHERE day=? AND session_id IS NOT NULL AND project_id IS NOT NULL", [day]).map(TaskItem.init)
        for a in db.query("SELECT * FROM activity WHERE task_id IS NULL AND project_id IS NOT NULL AND end>? AND start<?", [d.start, d.end]).map(Activity.init) {
            let tid = taskFor(a, among: sessionTasks.filter { $0.projectId == a.projectId })
                ?? ensureTask(projectId: a.projectId, day: day, name: "General", sessionId: nil)
            db.run("UPDATE activity SET task_id=? WHERE id=?", [tid, a.id])
            Log.write("task", "activity #\(a.id) \(a.app) | \(a.title.prefix(60)) → task #\(tid) '\(task(tid)?.name.prefix(60) ?? "")'")
        }
    }

    /// Where the user moved an earlier session with the same Session Summary wins (a follow-up session repeats the label);
    /// then the Project folder a Claude Session runs in; a Project named in the Session Summary decides only when the cwd
    /// is in none, then the AI classification (stored on the session). Claude Code names a session once, from its first
    /// prompt, so the name can point at another project. Recomputed on every rebuild.
    private func sessionProject(_ s: ClaudeSession) -> Int64? {
        let pid = s.summary.flatMap(correctedProject(sessionSummary:)) ?? (s.cwd.isEmpty ? nil : projectId(forCwd: s.cwd))
            ?? s.summary.flatMap(projectMatching)?.project.id ?? s.projectId
        if pid != s.projectId { db.run("UPDATE session SET project_id=? WHERE id=?", [pid, s.id]) }
        return pid
    }

    /// Moves a session's task to the session's Project unless the user moved it or approved it from a draft; its
    /// activities get re-tasked on the next rebuild.
    private func followSessionProject(_ tid: Int64, _ pid: Int64?) {
        guard let t = task(tid), t.projectId != pid, !t.projectEdited, t.rangesUntil == nil,
              db.scalar("SELECT COUNT(*) FROM draft WHERE task_id=? AND status='approved'", [tid]) == 0 else { return }
        db.run("UPDATE task SET project_id=? WHERE id=?", [pid, tid])
        db.run("UPDATE activity SET task_id=NULL WHERE task_id=?", [tid])
        Log.write("task", "task #\(tid) '\(t.name)' → project \(pid.map { "#\($0)" } ?? "none") (session)")
    }

    /// Session task whose runs overlap the activity, else the nearest one in time.
    /// ponytail: time proximity only; on-device model classification if this proves too naive.
    private func taskFor(_ a: Activity, among candidates: [TaskItem]) -> Int64? {
        func distance(_ t: TaskItem) -> Seconds {
            runs(session: t.sessionId!).map { r in
                a.interval.end < r.start ? r.start - a.interval.end : (a.interval.start > r.end ? a.interval.start - r.end : 0)
            }.min() ?? .infinity
        }
        return candidates.min { distance($0) < distance($1) }?.id
    }

    private func firstPromptName(_ sessionId: String) -> String {
        let t = prompts(session: sessionId).first?.text ?? "Claude session"
        return String(t.replacingOccurrences(of: "\n", with: " ").prefix(80))
    }
}
