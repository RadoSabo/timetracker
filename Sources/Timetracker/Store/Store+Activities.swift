import Foundation

/// Activities (tracked windows) and Manual Entries.
extension Store {
    func activities(day: String) -> [Activity] {
        let d = Day.interval(day)
        return db.query("SELECT * FROM activity WHERE end>? AND start<? ORDER BY start", [d.start, d.end]).map(Activity.init)
    }
    func setActivityProject(_ id: Int64, projectId: Int64?) {
        db.run("UPDATE activity SET project_id=?, task_id=NULL, user_set=1 WHERE id=?", [projectId, id]); refresh()
    }
    func setActivityTask(_ id: Int64, taskId: Int64?) {
        let pid = taskId.flatMap { task($0)?.projectId }
        db.run("UPDATE activity SET task_id=?, project_id=COALESCE(?,project_id), user_set=1 WHERE id=?", [taskId, pid, id]); refresh()
    }
    func deleteActivity(_ id: Int64) { db.run("DELETE FROM activity WHERE id=?", [id]); refresh() }
    func unassignedCount(day: String) -> Int {
        let d = Day.interval(day)
        return Int(db.scalar("SELECT COUNT(*) FROM activity WHERE project_id IS NULL AND end>? AND start<? AND end-start>=?",
                             [d.start, d.end, Settings.minVisibleSeconds]))
    }

    func manualEntries(day: String) -> [ManualEntry] {
        let d = Day.interval(day)
        return db.query("SELECT * FROM manual WHERE end>? AND start<? ORDER BY start", [d.start, d.end]).map(ManualEntry.init)
    }
    func addManual(start: Seconds, end: Seconds, projectId: Int64, note: String, taskId: Int64?) {
        let tid = taskId ?? ensureTask(projectId: projectId, day: Day.key(start), name: note.isEmpty ? "Manual" : note, sessionId: nil)
        db.run("INSERT INTO manual(start,end,project_id,note,task_id) VALUES(?,?,?,?,?)", [start, end, projectId, note, tid])
        refresh()
    }
}
