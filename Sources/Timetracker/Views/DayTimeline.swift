import SwiftUI

/// Memory (what the tracker saw) and Timesheet (what gets billed) side by side on one vertical clock, so every
/// entry sits next to the windows it was built from. Selecting an entry lights up the memory it was built from.
struct DayTimeline: View {
    @EnvironmentObject var store: Store
    var day: String
    var tasks: [TaskItem]
    var projects: [Project]
    var projectById: [Int64: Project]
    var time: [Int64: [Interval]]
    var breaks: [Break]
    var drafts: [Draft]
    var activities: [Activity]
    var runs: [AgentRun]
    var onAddManual: () -> Void
    @Local var selected: Int64?
    @Local var onlyUnassigned = false
    @AppStorage("day.memoryShare") private var memoryShare = 0.5
    @AppStorage("day.agentWidth") private var agentWidth = 110.0
    @Local var dragBase: (memory: CGFloat, agent: CGFloat)?

    static let pxPerHour: CGFloat = 200
    private let axisWidth: CGFloat = 50
    private let columnGap: CGFloat = 16

    var body: some View {
        GeometryReader { geo in content(total: geo.size.width) }
    }

    @ViewBuilder private func content(total: CGFloat) -> some View {
        let w = widths(total)
        let shown = activities.filter { !onlyUnassigned || $0.projectId == nil }
        let entries = TimesheetEntry.build(tasks: tasks, drafts: drafts, breaks: breaks, fallback: Day.interval(day).start)
        let sheetWidth = total - 2 * Theme.gutter - axisWidth - 3 * columnGap - w.memory - w.agent
        let l = DayLayout(day: day, activities: shown, entries: entries, projectById: projectById,
                          memoryWidth: w.memory, sheetWidth: sheetWidth, pxPerHour: Self.pxPerHour)
        VStack(spacing: 0) {
            headers(w).padding(.horizontal, Theme.gutter).padding(.vertical, 12)
            ScrollView {
                ZStack(alignment: .topLeading) {
                    TimelineGrid(hours: l.hours, scale: l.scale).padding(.leading, axisWidth + columnGap)
                    HStack(alignment: .top, spacing: 0) {
                        TimelineAxis(firstHour: l.firstHour, hours: l.hours, scale: l.scale).frame(width: axisWidth)
                        Spacer().frame(width: columnGap)
                        lanes(l.memory, height: l.height) { i, h in
                            MemoryCard(block: l.groups[i], projects: projects, tasks: tasks, projectById: projectById, selected: selected, height: h, stacked: l.stacked[i])
                        }
                        .frame(width: w.memory)
                        SplitHandle(width: columnGap, onDrag: { drag($0, memorySide: true, total: total) }, onEnd: { dragBase = nil })
                        AgentLane(runs: runs, scale: l.scale, projectById: projectById).frame(width: w.agent, height: l.height)
                        SplitHandle(width: columnGap, onDrag: { drag($0, memorySide: false, total: total) }, onEnd: { dragBase = nil })
                        ZStack(alignment: .topLeading) {
                            lanes(l.sheet, height: l.height) { i, h in entryCard(l.entries[i], height: h) }
                            Button(action: onAddManual) {
                                Label("Add time by hand", systemImage: "plus").font(.label).frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            .buttonStyle(.plain).foregroundStyle(Theme.muted)
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.faint, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                            .offset(y: (l.sheet.map { $0.y + $0.h }.max() ?? 0) + 12)
                        }
                    }
                    if Day.key(Date()) == day { NowLine(scale: l.scale, leading: axisWidth + columnGap) }
                }
                .frame(height: l.height)
                .padding(.horizontal, Theme.gutter).padding(.top, 10).padding(.bottom, Theme.gutter)
            }
        }
    }

    /// Cards placed by DayLayout: side by side in their lane, at their clock position.
    private func lanes<C: View>(_ placed: [DayLayout.Placed], height: CGFloat, @ViewBuilder card: @escaping (Int, CGFloat) -> C) -> some View {
        GeometryReader { geo in
            ForEach(placed.indices, id: \.self) { i in
                let p = placed[i], w = geo.size.width / CGFloat(p.lanes)
                card(i, p.h).frame(width: w - 4, height: p.h, alignment: .topLeading).clipped().offset(x: CGFloat(p.lane) * w, y: p.y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .topLeading)
    }

    // MARK: layout
    /// Memory and Agent widths from the stored split; Timesheet takes the rest.
    private func widths(_ total: CGFloat) -> (memory: CGFloat, agent: CGFloat) {
        let avail = total - 2 * Theme.gutter - axisWidth - 3 * columnGap
        let agent = min(max(CGFloat(agentWidth), 60), 320)
        let memory = max(0, min(max((avail - agent) * CGFloat(memoryShare), 200), avail - agent - 240))
        return (memory, agent)
    }

    /// Dragging the Memory|Agent handle moves Memory's edge; the Agent|Timesheet one resizes Agent and keeps Memory.
    private func drag(_ dx: CGFloat, memorySide: Bool, total: CGFloat) {
        let current = widths(total), base = dragBase ?? current
        dragBase = base
        let avail = total - 2 * Theme.gutter - axisWidth - 3 * columnGap
        if !memorySide { agentWidth = Double(min(max(base.agent + dx, 60), 320)) }
        let memory = memorySide ? base.memory + dx : base.memory
        memoryShare = Double(memory / max(1, avail - CGFloat(agentWidth)))
    }
    // MARK: pieces
    private func headers(_ w: (memory: CGFloat, agent: CGFloat)) -> some View {
        HStack(alignment: .top, spacing: columnGap) {
            Spacer().frame(width: axisWidth)
            columnTitle("MEMORY", "recorded automatically") {
                let n = store.unassignedCount(day: day)
                Toggle(n > 0 ? "Unassigned (\(n))" : "Unassigned", isOn: $onlyUnassigned).toggleStyle(.checkbox).font(.label)
            }
            .frame(width: w.memory)
            Text("AGENT").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.ink).frame(width: w.agent, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                columnTitle("TIMESHEET", "what gets billed") { SummarizeControl(day: day) }
                HStack(spacing: 12) {
                    ForEach(projects.filter { time[$0.id]?.first != nil }) { p in DayStartButton(project: p, day: day, first: time[p.id]!.first!) }
                }
            }
        }
    }

    private func columnTitle<T: View>(_ title: String, _ sub: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.ink)
            Text("· " + sub).font(.label).foregroundStyle(Theme.muted)
            Spacer()
            trailing()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func entryCard(_ e: TimesheetEntry, height: CGFloat) -> some View {
        switch e.kind {
        case .task(let t): TaskCard(task: t, project: projectById[t.projectId], range: Interval(start: e.start, end: e.end), seconds: e.length, parts: e.parts, height: height, projects: projects, selected: $selected)
        case .draft(let d): DraftCard(draft: d, project: projectById[d.projectId], range: Interval(start: e.start, end: e.end), seconds: e.length, parts: e.parts, height: height)
        case .pause(let b): BreakCard(brk: b, project: projectById[b.projectId])
        }
    }
}
