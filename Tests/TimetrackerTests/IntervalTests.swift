import Foundation
import Testing
@testable import Timetracker

@Test func unionMergesOverlapsAndDoesNotDoubleCount() {
    let ivs = [Interval(start: 0, end: 100), Interval(start: 50, end: 150), Interval(start: 200, end: 250), Interval(start: 240, end: 260)]
    #expect(ivs.union() == [Interval(start: 0, end: 150), Interval(start: 200, end: 260)])
    #expect(ivs.total == 210)
}

@Test func subtractingCutsMiddleAndEdges() {
    let base = [Interval(start: 0, end: 100)]
    #expect(base.subtracting([Interval(start: 40, end: 60)]) == [Interval(start: 0, end: 40), Interval(start: 60, end: 100)])
    #expect(base.subtracting([Interval(start: -10, end: 10), Interval(start: 90, end: 200)]) == [Interval(start: 10, end: 90)])
    #expect(base.subtracting([Interval(start: -1, end: 101)]) == [])
}

@Test func filledClosesShortGapsAndGapsReportsTheRest() {
    let ivs = [Interval(start: 0, end: 600), Interval(start: 900, end: 1200), Interval(start: 4800, end: 5000), Interval(start: 20000, end: 20100)]
    #expect(ivs.filled(maxGap: 1800) == [Interval(start: 0, end: 1200), Interval(start: 4800, end: 5000), Interval(start: 20000, end: 20100)])
    #expect(ivs.filled(maxGap: 1800).gaps(1800..<5400) == [Interval(start: 1200, end: 4800)])
    #expect(Day.time("2026-10-01", "8:00") == Day.interval("2026-10-01").start + 8 * 3600)
    #expect(Day.time("2026-10-01", "25:00") == nil)
}

@Test func roundingToQuarterAndHalfHour() {
    #expect(Report.round(5 * 3600 + 14 * 60, minutes: 30) == 5 * 3600)
    #expect(Report.round(5 * 3600 + 16 * 60, minutes: 30) == 5.5 * 3600)
    #expect(Report.round(7 * 60, minutes: 15) == 0)
    #expect(Report.round(8 * 60, minutes: 15) == 15 * 60)
}

@Test func summaryThresholdsDouble() {
    #expect(Summarizer.threshold(after: 0) == 1)
    #expect(Summarizer.threshold(after: 1) == 3)
    #expect(Summarizer.threshold(after: 3) == 6)
    #expect(Summarizer.threshold(after: 6) == 12)
    #expect(Summarizer.threshold(after: 12) == 24)
    #expect(Summarizer.threshold(after: 9) == 12)
}

@Test func activityGroupingMergesRevisitsAndUntitledRows() {
    func act(_ id: Int64, _ start: Double, _ end: Double, _ title: String) -> Activity {
        Activity(row: Row(values: ["id": id, "start": start, "end": end, "app": "Superset", "title": title, "project_id": Int64(1)]))
    }
    let groups = ActivityGroup.group([act(1, 0, 60, ""), act(2, 120, 300, "Team"), act(3, 400, 500, "Team"), act(4, 5000, 5100, "Team")])
    #expect(groups.count == 2)
    #expect(groups[0].items.map(\.id) == [1, 2, 3])
    #expect(groups[0].title == "Team")
    #expect(groups[0].duration == 340)
}

@Test func activityGroupingMergesFastSwitchingBetweenTwoWindows() {
    func act(_ id: Int64, _ app: String, _ start: Double, _ end: Double) -> Activity {
        Activity(row: Row(values: ["id": id, "start": start, "end": end, "app": app, "title": app, "project_id": Int64(1)]))
    }
    let groups = ActivityGroup.group([act(1, "A", 0, 60), act(2, "B", 60, 240), act(3, "A", 240, 300), act(4, "B", 300, 360), act(5, "A", 1000, 1060)])
    #expect(groups.map { $0.items.map(\.id) } == [[1, 3], [2, 4], [5]])
    #expect(groups[0].start == 0 && groups[0].end == 300 && groups[0].duration == 120)
}

@Test func transcriptReadsLastAiTitleAndUserMessages() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("tt-transcript-test.jsonl").path
    let lines = [
        #"{"type":"user","message":{"role":"user","content":"<command-name>/clear</command-name>"}}"#,
        #"{"type":"user","message":{"role":"user","content":"Import the worker list from xlsx"}}"#,
        #"{"type":"user","isMeta":true,"message":{"role":"user","content":"meta"}}"#,
        #"{"type":"ai-title","aiTitle":"Worker list"}"#,
        #"{"type":"user","message":{"role":"user","content":[{"type":"text","text":"now do a review"},{"type":"tool_result","content":"x"}]}}"#,
        #"{"type":"ai-title","aiTitle":"Worker list import implementation"}"#,
        "not json",
    ]
    try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    let t = try #require(Transcript.read(path: path))
    #expect(t.aiTitle == "Worker list import implementation")
    #expect(t.userMessages == ["Import the worker list from xlsx", "now do a review"])
    #expect(Transcript.defaultPath(sessionId: "abc", cwd: "/Users/x/my.proj").hasSuffix(".claude/projects/-Users-x-my-proj/abc.jsonl"))
}

@Test func claudeAppTitleShowsConversationAndMode() {
    #expect(WindowContext.claudeTitle("Acme - Claude Code") == "Acme (Code)")
    #expect(WindowContext.claudeTitle("Best todo app comparison - Claude") == "Best todo app comparison (Chat)")
    #expect(WindowContext.claudeTitle("Claude") == "Claude")
}

@Test func projectKeywordsMatchWholeWordsOnly() {
    let p = Project(row: Row(values: ["id": Int64(1), "name": "acme-api", "keywords": "acme, Jane", "billable": Int64(1), "rate": 40.0, "color": Int64(0), "hidden": Int64(0)]))
    #expect(p.match(in: "Acme (Code)") == "acme")
    #expect(p.match(in: "Screen Studio · Jane intro.mp4") == "Jane")
    #expect(p.match(in: "worker_list_parser.rb — acme-api (Workspace)") == "acme-api")
    #expect(p.match(in: "Janeway trip") == nil)
    #expect(p.match(in: "acme1 encoder") == nil)
}
