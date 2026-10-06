import Testing
@testable import Timetracker

@Test func pendingDraftReplacesTheTaskItTargetsInsteadOfDuplicatingIt() {
    func task(_ id: Int64, _ name: String) -> TaskItem {
        var t = TaskItem(row: Row(values: ["id": id, "project_id": Int64(1), "day": "d", "name": name, "name_edited": Int64(0), "adjustment": 0.0, "adjustment_note": ""]))
        t.tracked = [Interval(start: 100, end: 200)]
        return t
    }
    func draft(_ id: Int64, _ taskId: Int64?, _ name: String) -> Draft {
        var values: [String: Any] = ["id": id, "day": "d", "project_id": Int64(1), "name": name, "description": "", "ranges": "[[100,200]]", "status": "pending"]
        values["task_id"] = taskId
        return Draft(row: Row(values: values))
    }
    let entries = TimesheetEntry.build(tasks: [task(1, "Session"), task(2, "General"), task(3, "Kept")],
                                       drafts: [draft(10, 1, "Renamed"), draft(11, nil, "General")], breaks: [], fallback: 0)
    let names = entries.map { e -> String in
        switch e.kind { case .task(let t): "task \(t.name)"; case .draft(let d): "draft \(d.name)"; case .pause: "pause" }
    }
    #expect(names.sorted() == ["draft General", "draft Renamed", "task Kept"])
}

@Test func taskSplitsIntoStretchesAtItsRealTimesClosingShortGaps() {
    var t = TaskItem(row: Row(values: ["id": Int64(1), "project_id": Int64(1), "day": "d", "name": "T", "name_edited": Int64(0), "adjustment": 0.0, "adjustment_note": ""]))
    t.tracked = [Interval(start: 0, end: 600), Interval(start: 900, end: 1200), Interval(start: 5000, end: 5600)]
    let entries = TimesheetEntry.build(tasks: [t], drafts: [], breaks: [], fallback: 0)
    #expect(entries.map { Interval(start: $0.start, end: $0.end) } == [Interval(start: 0, end: 1200), Interval(start: 5000, end: 5600)])
    #expect(entries.map(\.length) == [900, 600])
    #expect(entries.allSatisfy { $0.parts == 2 })
}

@Test func pendingSummaryHidesTasksThatOnlyAnEarlierSummaryCreated() {
    var old = TaskItem(row: Row(values: ["id": Int64(5), "project_id": Int64(1), "day": "d", "name": "Old AI", "name_edited": Int64(1), "adjustment": 0.0, "adjustment_note": ""]))
    old.tracked = [Interval(start: 100, end: 200)]
    old.fromDraft = true
    let draft = Draft(row: Row(values: ["id": Int64(1), "day": "d", "project_id": Int64(1), "name": "New", "description": "", "ranges": "[[100,200]]", "status": "pending"]))
    #expect(TimesheetEntry.build(tasks: [old], drafts: [], breaks: [], fallback: 0).count == 1)
    #expect(TimesheetEntry.build(tasks: [old], drafts: [draft], breaks: [], fallback: 0).map { if case .draft = $0.kind { true } else { false } } == [true])
}
