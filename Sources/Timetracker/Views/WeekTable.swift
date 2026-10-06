import SwiftUI

/// Project × day grid of the week's Project Time, with day totals that count overlapping time once.
struct WeekTable: View {
    var projects: [Project]
    var perDay: [(day: String, time: [Int64: [Interval]])]
    var dayTotals: [Seconds]

    var body: some View {
        let today = Day.key(Date())
        return VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    Text("Project").font(.label).foregroundStyle(Theme.muted).padding(.vertical, 8)
                    ForEach(perDay, id: \.day) { d in
                        VStack(spacing: 1) {
                            Text(Format.date(Day.date(d.day), "EEE")).font(.label).foregroundStyle(d.day == today ? Theme.accent : Theme.muted)
                            Text(Format.date(Day.date(d.day), "d")).font(.figure(10, .regular)).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 6).background(d.day == today ? Theme.accent.opacity(0.07) : .clear)
                    }
                    Text("Total").font(.label).foregroundStyle(Theme.muted).frame(width: 70, alignment: .trailing)
                }
                Divider().gridCellColumns(9)
                ForEach(projects) { p in
                    GridRow {
                        HStack(spacing: 8) {
                            ProjectDot(project: p)
                            Text(p.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink)
                            if p.billable { Text("billable").font(.system(size: 9, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 1).background(Capsule().fill(Theme.accent.opacity(0.12))).foregroundStyle(Theme.accent) }
                        }
                        .padding(.vertical, 8)
                        ForEach(perDay, id: \.day) { d in cell(d.time[p.id]?.total ?? 0, highlight: d.day == today) }
                        Text(hm(perDay.reduce(0) { $0 + ($1.time[p.id]?.total ?? 0) })).font(.figure(12)).foregroundStyle(Theme.ink).frame(width: 70, alignment: .trailing)
                    }
                    Divider().gridCellColumns(9)
                }
                GridRow {
                    Text("Day total").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink).padding(.vertical, 8)
                    ForEach(perDay.indices, id: \.self) { i in cell(dayTotals[i], highlight: perDay[i].day == today, bold: true) }
                    Text(hm(dayTotals.reduce(0, +))).font(.figure(13)).foregroundStyle(Theme.ink).frame(width: 70, alignment: .trailing)
                }
            }
            Text("Overlapping time between projects counts once in the day total.").font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
    }
    private func cell(_ s: Seconds, highlight: Bool, bold: Bool = false) -> some View {
        Text(s > 0 ? hm(s) : "–").font(.figure(12, bold ? .semibold : .regular)).foregroundStyle(s > 0 ? Theme.ink : Theme.faint)
            .frame(maxWidth: .infinity).padding(.vertical, 8).background(highlight ? Theme.accent.opacity(0.07) : .clear)
    }
}
