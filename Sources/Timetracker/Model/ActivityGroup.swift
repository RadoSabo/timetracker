import Foundation

/// Consecutive activities in the same window and project, shown as one Memory row.
struct ActivityGroup: Identifiable {
    var items: [Activity]
    var title: String
    var id: Int64 { items[0].id }
    var first: Activity { items[0] }
    var duration: Seconds { items.reduce(0) { $0 + $1.interval.duration } }
    var start: Seconds { items.map(\.interval.start).min()! }
    var end: Seconds { items.map(\.interval.end).max()! }

    /// Gaps up to `maxGap` seconds between two visits keep them in one group; when another window was visited in
    /// between, the gap must be under `switchGap` (fast A-B-A-B switching = working in both). An empty title (recorded
    /// before Accessibility was granted) matches any title of the same app.
    static func group(_ acts: [Activity], maxGap: Seconds = 20 * 60, switchGap: Seconds = 5 * 60) -> [ActivityGroup] {
        var out: [ActivityGroup] = []
        for a in acts {
            let match = out.indices.last { i in
                let g = out[i]
                return g.first.app == a.app && g.first.url == a.url && g.first.projectId == a.projectId
                    && (g.title == a.title || g.title.isEmpty || a.title.isEmpty)
                    && a.interval.start - g.end < (i == out.count - 1 ? maxGap : switchGap)
            }
            if let i = match {
                if out[i].title.isEmpty { out[i].title = a.title }
                out[i].items.append(a)
            } else {
                out.append(ActivityGroup(items: [a], title: a.title))
            }
        }
        return out
    }
}

/// Groups of one app and project close in time, shown as one Memory card: a stretch in that app.
struct MemoryBlock: Identifiable {
    var groups: [ActivityGroup]
    var id: Int64 { groups[0].id }
    var items: [Activity] { groups.flatMap(\.items) }
    var first: Activity { groups[0].first }
    var start: Seconds { groups.map(\.start).min()! }
    var end: Seconds { groups.map(\.end).max()! }
    var duration: Seconds { groups.reduce(0) { $0 + $1.duration } }
    /// Window titles in the block, the first one first, then the longest; deduplicated, the bare app name skipped.
    var titles: [String] {
        var seen: Set<String> = [first.app, ""]
        return ([groups[0]] + groups.dropFirst().sorted { $0.duration > $1.duration }).compactMap { seen.insert($0.title).inserted ? $0.title : nil }
    }

    /// One card per app and project: its groups close in time stay together even when other apps were used in between.
    static func byApp(_ groups: [ActivityGroup], maxGap: Seconds = 5 * 60) -> [MemoryBlock] {
        var out: [MemoryBlock] = []
        for g in groups {
            if let i = out.indices.last(where: { out[$0].first.app == g.first.app && out[$0].first.projectId == g.first.projectId }), g.start - out[i].end < maxGap {
                out[i].groups.append(g)
            } else { out.append(MemoryBlock(groups: [g])) }
        }
        return out
    }
}
