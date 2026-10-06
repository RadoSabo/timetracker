import EventKit
import IOKit.pwr_mgt

/// Opens and closes Meeting rows from Teams calls (power assertion) and work-calendar events.
final class MeetingTracker {
    private let store = Store.shared
    private let db = DB.shared
    let eventStore = EKEventStore()
    private var events: [EKEvent] = []
    private var eventsFetched: Date = .distantPast
    private var openId: Int64?
    private(set) var inTeamsCall = false
    var active: Bool { openId != nil }

    func update(now ts: Seconds, idle: Bool) {
        inTeamsCall = teamsInCall()
        let event = currentEvent(at: ts)
        let shouldBeActive = inTeamsCall || (event != nil && !idle)
        switch (shouldBeActive, openId) {
        case (true, nil):
            let title = event?.title ?? AX.windowTitles(bundleId: WindowContext.teams).first { !$0.contains("| Microsoft Teams") } ?? "Teams call"
            // Teams is client-only, so an unmatched meeting defaults to the first billable project.
            let pid = store.projectMatching(title)?.project.id ?? store.billableProjects().first?.id
            openId = db.run("INSERT INTO meeting(start,end,title,project_id) VALUES(?,NULL,?,?)", [ts, title, pid])
            Log.write("meeting", "start '\(title)' teamsCall=\(inTeamsCall) calendar=\(event?.title ?? "-")")
            store.refresh()
        case (true, let id?):
            db.run("UPDATE meeting SET end=? WHERE id=?", [ts, id])
        case (false, let id?):
            db.run("UPDATE meeting SET end=? WHERE id=?", [ts, id])
            Log.write("meeting", "end #\(id)")
            openId = nil
            store.refresh()
        case (false, nil): break
        }
    }

    /// Teams holds a display-sleep assertion while a call is active.
    private func teamsInCall() -> Bool {
        var assertions: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertions) == kIOReturnSuccess,
              let byPid = assertions?.takeRetainedValue() as? [Int: [[String: Any]]] else { return false }
        return byPid.values.joined().contains { a in
            let proc = (a["Process Name"] as? String ?? "").lowercased()
            let type = a["AssertionTrueType"] as? String ?? a["AssertType"] as? String ?? ""
            return proc.contains("teams") && type.contains("PreventUserIdleDisplaySleep")
        }
    }

    private func currentEvent(at ts: Seconds) -> EKEvent? {
        if Date().timeIntervalSince(eventsFetched) > 300, EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            let cals = eventStore.calendars(for: .event).filter { Settings.workCalendars.contains($0.calendarIdentifier) }
            events = cals.isEmpty ? [] : eventStore.events(matching: eventStore.predicateForEvents(
                withStart: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(12 * 3600), calendars: cals)).filter { !$0.isAllDay }
            eventsFetched = Date()
        }
        let d = Date(timeIntervalSince1970: ts)
        return events.first { $0.startDate <= d && $0.endDate > d }
    }
}
