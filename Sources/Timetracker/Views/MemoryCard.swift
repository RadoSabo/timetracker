import SwiftUI

/// One stretch of windows in the Memory column; the project label opens reassignment.
struct MemoryCard: View {
    @EnvironmentObject var store: Store
    var block: MemoryBlock
    var projects: [Project]
    var tasks: [TaskItem]
    var projectById: [Int64: Project]
    var selected: Int64?
    /// Card height on the timeline; window titles fill whatever is left below the header rows.
    var height: CGFloat
    /// Time range and project on separate rows: they don't fit side by side at this width.
    var stacked = false

    /// Header rows plus one line of window titles, which always sit below the project.
    static func minHeight(stacked: Bool) -> CGFloat { stacked ? 77 : 61 }

    static func stacked(project: String?, width: CGFloat) -> Bool {
        let projectWidth = ((project ?? "No project") as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]).width
        return 16 + 80 + 6 + projectWidth > width
    }

    var body: some View {
        let a = block.first
        let project = a.projectId.flatMap { projectById[$0] }
        let mine = selected != nil && block.items.contains { $0.taskId == selected }
        let titles = block.titles
        let lines = 1 + max(0, Int((height - Self.minHeight(stacked: stacked)) / 14))
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                AppIcon(app: a.app, size: 14)
                Text(a.app).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer(minLength: 4)
                Text(hm(block.duration)).font(.figure(11)).foregroundStyle(Theme.ink).fixedSize().layoutPriority(1)
            }
            let range = Text("\(clock(block.start))–\(clock(block.end))").font(.figure(10, .regular)).foregroundStyle(Theme.muted).fixedSize()
            if stacked {
                range
                assignMenu(project)
            } else {
                HStack(spacing: 6) { range; assignMenu(project) }
            }
            if !titles.isEmpty {
                Text(titles.joined(separator: " · ")).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(lines)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(mine ? Theme.accent.opacity(0.1) : Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(mine ? Theme.accent : (project?.color ?? Theme.faint).opacity(0.5), lineWidth: mine ? 1.5 : 1))
        .opacity(selected != nil && !mine ? 0.4 : 1)
        .clipped()
        .help(block.groups.map { "\($0.first.app) · \($0.title) \(clock($0.start))–\(clock($0.end))" }.joined(separator: "\n"))
    }

    private func assignMenu(_ project: Project?) -> some View {
        Menu {
            Section("Move to project") {
                ForEach(projects) { p in Button(p.name) { block.items.forEach { store.setActivityProject($0.id, projectId: p.id) } } }
                Button("No project") { block.items.forEach { store.setActivityProject($0.id, projectId: nil) } }
            }
            Section("Add to task") {
                ForEach(tasks) { t in Button(t.name) { block.items.forEach { store.setActivityTask($0.id, taskId: t.id) } } }
            }
            Divider()
            Button("Delete", role: .destructive) { block.items.forEach { store.deleteActivity($0.id) } }
        } label: {
            Text(project?.name ?? "No project").font(.label).foregroundStyle(project == nil ? Theme.warn : (project?.color ?? Theme.muted))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }
}
