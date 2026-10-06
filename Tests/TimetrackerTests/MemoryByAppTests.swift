import Testing
@testable import Timetracker

@Test func memoryCardsFollowOneAppAcrossInterleavedSwitches() {
    func act(_ id: Int64, _ app: String, _ start: Double, _ end: Double) -> Activity {
        Activity(row: Row(values: ["id": id, "start": start, "end": end, "app": app, "title": "\(app) \(id)", "project_id": Int64(1)]))
    }
    let acts = [act(1, "Chrome", 0, 100), act(2, "Cursor", 100, 200), act(3, "Chrome", 200, 300), act(4, "Cursor", 300, 400), act(5, "Chrome", 2000, 2100)]
    let blocks = MemoryBlock.byApp(ActivityGroup.group(acts, switchGap: 0))
    #expect(blocks.map { $0.items.map(\.id) } == [[1, 3], [2, 4], [5]])
}

@Test func agentRunsOfOneSessionMergeAcrossShortPauses() {
    func run(_ s: String, _ start: Double, _ end: Double) -> AgentRun { AgentRun(interval: Interval(start: start, end: end), sessionId: s, projectId: 1, label: s) }
    let bars = AgentLane.merge([run("a", 0, 60), run("b", 30, 90), run("a", 200, 260), run("a", 1000, 1060)])
    #expect(bars.map(\.sessionId) == ["a", "b", "a"])
    #expect(bars[0].interval == Interval(start: 0, end: 260))
}
