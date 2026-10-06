import CoreGraphics

/// Clock → y for the Day timeline. Linear, but stretched wherever a card's minimum height is taller than its time
/// (or would push the next card in its column past its clock position), so every card ends at its end time and the axis,
/// grid and now line stay next to the cards. Each card grows over any stretch inside its time, so a stretch never shows
/// up as an empty gap.
struct TimeScale {
    /// `cols`: the layout columns the card covers; cards sharing a column stack, others may sit side by side.
    typealias Item = (start: Seconds, end: Seconds, minHeight: CGFloat, cols: Range<Int>)
    /// Packed cards: the scale items to lay out and, per card, its item index and horizontal slot.
    struct Packed { var items: [Item]; var slots: [(item: Int, lane: Int, lanes: Int)] }

    let origin: Seconds
    let pxPerHour: CGFloat
    /// Extra pixels inserted at a clock time; not in time order, a card's end can be stretched before later starts.
    private var stretch: [(at: Seconds, px: CGFloat)] = []
    /// One frame per item, in input order.
    private(set) var frames: [(y: CGFloat, h: CGFloat)] = []

    init(origin: Seconds, pxPerHour: CGFloat, items: [Item], gap: CGFloat = 4) {
        self.origin = origin; self.pxPerHour = pxPerHour
        let order = items.indices.sorted { (items[$0].start, $0) < (items[$1].start, $1) }
        // A card ends where the next one in any of its columns starts.
        var ends = items.map(\.end)
        for (k, i) in order.enumerated() {
            if let j = order[(k + 1)...].first(where: { items[$0].cols.overlaps(items[i].cols) }) {
                ends[i] = max(items[i].start, min(items[i].end, items[j].start))
            }
        }
        var ys = [CGFloat](repeating: 0, count: items.count)
        var floors = [CGFloat](repeating: 0, count: items.map(\.cols.upperBound).max() ?? 0)
        for i in order {
            let it = items[i], y = self.y(it.start), floor = it.cols.map { floors[$0] }.max() ?? 0
            if y < floor { stretch.append((it.start, floor - y)) }
            ys[i] = max(y, floor)
            let short = ys[i] + it.minHeight + gap - self.y(ends[i])
            if it.minHeight > 0, ends[i] > it.start, short > 0 { stretch.append((ends[i], short)) }
            let h = max(it.minHeight, CGFloat((ends[i] - it.start) / 3600) * pxPerHour)
            for c in it.cols { floors[c] = ys[i] + h + (h > 0 ? gap : 0) }
        }
        frames = items.indices.map { i in (ys[i], max(items[i].minHeight, self.y(ends[i]) - ys[i] - gap)) }
    }

    func y(_ t: Seconds) -> CGFloat {
        CGFloat((t - origin) / 3600) * pxPerHour + stretch.reduce(0) { $0 + ($1.at <= t ? $1.px : 0) }
    }

    /// Side-by-side packing like a calendar, in layout columns from `colOffset`: cards overlapping in time form a cluster split into equal lanes (first fit).
    /// A zero-height barrier item opens each cluster so it starts below the previous one.
    static func pack(_ spans: [(start: Seconds, end: Seconds)], minHeight: CGFloat, colOffset: Int = 0) -> Packed {
        var lanes: [Int] = [], laneEnds: [Seconds] = [], clusterOf: [Int] = [], clusterLanes: [Int] = []
        var clusterEnd = -Double.infinity
        for s in spans {
            if s.start >= clusterEnd { clusterLanes.append(0); laneEnds = [] }
            let lane = laneEnds.firstIndex { $0 <= s.start } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(s.end) } else { laneEnds[lane] = s.end }
            clusterEnd = s.start >= clusterEnd ? s.end : max(clusterEnd, s.end)
            lanes.append(lane); clusterOf.append(clusterLanes.count - 1)
            clusterLanes[clusterLanes.count - 1] = max(clusterLanes.last!, lane + 1)
        }
        let cols = clusterLanes.max() ?? 0
        var items: [Item] = [], slots: [(item: Int, lane: Int, lanes: Int)] = []
        for (i, s) in spans.enumerated() {
            if i == 0 || clusterOf[i] != clusterOf[i - 1] { items.append((s.start, s.start, 0, colOffset..<colOffset + cols)) }
            slots.append((items.count, lanes[i], clusterLanes[clusterOf[i]]))
            items.append((s.start, s.end, minHeight, colOffset + lanes[i]..<colOffset + lanes[i] + 1))
        }
        return Packed(items: items, slots: slots)
    }
}
