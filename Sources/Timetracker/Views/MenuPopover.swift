import SwiftUI

/// Menu bar popover: what is tracked right now, today's split per project, what waits for review, and the few commands.
struct MenuPopover: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) var openWindow

    var body: some View {
        let _ = store.tick
        TimelineView(.everyMinute) { _ in
            let day = Day.key(Date())
            let tasks = store.tasks(day: day)
            let time = store.projectTime(day: day, tasks: tasks)
            let projects = store.projects().filter { time[$0.id] != nil }
            let total = time.values.flatMap { $0 }.union().total
            let unassigned = store.activities(day: day).filter { $0.projectId == nil }.reduce(0) { $0 + $1.interval.duration }
            let drafts = store.drafts(day: day).count
            VStack(spacing: 8) {
                tracking
                Card(padding: 12) { today(total, projects, time) }
                if unassigned >= 60 || drafts > 0 { review(unassigned, drafts) }
                Card(padding: 12) { commands }
            }
            .padding(8).frame(width: 300).background(Theme.canvas)
        }
    }

    private var tracking: some View {
        let paused = store.trackingPaused
        let name = store.currentProjectName
        let live = !paused && !["Idle", "Unassigned", "—"].contains(name)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(paused ? "PAUSED" : live ? "TRACKING" : name.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Theme.warn)
                Spacer()
                Text(store.pausedUntil.map { "until \(clock($0))" } ?? "since \(clock(store.currentSince))").font(.figure(10, .regular)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(live ? name : "Nothing").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
                Text(hm(now() - store.currentSince)).font(.figure(22)).foregroundStyle(Theme.ink)
            }
            if !store.currentTaskName.isEmpty {
                Text("Claude Code — " + store.currentTaskName).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(2)
            }
            HStack(spacing: 6) {
                if store.pausedUntil != nil {
                    Button { Tracker.shared.resumeByUser() } label: { Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity) }
                } else {
                    Menu {
                        ForEach([15, 30, 60, 120], id: \.self) { m in
                            Button(m < 60 ? "\(m) minutes" : "\(m / 60) hour\(m > 60 ? "s" : "")") { Tracker.shared.pauseByUser(until: now() + Double(m) * 60) }
                        }
                        Button("Rest of today") { Tracker.shared.pauseByUser(until: Day.interval(Day.key(Date())).end) }
                    } label: { Label("Pause", systemImage: "pause.fill") }
                    .frame(maxWidth: .infinity)
                }
                Menu("Switch project…") {
                    ForEach(store.projects()) { p in Button(p.name) { Tracker.shared.switchProject(to: p.id) } }
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.warm))
    }

    private func today(_ total: Seconds, _ projects: [Project], _ time: [Int64: [Interval]]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
                Spacer()
                Text(hm(total)).font(.figure(18)).foregroundStyle(Theme.ink)
            }
            SplitBar(parts: projects.map { ($0.color, time[$0.id]?.total ?? 0) })
            ForEach(projects) { p in
                let s = time[p.id]?.total ?? 0
                HStack(spacing: 8) {
                    ProjectDot(project: p)
                    Text(p.name).font(.system(size: 12)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    if p.billable { Text(Format.euro(s / 3600 * p.rate, decimals: 2)).font(.figure(11, .regular)).foregroundStyle(Theme.muted) }
                    Text(hm(s)).font(.figure(11)).foregroundStyle(Theme.ink)
                }
            }
            if projects.isEmpty { Text("Nothing tracked yet today.").font(.system(size: 12)).foregroundStyle(Theme.muted) }
        }
    }

    private func review(_ unassigned: Seconds, _ drafts: Int) -> some View {
        let parts = [unassigned >= 60 ? "\(Int(unassigned / 60)) min unassigned" : nil, drafts > 0 ? "\(drafts) AI draft\(drafts == 1 ? "" : "s")" : nil].compactMap { $0 }
        return Button { open(tab: "Day") } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("To review").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(parts.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            .padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
        }
        .buttonStyle(.plain)
    }

    private var commands: some View {
        VStack(spacing: 2) {
            command("Open Timetracker", "⌘O", "o") { open(tab: nil) }
            command("Add time by hand…", "⌘N", "n") { open(tab: "Day"); NotificationCenter.default.post(name: .addManual, object: nil) }
            command("Quit", "⌘Q", "q") { NSApp.terminate(nil) }
        }
    }

    private func command(_ title: String, _ hint: String, _ key: Character, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title).font(.system(size: 12)).foregroundStyle(Theme.ink); Spacer(); Text(hint).font(.figure(10, .regular)).foregroundStyle(Theme.muted) }
                .padding(.vertical, 4).contentShape(Rectangle())
        }
        .buttonStyle(.plain).keyboardShortcut(KeyEquivalent(key))
    }

    private func open(tab: String?) {
        showMain(openWindow)
        if let tab { NotificationCenter.default.post(name: .selectTab, object: tab) }
    }
}
