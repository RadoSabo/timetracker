import SwiftUI

/// Narrow Day timeline column: when a Claude Code agent was running and on which Task, even while another window
/// was in front.
struct AgentLane: View {
    var runs: [AgentRun]
    var scale: TimeScale
    var projectById: [Int64: Project]

    /// Runs of one session with short pauses between prompts become one bar.
    static func merge(_ runs: [AgentRun], maxGap: Seconds = 5 * 60) -> [AgentRun] {
        var out: [AgentRun] = []
        for r in runs.sorted(by: { $0.interval.start < $1.interval.start }) {
            if let i = out.indices.last(where: { out[$0].sessionId == r.sessionId }), r.interval.start - out[i].interval.end < maxGap {
                out[i].interval.end = max(out[i].interval.end, r.interval.end)
            } else { out.append(r) }
        }
        return out
    }

    var body: some View {
        let bars = Self.merge(runs)
        let lanes = TimeScale.pack(bars.map { ($0.interval.start, $0.interval.end) }, minHeight: 0).slots
        GeometryReader { geo in
            ForEach(bars.indices, id: \.self) { i in
                let w = geo.size.width / CGFloat(lanes[i].lanes)
                bar(bars[i]).frame(width: w - 2).offset(x: CGFloat(lanes[i].lane) * w)
            }
        }
    }

    private func bar(_ r: AgentRun) -> some View {
        let y = scale.y(r.interval.start), h = max(3, scale.y(r.interval.end) - y)
        let color = r.projectId.flatMap { projectById[$0]?.color } ?? Theme.muted
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.16))
            Rectangle().fill(color).frame(width: 3)
            if h >= 16 {
                Text(r.label).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.ink)
                    .lineLimit(max(1, Int(h / 13))).padding(.leading, 7).padding(.trailing, 3).padding(.top, 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .frame(height: h).offset(y: y)
        .help("\(r.label)\n\(clock(r.interval.start))–\(clock(r.interval.end))")
    }
}
