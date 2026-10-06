import SwiftUI

struct DayView: View {
    @EnvironmentObject var store: Store
    @Binding var day: String
    @Local var showManual = false

    var body: some View {
        let _ = store.tick
        let tasks = store.tasks(day: day)
        let projects = store.projects()
        let byId = Dictionary(uniqueKeysWithValues: store.projects(includeHidden: true).map { ($0.id, $0) })
        let time = store.projectTime(day: day, tasks: tasks)
        let breaks = store.breaks(day: day, tasks: tasks)
        let activities = store.activities(day: day)
        let total = time.values.flatMap { $0 }.union().total
        let billable = projects.filter(\.billable).reduce(0.0) { $0 + (time[$1.id]?.total ?? 0) / 3600 * $1.rate }
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                DateNav(title: Format.date(Day.date(day), "EEEE d MMMM"),
                        subtitle: "\(hm(total)) tracked" + (billable > 0 ? ", \(Format.euro(billable)) billable" : ""),
                        onShift: { day = Day.key(Calendar.current.date(byAdding: .day, value: $0, to: Day.date(day))!) },
                        onToday: { day = Day.key(Date()) })
                DayRibbon(day: day, tasks: tasks, projects: projects, time: time, drafts: store.drafts(day: day), activities: activities, projectById: byId)
            }
            .padding(Theme.gutter)
            .background(Theme.surface)
            DayTimeline(day: day, tasks: tasks, projects: projects, projectById: byId, time: time, breaks: breaks,
                        drafts: store.drafts(day: day), activities: activities, runs: store.agentRuns(day: day), onAddManual: { showManual = true })
        }
        .sheet(isPresented: $showManual) { ManualEntrySheet(day: day) }
        .onReceive(NotificationCenter.default.publisher(for: .addManual)) { _ in day = Day.key(Date()); showManual = true }
    }
}
