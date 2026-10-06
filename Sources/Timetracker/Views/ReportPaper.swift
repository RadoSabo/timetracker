import SwiftUI

/// The time report as a sheet of paper: per day the tasks, measured and billed hours, then the total and amount.
struct ReportPaper: View {
    @EnvironmentObject var store: Store
    var report: Report
    @Binding var tab: Tab
    @Binding var day: String

    var body: some View {
        let r = report
        let exact = r.days.reduce(0) { $0 + $1.exactSeconds }
        let today = Day.key(Date())
        let unreviewed = Day.keys(from: r.from, to: r.to).contains(today)
            ? store.activities(day: today).filter { $0.projectId == nil }.reduce(0) { $0 + $1.interval.duration } : 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME REPORT").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Theme.muted)
                    Text(r.project.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("\(Format.date(r.from, "d MMMM")) – \(Format.date(r.to, "d MMMM yyyy"))").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.euro(r.amount, decimals: 2)).font(.figure(30)).foregroundStyle(Theme.ink)
                    Text("\(hoursShort(r.totalSeconds)) × \(Format.euro(r.project.rate))").font(.figure(11, .regular)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.bottom, 20)
            tableHeader.padding(.bottom, 6).overlay(alignment: .bottom) { Rectangle().fill(Theme.ink).frame(height: 1) }
            if r.days.isEmpty { Text("No billable time in this period.").foregroundStyle(Theme.muted).padding(.vertical, 14) }
            ForEach(r.days, id: \.day) { d in dayRow(d) }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Total").font(.system(size: 12, weight: .semibold)).frame(width: 90, alignment: .leading)
                Text(Settings.roundingMinutes > 0 ? "Days rounded to \(Settings.roundingMinutes) min" : "Exact minutes").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Text(hm(exact)).font(.figure(11, .regular)).foregroundStyle(Theme.muted).frame(width: 70, alignment: .trailing)
                Text(hoursShort(r.totalSeconds)).font(.figure(13)).foregroundStyle(Theme.ink).frame(width: 60, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(Theme.ink).frame(height: 1) }
            if unreviewed >= 60 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(Theme.warn)
                    Text("\(Int(unreviewed / 60)) minutes today are still unassigned and not included.").font(.system(size: 12)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button("Review") { day = today; tab = .day }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).underline()
                }
                .padding(10).background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.warm))
            }
        }
        .padding(28)
        .frame(maxWidth: 560)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface).shadow(color: .black.opacity(0.08), radius: 12, y: 4))
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("DAY").frame(width: 90, alignment: .leading)
            Text("WORK")
            Spacer()
            Text("MEASURED").frame(width: 70, alignment: .trailing)
            Text("BILLED").frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
    }

    private func dayRow(_ d: Report.DayLine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(Format.date(Day.date(d.day), "EEE d MMM")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink).frame(width: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(d.tasks) { t in
                    HStack(spacing: 8) {
                        Text(t.name).font(.system(size: 12)).foregroundStyle(Theme.ink).lineLimit(2)
                        Spacer()
                        Text(hm(t.totalSeconds)).font(.figure(10, .regular)).foregroundStyle(Theme.muted)
                    }
                }
            }
            Text(hm(d.exactSeconds)).font(.figure(11, .regular)).foregroundStyle(Theme.muted).frame(width: 70, alignment: .trailing)
            Text(hoursShort(d.roundedSeconds)).font(.figure(13)).foregroundStyle(Theme.ink).frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.faint.opacity(0.6)).frame(height: 0.5) }
    }

    private func hoursShort(_ s: Seconds) -> String {
        let h = s / 3600
        return h == h.rounded() ? String(format: "%.0f h", h) : String(format: "%.2f h", h).replacingOccurrences(of: "0 h", with: " h")
    }
}
