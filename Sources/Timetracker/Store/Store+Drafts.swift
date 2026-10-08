import Foundation

/// Drafts from the AI day summary. Approving one assigns the activities inside its ranges to its task.
extension Store {
    func drafts(day: String) -> [Draft] {
        db.query("SELECT * FROM draft WHERE day=? AND status='pending' ORDER BY id", [day]).map(Draft.init)
    }

    /// Replaces the day's pending AI drafts; approved and dismissed ones and calendar meetings stay.
    func replaceDrafts(day: String, with items: [Draft.Proposal]) {
        db.run("DELETE FROM draft WHERE day=? AND status='pending' AND source IS NULL", [day])
        for d in items {
            let json = String(data: try! JSONSerialization.data(withJSONObject: d.ranges.map { [$0.start, $0.end] }), encoding: .utf8)!
            db.run("INSERT INTO draft(day,project_id,task_id,name,description,ranges) VALUES(?,?,?,?,?,?)",
                   [day, d.projectId, d.taskId, d.name, d.description, json])
        }
        refresh()
    }

    /// Approves all at once: every target task is released first, so two drafts for one task don't undo each other.
    /// Approving the whole summary replaces the day's AI timesheet: tasks that only an earlier summary created and this
    /// one doesn't reuse are deleted.
    func approveAll(_ drafts: [Draft]) {
        guard let day = drafts.first?.day else { return }
        let kept = Set(drafts.compactMap(\.taskId))
        let stale = tasks(day: day).filter { $0.fromDraft && !kept.contains($0.id) }
        drafts.compactMap(\.taskId).forEach(releaseAIAssignments)
        drafts.forEach { approve($0, release: false) }
        for t in stale where !drafts.contains(where: { $0.taskId == nil && $0.projectId == t.projectId && $0.name == t.name }) {
            deleteTask(t.id)
            Log.write("draft", "removed stale AI task #\(t.id) '\(t.name)'")
        }
    }

    /// The draft regenerates its task: earlier AI assignments are released, the approved name sticks.
    /// A calendar draft becomes a Meeting instead, which gets its own task.
    func approve(_ d: Draft, release: Bool = true) {
        if d.isCalendar { return approveMeeting(d) }
        let tid = d.taskId.flatMap { task($0)?.id } ?? ensureTask(projectId: d.projectId, day: d.day, name: d.name, sessionId: nil)
        if release { releaseAIAssignments(tid) }
        if task(tid)?.projectId != d.projectId { db.run("UPDATE task SET project_id=? WHERE id=?", [d.projectId, tid]) }
        // Approved ranges are the task's time up to now, so overlapping drafts keep their own time; later work is tracked live.
        db.run("DELETE FROM task_range WHERE task_id=?", [tid])
        for r in d.ranges.union() { db.run("INSERT INTO task_range(task_id,start,end) VALUES(?,?,?)", [tid, r.start, r.end]) }
        db.run("UPDATE task SET ranges_until=? WHERE id=?", [max(now(), d.ranges.map(\.end).max() ?? 0), tid])
        if !isBareProjectName(d.name) { db.run("UPDATE task SET name=?, name_edited=1 WHERE id=?", [d.name, tid]) }
        var assigned = 0
        for r in d.ranges {
            // User-set activities are never overridden by AI.
            let ids = db.query("SELECT id FROM activity WHERE user_set=0 AND start<? AND end>?", [r.end, r.start]).map { $0.int("id") }
            for id in ids { db.run("UPDATE activity SET project_id=?, task_id=?, reason=? WHERE id=?", [d.projectId, tid, "ai draft #\(d.id)", id]) }
            assigned += ids.count
        }
        db.run("UPDATE draft SET status='approved', task_id=? WHERE id=?", [tid, d.id])
        Log.write("draft", "approved #\(d.id) '\(d.name)' → task #\(tid), \(assigned) activities")
        refresh()
    }

    private func releaseAIAssignments(_ taskId: Int64) {
        db.run("UPDATE activity SET task_id=NULL WHERE task_id=? AND user_set=0 AND reason LIKE 'ai draft%'", [taskId])
    }

    /// Finished work-calendar events that recorded Meetings cover for less than 80 % (the Mac was idle or asleep, e.g. an
    /// in-person meeting) become drafts to confirm. Each event is offered once; a dismissed one stays gone. Confirming
    /// adds a Meeting with the same title, so a partly recorded one merges into the same task.
    func offerCalendarMeetings(_ events: [(id: String, title: String, notes: String, interval: Interval)]) {
        var added = 0
        for e in events where e.interval.end <= now() {
            let source = "calendar:\(e.id)@\(Int(e.interval.start))"
            let recorded = db.query("SELECT start, COALESCE(end, ?) AS end FROM meeting WHERE start<? AND COALESCE(end, ?)>?", [now(), e.interval.end, now(), e.interval.start])
                .compactMap { Interval(start: $0.dbl("start"), end: $0.dbl("end")).clipped(to: e.interval) }.total
            guard db.query("SELECT id FROM draft WHERE source=?", [source]).isEmpty, recorded < 0.8 * e.interval.duration,
                  let pid = projectMatching(e.title + " " + e.notes)?.project.id ?? billableProjects().first?.id else { continue }
            let json = String(data: try! JSONSerialization.data(withJSONObject: [[e.interval.start, e.interval.end]]), encoding: .utf8)!
            db.run("INSERT INTO draft(day,project_id,name,description,ranges,source) VALUES(?,?,?,?,?,?)",
                   [Day.key(e.interval.start), pid, e.title, e.notes, json, source])
            Log.write("meeting", "offered calendar event '\(e.title)' \(clock(e.interval.start))–\(clock(e.interval.end)) → \(project(pid)?.name ?? "?")")
            added += 1
        }
        if added > 0 { refresh() }
    }

    private func approveMeeting(_ d: Draft) {
        for r in d.ranges { db.run("INSERT INTO meeting(start,end,title,project_id) VALUES(?,?,?,?)", [r.start, r.end, d.name, d.projectId]) }
        db.run("UPDATE draft SET status='approved' WHERE id=?", [d.id])
        Log.write("meeting", "confirmed calendar meeting #\(d.id) '\(d.name)'")
        refresh()
    }

    func dismiss(_ d: Draft) {
        db.run("UPDATE draft SET status='dismissed' WHERE id=?", [d.id])
        Log.write("draft", "dismissed #\(d.id) '\(d.name)'")
        refresh()
    }
}
