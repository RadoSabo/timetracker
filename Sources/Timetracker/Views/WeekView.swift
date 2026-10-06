import SwiftUI

/// The week: three figures (tracked, billable, personal), a project × day table, and seven day ribbons.
struct WeekView: View {
    @EnvironmentObject var store: Store
    @Binding var day: String
    @Binding var tab: Tab

    var body: some View {
        let _ = store.tick
        let ws = Day.weekStart(Day.date(day))
        let we = Calendar.current.date(byAdding: .day, value: 6, to: ws)!
        let days = (0..<7).map { Day.key(Calendar.current.date(byAdding: .day, value: $0, to: ws)!) }
        let projects = store.projects()
        let perDay = days.map { d in (day: d, time: store.projectTime(day: d)) }
        let dayTotals = perDay.map { $0.time.values.flatMap { $0 }.union().total }
        let byProject = Dictionary(uniqueKeysWithValues: projects.map { p in (p.id, perDay.reduce(0) { $0 + ($1.time[p.id]?.total ?? 0) }) })
        let active = projects.filter { byProject[$0.id]! > 0 }
        let reports = projects.filter(\.billable).map { Report.build(project: $0, from: ws, to: we) }.filter { !$0.days.isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DateNav(title: "\(Format.date(ws, "d MMMM")) – \(Format.date(we, "d MMMM"))",
                        subtitle: "Week \(Calendar.current.component(.weekOfYear, from: ws)) · \(dayTotals.filter { $0 > 0 }.count) days worked",
                        onShift: { day = Day.key(Calendar.current.date(byAdding: .weekOfYear, value: $0, to: Day.date(day))!) },
                        onToday: { day = Day.key(Date()) })
                HStack(spacing: 12) {
                    stat("Tracked", hm(dayTotals.reduce(0, +))) { SplitBar(parts: active.map { ($0.color, byProject[$0.id]!) }) }
                    billable(reports)
                    personal(active.filter { !$0.billable }, byProject)
                }
                Card { WeekTable(projects: active, perDay: perDay, dayTotals: dayTotals) }
                Card {
                    VStack(spacing: 0) {
                        axis
                        ForEach(perDay, id: \.day) { d in dayRow(d.day, d.time, projects) }
                    }
                }
            }
            .padding(Theme.gutter * 1.5)
        }
    }

    // MARK: figures
    private func stat<C: View>(_ title: String, _ value: String, @ViewBuilder _ sub: () -> C) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.label).foregroundStyle(Theme.muted)
                Text(value).font(.figure(26)).foregroundStyle(Theme.ink)
                sub()
            }
        }
    }
    private func billable(_ reports: [Report]) -> some View {
        let amount = reports.reduce(0) { $0 + $1.amount }
        let rounded = reports.reduce(0) { $0 + $1.totalSeconds }, exact = reports.reduce(0) { $0 + $1.days.reduce(0) { $0 + $1.exactSeconds } }
        let title = reports.count == 1 ? "Billable · \(reports[0].project.name)" : "Billable"
        return stat(title, Format.euro(amount, decimals: 2)) {
            Text(reports.isEmpty ? "no billable time" : "\(hm(rounded)) rounded from \(hm(exact))" + (reports.count == 1 ? " at \(Format.euro(reports[0].project.rate))/h" : ""))
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
    }
    private func personal(_ projects: [Project], _ byProject: [Int64: Seconds]) -> some View {
        stat("Personal", hm(projects.reduce(0) { $0 + byProject[$1.id]! })) {
            Text(projects.isEmpty ? "nothing" : projects.map(\.name).joined(separator: " · ") + " · not billed").font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
        }
    }

    // MARK: ribbons
    private func dayRow(_ d: String, _ time: [Int64: [Interval]], _ projects: [Project]) -> some View {
        let lanes = projects.filter { time[$0.id] != nil }
        let total = time.values.flatMap { $0 }.union().total
        let drafts = store.drafts(day: d).count
        let isToday = d == Day.key(Date())
        return HStack(alignment: .center, spacing: 18) {
            HStack(spacing: 6) {
                Text(Format.date(Day.date(d), "EEE d")).font(.system(size: 12, weight: isToday ? .bold : .semibold)).foregroundStyle(isToday ? Theme.accent : Theme.ink)
                if isToday { Text("Today").font(.system(size: 10)).foregroundStyle(Theme.accent) }
            }
            .frame(width: 96, alignment: .leading)
            GeometryReader { geo in
                VStack(spacing: 3) {
                    if lanes.isEmpty { Rectangle().fill(Theme.sunken).frame(height: 6) }
                    ForEach(lanes) { p in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Theme.sunken)
                            ForEach(Array(time[p.id]!.enumerated()), id: \.offset) { _, iv in
                                let x0 = xPos(iv.start, d, geo.size.width), x1 = xPos(iv.end, d, geo.size.width)
                                Rectangle().fill(p.color).frame(width: max(1.5, x1 - x0)).offset(x: x0)
                            }
                        }
                        .frame(height: 8).clipShape(RoundedRectangle(cornerRadius: 2)).help(p.name)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: max(20, CGFloat(lanes.count) * 11))
            HStack(spacing: 8) {
                if drafts > 0 { Label("\(drafts)", systemImage: "sparkles").font(.label).foregroundStyle(Theme.accent).help("\(drafts) AI drafts to review") }
                Text(total > 0 ? hm(total) : "–").font(.figure(13)).foregroundStyle(total > 0 ? Theme.ink : Theme.faint)
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.faint.opacity(0.6)).frame(height: 0.5) }
        .contentShape(Rectangle())
        .onTapGesture { day = d; tab = .day }
    }

    private var axis: some View {
        HStack(spacing: 18) {
            Spacer().frame(width: 96)
            GeometryReader { geo in
                ForEach([7, 9, 12, 15, 18, 21], id: \.self) { h in
                    Text(String(format: "%02d", h)).font(.figure(10, .regular)).foregroundStyle(Theme.muted)
                        .position(x: CGFloat(h - 7) / 14 * geo.size.width, y: 6)
                }
            }.frame(height: 12)
            Spacer().frame(width: 100)
        }
    }

    /// Weekly rows share a 7:00–21:00 axis so days line up vertically.
    private func xPos(_ ts: Seconds, _ d: String, _ width: CGFloat) -> CGFloat {
        let start = Day.interval(d).start + 7 * 3600
        return CGFloat(min(max(0, (ts - start) / (14 * 3600)), 1)) * width
    }
}
