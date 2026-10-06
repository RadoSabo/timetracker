import AppKit

/// Where everything sits on the Day timeline: Memory cards and Timesheet entries packed side by side when they overlap,
/// all on one TimeScale so both columns, the axis and the now line share a clock.
struct DayLayout {
    struct Placed { var lane: Int; var lanes: Int; var y: CGFloat; var h: CGFloat }

    let groups: [MemoryBlock]
    /// Memory card too narrow for time range and project on one row.
    let stacked: [Bool]
    let memory: [Placed]
    let entries: [TimesheetEntry]
    let sheet: [Placed]
    let scale: TimeScale
    let firstHour: Int
    let hours: Int
    let height: CGFloat

    init(day: String, activities: [Activity], entries: [TimesheetEntry], projectById: [Int64: Project],
         memoryWidth: CGFloat, sheetWidth: CGFloat, pxPerHour: CGFloat) {
        let d = Day.interval(day)
        let groups = MemoryBlock.byApp(ActivityGroup.group(activities)).filter { $0.duration >= Settings.minMemoryCardSeconds }
        let (first, hours) = Self.span(d, today: Day.key(Date()) == day, starts: groups.map(\.start) + entries.map(\.start), ends: groups.map(\.end) + entries.map(\.end))

        var mem = TimeScale.pack(groups.map { ($0.start, $0.end) }, minHeight: MemoryCard.minHeight(stacked: false))
        let stacked = groups.indices.map { i in
            MemoryCard.stacked(project: groups[i].first.projectId.flatMap { projectById[$0]?.name }, width: memoryWidth / CGFloat(mem.slots[i].lanes) - 4)
        }
        for i in groups.indices where stacked[i] { mem.items[mem.slots[i].item].minHeight = MemoryCard.minHeight(stacked: true) }

        var ts = TimeScale.pack(entries.map { ($0.start, $0.end) }, minHeight: 0, colOffset: mem.slots.map(\.lanes).max() ?? 0)
        for (i, slot) in ts.slots.enumerated() { ts.items[slot.item].minHeight = entries[i].minHeight(width: sheetWidth / CGFloat(slot.lanes) - 4) }

        let origin = d.start + Double(first) * 3600
        let scale = TimeScale(origin: origin, pxPerHour: pxPerHour, items: mem.items + ts.items)
        let offset = mem.items.count
        let memory = mem.slots.map { Placed(lane: $0.lane, lanes: $0.lanes, y: scale.frames[$0.item].y, h: scale.frames[$0.item].h) }
        let sheet = ts.slots.map { Placed(lane: $0.lane, lanes: $0.lanes, y: scale.frames[offset + $0.item].y, h: scale.frames[offset + $0.item].h) }
        let bottom = (memory + sheet).map { $0.y + $0.h }.max() ?? 0
        self.groups = groups; self.stacked = stacked; self.memory = memory; self.entries = entries; self.sheet = sheet
        self.scale = scale; self.firstHour = first; self.hours = hours
        self.height = max(scale.y(origin + Double(hours) * 3600), bottom) + 70
    }

    /// First hour shown and how many: from the earliest record (8:00 at the latest) to an hour past the last one or now.
    private static func span(_ d: Interval, today: Bool, starts: [Seconds], ends: [Seconds]) -> (Int, Int) {
        var last = ends.max() ?? d.start + 17 * 3600
        if today { last = max(last, now()) }
        let first = max(0, min(8, Int(((starts.min() ?? d.start + 8 * 3600) - d.start) / 3600)))
        return (first, min(24 - first, Int(ceil((last - d.start) / 3600)) + 1 - first))
    }
}
