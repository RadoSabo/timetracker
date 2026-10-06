import AppKit

/// Samples the foreground window once a second and turns it into Activities.
/// Stops on idle, sleep and screen lock; meetings live in MeetingTracker.
final class Tracker {
    static let shared = Tracker()
    private let store = Store.shared
    private let db = DB.shared
    let meetings = MeetingTracker()
    private var timer: Timer?
    private var current: (id: Int64, app: String, title: String, url: String?)?
    private let window = ForegroundWindow()
    private var lastSample: Seconds = 0
    private var paused = false
    /// Pause from the menu bar always has an end, so a forgotten pause can't swallow a day of work.
    private var userPausedUntil: Seconds?
    private var userPaused: Bool { userPausedUntil != nil }
    private var published: (pid: Int64?, set: Bool) = (nil, false)
    private(set) var idle = false

    /// Lock screen and screen saver own the foreground while nobody works.
    private static let ignoredBundles: Set<String> = ["com.apple.loginwindow", "com.apple.ScreenSaver.Engine"]
    /// A longer gap between samples means the Mac was asleep; the open activity ends at the last sample.
    private static let maxSampleGap: Seconds = 30

    func start() {
        Log.write("app", "started, accessibility=\(AX.trusted), model=\(Summarizer.available)")
        store.closeStaleRuns()
        observeSleepAndLock()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.sample() }
        timer!.tolerance = 0.2
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func observeSleepAndLock() {
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in self?.pause(n.name.rawValue) }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in self?.resume(n.name.rawValue) }
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.pause("screen locked") }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.resume("screen unlocked") }
    }

    private func pause(_ why: String) {
        guard !paused else { return }
        paused = true
        Log.write("pause", why)
        closeActivity(at: now())
        publishStatus(projectId: nil)
    }

    private func resume(_ why: String) {
        guard paused else { return }
        paused = false
        lastSample = now()
        Log.write("resume", why)
    }

    /// Pause from the menu bar until `until`, then tracking resumes on its own; sleep and lock pause separately.
    func pauseByUser(until: Seconds) {
        userPausedUntil = until
        Log.write("pause", "paused by user until \(clock(until))")
        closeActivity(at: now())
        publishStatus(projectId: nil)
    }

    func resumeByUser(_ why: String = "resumed by user") {
        guard userPaused else { return }
        userPausedUntil = nil
        Log.write("pause", why)
        lastSample = now()
        publishStatus(projectId: nil)
    }

    /// Reassigns the window in the foreground right now; the next window is assigned by the usual rules.
    func switchProject(to pid: Int64) {
        guard let c = current else { return }
        store.setActivityProject(c.id, projectId: pid)
        Log.write("assign", "user switched current activity #\(c.id) → project #\(pid)")
        publishStatus(projectId: pid)
    }

    private func sample() {
        let ts = now()
        defer { lastSample = ts }
        if lastSample > 0, ts - lastSample > Tracker.maxSampleGap, current != nil {
            Log.write("pause", "no samples for \(Int((ts - lastSample) / 60)) min (sleep), closing activity at last sample")
            closeActivity(at: lastSample)
        }
        if let until = userPausedUntil, ts >= until { resumeByUser("pause ended at \(clock(until))") }
        if let until = userPausedUntil, Int(ts) % 30 == 0 { publishPauseLeft(until) }
        let tick = Int(ts)
        if tick % 5 == 0 { AX.Dump.checkTrigger(); DaySummary.shared.checkTrigger(); Snapshot.checkTrigger() }
        guard !paused, !userPaused else { return }
        let idleSecs = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
        idle = idleSecs > Settings.idleMinutes * 60
        if tick % 15 == 0 { meetings.update(now: ts, idle: idle) }

        if idle && store.runningSessions().isEmpty && !meetings.active {
            if current != nil { Log.write("idle", "idle for \(Int(idleSecs / 60)) min, closing activity") }
            closeActivity(at: ts - idleSecs)
            publishStatus(projectId: nil)
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        if Tracker.ignoredBundles.contains(app.bundleIdentifier ?? "") { closeActivity(at: ts); return }
        let name = app.localizedName ?? app.bundleIdentifier ?? "?"
        let title = window.title(app, tick: tick)
        let url = window.url(app, title: title)

        if let c = current, c.app == name, c.title == title, c.url == url {
            if tick % 10 == 0 { db.run("UPDATE activity SET end=? WHERE id=?", [ts, c.id]) }
            return
        }
        closeActivity(at: ts)
        let (pid, reason) = store.assignProject(app: name, title: title, url: url, at: ts)
        let id = db.run("INSERT INTO activity(start,end,app,title,url,project_id,reason) VALUES(?,?,?,?,?,?,?)", [ts, ts, name, title, url, pid, reason])
        current = (id, name, title, url)
        publishStatus(projectId: pid)
        store.refresh()
    }

    private func closeActivity(at ts: Seconds) {
        guard let c = current else { return }
        db.run("UPDATE activity SET end=MAX(start, ?) WHERE id=?", [ts, c.id])
        db.run("DELETE FROM activity WHERE id=? AND end-start<2", [c.id])
        current = nil
    }

    private func publishPauseLeft(_ until: Seconds) {
        let left = hm(max(0, until - now()))
        DispatchQueue.main.async { if self.store.pauseLeft != left { self.store.pauseLeft = left } }
    }

    private func publishStatus(projectId: Int64?) {
        if let until = userPausedUntil { publishPauseLeft(until) }
        let name = store.project(projectId)?.name ?? (paused || userPaused ? "Paused" : idle ? "Idle" : "Unassigned")
        let running = store.runningSessions().compactMap(\.summary).first ?? ""
        let changed = !published.set || published.pid != projectId
        published = (projectId, true)
        DispatchQueue.main.async {
            self.store.currentProjectName = name
            self.store.currentTaskName = running
            self.store.trackingPaused = self.paused || self.userPaused
            self.store.pausedUntil = self.userPausedUntil
            if changed { self.store.currentSince = now() }
        }
    }
}
