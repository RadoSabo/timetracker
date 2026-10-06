import Foundation

/// Tails events.jsonl and turns hook events into sessions, prompts, runs and shell commands.
final class EventIngest {
    static let shared = EventIngest()
    private let store = Store.shared
    private let db = DB.shared
    private var timer: Timer?
    private var offset: UInt64 {
        get { UInt64(db.setting("events_offset") ?? "0") ?? 0 }
        set { db.setSetting("events_offset", "\(newValue)") }
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.ingest() }
        RunLoop.main.add(timer!, forMode: .common)
        ingest()
    }

    func ingest() {
        guard let h = try? FileHandle(forReadingFrom: Hooks.eventsFile) else { return }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let off = size < offset ? 0 : offset
        guard size > off else { return }
        try? h.seek(toOffset: off)
        guard let data = try? h.readToEnd(), let text = String(data: data, encoding: .utf8), let lastNL = text.lastIndex(of: "\n") else { return }
        let complete = text[..<lastNL]
        for line in complete.split(separator: "\n") where !line.isEmpty {
            if let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] { handle(obj) }
        }
        offset = off + UInt64(complete.utf8.count) + 1
        store.refresh()
    }

    private func handle(_ e: [String: Any]) {
        let ts = (e["ts"] as? Double) ?? now()
        let p = e["payload"] as? [String: Any] ?? [:]
        let event = e["event"] as? String ?? ""
        let cwd = p["cwd"] as? String ?? ""
        let prompt = (p["prompt"] as? String ?? "").replacingOccurrences(of: "\n", with: " ")
        Log.write("hook", "\(event) session=\((p["session_id"] as? String ?? "-").prefix(8)) cwd=\(cwd) \(prompt.isEmpty ? "" : "prompt='\(prompt.prefix(80))'")")

        if event == "shell" {
            let pid: Int64? = cwd.isEmpty ? nil : store.projectId(forCwd: cwd)
            db.run("INSERT INTO shell(ts,cwd,cmd,project_id) VALUES(?,?,?,?)", [ts, cwd, p["cmd"] as? String ?? "", pid])
            return
        }
        guard let sid = p["session_id"] as? String else { return }
        if store.session(sid) == nil {
            let pid: Int64? = cwd.isEmpty ? nil : store.projectId(forCwd: cwd)
            db.run("INSERT INTO session(id,cwd,branch,project_id,started,last_event) VALUES(?,?,?,?,?,?)",
                   [sid, cwd, Git.root(of: cwd).flatMap(Git.branch), pid, ts, ts])
        }
        db.run("UPDATE session SET last_event=?, transcript=COALESCE(?, transcript) WHERE id=?", [ts, p["transcript_path"] as? String, sid])
        switch event {
        case "UserPromptSubmit":
            db.run("INSERT INTO prompt(session_id,ts,text) VALUES(?,?,?)", [sid, ts, p["prompt"] as? String ?? ""])
            if db.query("SELECT id FROM run WHERE session_id=? AND end IS NULL", [sid]).isEmpty {
                db.run("INSERT INTO run(session_id,start) VALUES(?,?)", [sid, ts])
            }
        case "Stop":
            closeRun(sid, at: ts)
            Summarizer.shared.summarize(sessionId: sid)
        case "SessionEnd":
            closeRun(sid, at: ts)
            db.run("UPDATE session SET ended=? WHERE id=?", [ts, sid])
        default: break
        }
    }

    private func closeRun(_ sid: String, at ts: Seconds) {
        db.run("UPDATE run SET end=? WHERE session_id=? AND end IS NULL", [ts, sid])
    }
}
