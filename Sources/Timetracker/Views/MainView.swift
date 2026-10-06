import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", raw = "Raw", invoice = "Invoice", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self { case .day: "sun.max"; case .week: "calendar"; case .raw: "list.bullet"; case .invoice: "doc.text"; case .settings: "gearshape" }
    }
}

extension Notification.Name {
    static let selectTab = Notification.Name("selectTab")
    static let addManual = Notification.Name("addManual")
}

struct MainView: View {
    @EnvironmentObject var store: Store
    @Local var tab: Tab = .day
    @Local var day: String = Day.key(Date())

    var body: some View {
        NavigationSplitView {
            Sidebar(tab: $tab, day: $day).navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                IssuesBanner(tab: $tab)
                switch tab {
                case .day: DayView(day: $day)
                case .week: WeekView(day: $day, tab: $tab)
                case .raw: RawView(day: $day)
                case .invoice: ReportView(tab: $tab, day: $day)
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.canvas)
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectTab)) { n in
            if let t = (n.object as? String).flatMap(Tab.init(rawValue:)) { tab = t }
        }
    }
}

/// Navigation plus a live glance at today: what is running now and each project's time so far.
struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var tab: Tab
    @Binding var day: String

    var body: some View {
        let _ = store.tick
        let today = Day.key(Date())
        let time = store.projectTime(day: today)
        VStack(alignment: .leading, spacing: 0) {
            List(selection: Binding(get: { tab }, set: { if let t = $0 { tab = t } })) {
                ForEach(Tab.allCases) { t in Label(t.rawValue, systemImage: t.icon).tag(t) }
            }
            .listStyle(.sidebar)
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 10) {
                Text("Today").font(.label).foregroundStyle(Theme.muted)
                Text(hm(time.values.reduce(0) { $0 + $1.total })).font(.figure(30)).foregroundStyle(Theme.ink)
                ForEach(store.projects().filter { time[$0.id] != nil }) { p in
                    HStack(spacing: 8) {
                        ProjectDot(project: p)
                        Text(p.name).font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Text(hm(time[p.id]!.total)).font(.figure(11, .regular)).foregroundStyle(Theme.muted)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)
            .contentShape(Rectangle())
            .onTapGesture { day = today; tab = .day }

            Spacer()
            NowStatus().padding(16)
        }
    }
}

struct NowStatus: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let _ = store.tick
        VStack(alignment: .leading, spacing: 6) {
            Text("Now").font(.label).foregroundStyle(Theme.muted)
            Text(store.currentProjectName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            if !store.currentTaskName.isEmpty { Text(store.currentTaskName).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(2) }
            if !store.runningSessions().isEmpty { Chip(text: "Claude is working", color: Theme.accent) }
            if Tracker.shared.meetings.inTeamsCall { Chip(text: "In a call", color: Project.palette[3]) }
        }
    }
}
