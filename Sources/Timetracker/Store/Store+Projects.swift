import Foundation

/// Removing a Project: its windows go back to raw data, Claude Sessions and Manual time stay as No Project.
extension Store {
    func deleteProject(_ id: Int64) {
        let gone = "SELECT id FROM task WHERE project_id=\(id) AND session_id IS NULL AND id NOT IN (SELECT task_id FROM manual WHERE task_id IS NOT NULL)"
        db.run("DELETE FROM task_range WHERE task_id IN (\(gone))")
        db.run("UPDATE meeting SET task_id=NULL WHERE task_id IN (\(gone))")
        db.run("DELETE FROM task WHERE id IN (\(gone))")
        db.run("UPDATE activity SET project_id=NULL, task_id=NULL, reason=NULL, user_set=0 WHERE project_id=?", [id])
        db.run("UPDATE session SET project_id=NULL, ai_reason=NULL WHERE project_id=?", [id])
        for table in ["shell", "meeting", "task", "draft", "manual"] { db.run("UPDATE \(table) SET project_id=NULL WHERE project_id=?", [id]) }
        for table in ["rule", "pause", "day_start", "correction"] { db.run("DELETE FROM \(table) WHERE project_id=?", [id]) }
        db.run("DELETE FROM project WHERE id=?", [id])
        Log.write("project", "deleted #\(id): windows unassigned, sessions and manual time are No Project now")
        refresh()
    }

    /// A new or changed Project may fit what the AI left without one: today's leftovers get classified again.
    func reclassifyToday() {
        let start = Day.interval(Day.key(Date())).start
        db.run("UPDATE activity SET reason=NULL WHERE project_id IS NULL AND user_set=0 AND reason LIKE 'ai%' AND end>?", [start])
        db.run("UPDATE session SET ai_reason=NULL WHERE project_id IS NULL AND last_event>?", [start])
    }
}
