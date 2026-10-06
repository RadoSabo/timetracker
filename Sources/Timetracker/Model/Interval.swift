import Foundation

typealias Seconds = Double

struct Interval: Hashable {
    var start: Seconds
    var end: Seconds
    var duration: Seconds { max(0, end - start) }
    func clipped(to day: Interval) -> Interval? {
        let s = max(start, day.start), e = min(end, day.end)
        return e > s ? Interval(start: s, end: e) : nil
    }
}

extension Array where Element == Interval {
    /// Merges overlapping intervals; result is sorted and disjoint.
    func union() -> [Interval] {
        let sorted = filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        var out: [Interval] = []
        for iv in sorted {
            if let last = out.last, iv.start <= last.end {
                out[out.count - 1].end = Swift.max(last.end, iv.end)
            } else { out.append(iv) }
        }
        return out
    }
    var total: Seconds { union().reduce(0) { $0 + $1.duration } }
    /// Closes gaps shorter than `maxGap` between consecutive intervals.
    func filled(maxGap: Seconds) -> [Interval] {
        var out: [Interval] = []
        for iv in union() {
            if let last = out.last, iv.start - last.end < maxGap { out[out.count - 1].end = iv.end } else { out.append(iv) }
        }
        return out
    }
    /// Gaps between consecutive intervals whose length falls in `range`.
    func gaps(_ range: Range<Seconds>) -> [Interval] {
        let u = union()
        return zip(u, u.dropFirst()).map { Interval(start: $0.end, end: $1.start) }.filter { range.contains($0.duration) }
    }
    /// Removes `other` from every interval in self.
    func subtracting(_ other: [Interval]) -> [Interval] {
        var result = union()
        for cut in other.union() {
            var next: [Interval] = []
            for iv in result {
                if cut.end <= iv.start || cut.start >= iv.end { next.append(iv); continue }
                if cut.start > iv.start { next.append(Interval(start: iv.start, end: cut.start)) }
                if cut.end < iv.end { next.append(Interval(start: cut.end, end: iv.end)) }
            }
            result = next
        }
        return result
    }
}
