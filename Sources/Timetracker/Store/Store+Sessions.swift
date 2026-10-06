import Foundation

/// Claude Sessions, their runs (prompt → Stop) and prompts; shell commands.
extension Store {
    func session(_ id: String) -> ClaudeSession? { db.query("SELECT * FROM session WHERE id=?", [id]).first.map(ClaudeSession.init) }
    /// Prompts the user typed; machine-injected ones (XML-like `<relay…>`, `<command-…>`) are skipped.
    func prompts(session: String) -> [(ts: Seconds, text: String)] {
        db.query("SELECT ts,text FROM prompt WHERE session_id=? AND ltrim(text) NOT LIKE '<%' ORDER BY ts", [session]).map { ($0.dbl("ts"), $0.str("text")) }
    }
    func runningSessions() -> [ClaudeSession] {
        db.query("SELECT DISTINCT s.* FROM session s JOIN run r ON r.session_id=s.id WHERE r.end IS NULL").map(ClaudeSession.init)
    }
    /// Run intervals of a session; an open run counts until now, capped at maxRunHours.
    func runs(session: String) -> [Interval] {
        db.query("SELECT start,end FROM run WHERE session_id=?", [session]).map {
            Interval(start: $0.dbl("start"), end: $0.optDbl("end") ?? min(now(), $0.dbl("start") + Settings.maxRunSeconds))
        }
    }
    /// Runs (agent working) overlapping the day, with their session, project and the Task the session worked on.
    func agentRuns(day: String) -> [AgentRun] {
        let d = Day.interval(day)
        return db.query("""
            SELECT r.start, r.end, s.id, s.project_id, s.cwd, s.summary,
                   (SELECT name FROM task t WHERE t.session_id=s.id AND t.day=? ORDER BY t.id DESC LIMIT 1) AS task
            FROM run r JOIN session s ON s.id=r.session_id WHERE COALESCE(r.end, ?)>? AND r.start<? ORDER BY r.start
            """, [day, now(), d.start, d.end]).map {
            let start = $0.dbl("start")
            return AgentRun(interval: Interval(start: start, end: $0.optDbl("end") ?? min(now(), start + Settings.maxRunSeconds)),
                            sessionId: $0.str("id"), projectId: $0.optInt("project_id"),
                            label: $0.optStr("task") ?? $0.optStr("summary") ?? ($0.str("cwd") as NSString).lastPathComponent)
        }
    }
    /// Closes runs that never received Stop (crashed sessions).
    func closeStaleRuns() {
        db.run("UPDATE run SET end=start+? WHERE end IS NULL AND start<?", [Settings.maxRunSeconds, now() - Settings.maxRunSeconds])
    }

    func shellCommands(day: String) -> [(ts: Seconds, cwd: String, cmd: String)] {
        let d = Day.interval(day)
        return db.query("SELECT ts,cwd,cmd FROM shell WHERE ts>=? AND ts<? ORDER BY ts", [d.start, d.end]).map { ($0.dbl("ts"), $0.str("cwd"), $0.str("cmd")) }
    }
}
