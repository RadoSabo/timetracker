import Testing
@testable import Timetracker

@Test func summaryAnswerBecomesDraftsAndOnlyTheLongestKeepsASharedTask() {
    let acme = Project(row: Row(values: ["id": Int64(1), "name": "acme-api", "billable": Int64(1), "rate": 50.0, "color": Int64(0), "hidden": Int64(0), "keywords": ""]))
    let answer = """
    Sure, here it is:
    [{"project": "ACME-API", "task_id": 9, "name": "Review CI", "description": "PR #31", "ranges": [["10:00", "11:00"]]},
     {"project": "acme-api", "task_id": 9, "name": "Short", "ranges": [["12:00", "12:10"], ["bad"]]},
     {"project": "unknown", "task_id": null, "name": "X", "ranges": [["13:00", "14:00"]]},
     {"project": "acme-api", "name": "No time", "ranges": []}]
    """
    let drafts = DaySummaryPrompt.parse(answer, day: "2026-10-01", projects: [acme])!
    #expect(drafts.map(\.name) == ["Review CI", "Short"])
    #expect(drafts.map(\.taskId) == [9, nil])
    #expect(drafts[0].ranges.total == 3600 && drafts[1].ranges.count == 1)
    #expect(DaySummaryPrompt.parse("no json here", day: "2026-10-01", projects: [acme]) == nil)
}
