import SwiftUI

/// The day as one horizontal strip: a lane per project (solid = tracked, hatched = manual, pale = closed gap,
/// Day Start stretch or billed Break), a dashed lane
/// for AI drafts, and a thin seismograph of every foreground window at the bottom.
struct DayRibbon: View {
    var day: String
    var tasks: [TaskItem]
    var projects: [Project]
    var time: [Int64: [Interval]]
    var drafts: [Draft]
    var activities: [Activity]
    var projectById: [Int64: Project]

    private let labelWidth: CGFloat = 120
    private let lane: CGFloat = 22
    private let gap: CGFloat = 6

    var body: some View {
        let d = Day.interval(day)
        let span = hourSpan(d)
        let lanes = projects.filter { p in tasks.contains { $0.projectId == p.id } }
        VStack(alignment: .leading, spacing: gap) {
            axis(span)
            ForEach(lanes) { p in row(p.name, color: p.color) { w in projectBlocks(p, span: span, width: w) } }
            if !drafts.isEmpty { row("AI drafts", color: Theme.accent) { w in draftBlocks(span: span, width: w) } }
            row("Windows", color: Theme.muted, height: 10) { w in activityTicks(span: span, width: w) }
            if lanes.isEmpty && drafts.isEmpty {
                Text("Nothing assigned yet. Raw activity is on the right; summarize the day to get drafts.")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.leading, labelWidth)
            }
        }
        .overlay(alignment: .topLeading) { nowLine(d, span: span) }
    }

    // MARK: layout helpers
    private func hourSpan(_ d: Interval) -> ClosedRange<Int> {
        let times = activities.map(\.interval) + tasks.flatMap(\.allIntervals)
        // Working hours are always shown; the axis grows only when activity falls outside them.
        let first = Int(((times.map(\.start).min() ?? d.start + 8 * 3600) - d.start) / 3600)
        let last = Int(ceil(((times.map(\.end).max() ?? d.start + 18 * 3600) - d.start) / 3600))
        return max(0, min(first, 8))...min(24, max(last + 1, 18))
    }
    private func x(_ ts: Seconds, _ span: ClosedRange<Int>, _ width: CGFloat) -> CGFloat {
        let start = Day.interval(day).start + Double(span.lowerBound) * 3600
        return CGFloat((ts - start) / (Double(span.count - 1) * 3600)) * width
    }

    private func row<Content: View>(_ title: String, color: Color, height: CGFloat? = nil, @ViewBuilder content: @escaping (CGFloat) -> Content) -> some View {
        HStack(spacing: 0) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(color == Theme.muted ? Theme.muted : Theme.ink)
                .lineLimit(1).frame(width: labelWidth, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.sunken)
                    content(geo.size.width)
                }
            }
            .frame(height: height ?? lane).clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private func axis(_ span: ClosedRange<Int>) -> some View {
        HStack(spacing: 0) {
            Spacer().frame(width: labelWidth)
            GeometryReader { geo in
                ForEach(Array(span), id: \.self) { h in
                    Text("\(h)").font(.figure(10, .regular)).foregroundStyle(Theme.muted)
                        .position(x: CGFloat(h - span.lowerBound) / CGFloat(span.count - 1) * geo.size.width, y: 6)
                }
            }.frame(height: 12)
        }
    }

    @ViewBuilder private func projectBlocks(_ p: Project, span: ClosedRange<Int>, width: CGFloat) -> some View {
        ForEach(Array((time[p.id] ?? []).enumerated()), id: \.offset) { _, iv in
            block(iv, span, width) { p.color.opacity(0.3) }.help("Billed as \(clock(iv.start))–\(clock(iv.end))")
        }
        ForEach(tasks.filter { $0.projectId == p.id }) { t in
            ForEach(Array(t.tracked.enumerated()), id: \.offset) { _, iv in block(iv, span, width) { p.color }.help("\(t.name)\n\(clock(iv.start))–\(clock(iv.end))") }
            ForEach(Array(t.manual.enumerated()), id: \.offset) { _, iv in block(iv, span, width) { Hatch(color: p.color) }.help("\(t.name), added by hand\n\(clock(iv.start))–\(clock(iv.end))") }
        }
    }

    private func draftBlocks(span: ClosedRange<Int>, width: CGFloat) -> some View {
        ForEach(drafts) { d in
            ForEach(Array(d.ranges.enumerated()), id: \.offset) { _, iv in
                block(iv, span, width) {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(projectById[d.projectId]?.color ?? Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                .help("Draft: \(d.name)\n\(clock(iv.start))–\(clock(iv.end))")
            }
        }
    }

    private func activityTicks(span: ClosedRange<Int>, width: CGFloat) -> some View {
        ForEach(activities.filter { $0.interval.duration >= 5 }) { a in
            block(a.interval, span, width, minWidth: 1) { a.projectId.flatMap { projectById[$0]?.color } ?? Theme.faint }
                .help("\(a.app) \(a.title)\n\(clock(a.interval.start))–\(clock(a.interval.end))")
        }
    }

    private func block<V: View>(_ iv: Interval, _ span: ClosedRange<Int>, _ width: CGFloat, minWidth: CGFloat = 2, @ViewBuilder fill: () -> V) -> some View {
        let x0 = x(iv.start, span, width), x1 = x(iv.end, span, width)
        return fill().frame(width: max(minWidth, x1 - x0)).clipShape(RoundedRectangle(cornerRadius: 2)).offset(x: x0)
    }

    @ViewBuilder private func nowLine(_ d: Interval, span: ClosedRange<Int>) -> some View {
        if Day.key(Date()) == day {
            GeometryReader { geo in
                let w = geo.size.width - labelWidth
                Rectangle().fill(Theme.ink).frame(width: 1.5).offset(x: labelWidth + x(now(), span, w))
            }
        }
    }
}
