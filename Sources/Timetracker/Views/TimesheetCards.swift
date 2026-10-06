import SwiftUI

/// Card title lines: one, plus one per ~15 px the card is taller than the narrow (stacked) minimum, at most three.
private func nameLines(_ height: CGFloat) -> Int { min(3, 1 + max(0, Int((height - 80) / 15))) }

private func timeRange(_ r: Interval) -> some View {
    Text("\(clock(r.start))–\(clock(r.end))").font(.figure(10, .regular)).foregroundStyle(Theme.muted).fixedSize()
}

/// One stretch of a task on the clock; a task split into several stretches shows this one's time and the total.
struct TaskCard: View {
    @EnvironmentObject var store: Store
    var task: TaskItem
    var project: Project?
    var range: Interval
    var seconds: Seconds
    var parts: Int
    var height: CGFloat
    var projects: [Project]
    @Binding var selected: Int64?
    @Local var adjusting = false
    @Local var renaming = false
    @Local var name = ""

    var body: some View {
        let on = selected == task.id
        let color = project?.color ?? Theme.accent
        // Wide: title and time on one row. Narrow: time and menu on top, the title gets the full width below.
        ViewThatFits(in: .horizontal) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) { title.lineLimit(1); Spacer(minLength: 4); duration; menu }
                HStack(spacing: 6) { timeRange(range); projectLabel }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) { duration; Spacer(minLength: 0); menu }
                title.lineLimit(nameLines(height))
                timeRange(range)
                projectLabel
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(color.opacity(on ? 0.16 : 0.08)))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(on ? Theme.accent : color.opacity(0.35), lineWidth: on ? 1.5 : 1))
        .contentShape(Rectangle())
        .onTapGesture { selected = on ? nil : task.id }
        .popover(isPresented: $adjusting) { AdjustmentPopover(task: task) }
        .popover(isPresented: $renaming) {
            TextField("Entry name", text: $name).textFieldStyle(.roundedBorder).frame(width: 280).padding()
                .onSubmit { store.renameTask(task.id, name); renaming = false }
        }
        .help(task.name)
    }

    private var title: some View {
        (Text(task.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
         + (task.sessionId != nil ? Text(" ") + Text(Image(systemName: "sparkles")) : Text("")).font(.system(size: 9)).foregroundStyle(Theme.muted))
    }

    private var duration: some View {
        (Text(hm(parts > 1 ? seconds : task.totalSeconds)).font(.figure(12)).foregroundStyle(Theme.ink)
         + Text(parts > 1 ? " / \(hm(task.totalSeconds))" : "").font(.figure(10, .regular)).foregroundStyle(Theme.muted))
            .fixedSize()
    }

    private var projectLabel: some View {
        HStack(spacing: 6) {
            Text(project?.name ?? "?").font(.label).foregroundStyle(project?.color ?? Theme.accent).lineLimit(1)
            if task.manualSeconds != 0 { OriginMark(origin: .manual, seconds: task.manualSeconds, color: project?.color ?? Theme.accent) }
        }
    }

    private var menu: some View {
        Menu {
            Button("Rename") { name = task.name; renaming = true }
            Button("Adjust hours…") { adjusting = true }
            Menu("Move to project") {
                ForEach(projects.filter { $0.id != task.projectId }) { q in Button(q.name) { store.moveTask(task.id, toProject: q.id) } }
            }
            Divider()
            Button("Delete entry", role: .destructive) { store.deleteTask(task.id) }
        } label: { Image(systemName: "ellipsis").foregroundStyle(Theme.muted) }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 18)
    }
}

/// One stretch of an AI draft: dashed, not billed until approved (approving takes the whole draft).
struct DraftCard: View {
    @EnvironmentObject var store: Store
    var draft: Draft
    var project: Project?
    var range: Interval
    var seconds: Seconds
    var parts: Int
    var height: CGFloat
    var body: some View {
        let color = project?.color ?? Theme.accent
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(draft.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(nameLines(height))
                Spacer(minLength: 4)
                (Text(hm(seconds)).font(.figure(12, .regular)).foregroundStyle(Theme.muted)
                 + Text(parts > 1 ? " / \(hm(draft.seconds))" : "").font(.figure(10, .regular)).foregroundStyle(Theme.muted))
                    .fixedSize().layoutPriority(1)
            }
            HStack(spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { timeRange(range); Text(project?.name ?? "?").font(.label).foregroundStyle(color).lineLimit(1) }
                    timeRange(range)
                }
                Spacer(minLength: 0)
                Button { store.approve(draft) } label: { Image(systemName: "checkmark") }.buttonStyle(.borderedProminent).tint(Theme.ink).controlSize(.mini).layoutPriority(1)
                Button { store.dismiss(draft) } label: { Image(systemName: "xmark") }.buttonStyle(.bordered).controlSize(.mini).layoutPriority(1)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(color.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
        .help("Draft, not billed until approved. " + (draft.description.isEmpty ? draft.name : draft.description))
    }
}

struct BreakCard: View {
    @EnvironmentObject var store: Store
    var brk: Break
    var project: Project?
    var body: some View {
        let bill = Toggle("Bill it", isOn: Binding(get: { brk.billable }, set: { store.setBreakBillable(brk, $0) })).toggleStyle(.checkbox).font(.label).fixedSize()
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("Break").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer(minLength: 4)
                Text(hm(brk.interval.duration)).font(.figure(11)).foregroundStyle(brk.billable ? Theme.ink : Theme.muted).fixedSize()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { timeRange(brk.interval); Spacer(minLength: 4); bill }
                VStack(alignment: .leading, spacing: 3) { timeRange(brk.interval); bill }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(brk.billable ? (project?.color ?? Theme.accent).opacity(0.3) : .clear))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.faint, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}

/// "acme-api from 08:32": click to set when the day really started; the first interval stretches back to it.
struct DayStartButton: View {
    @EnvironmentObject var store: Store
    var project: Project
    var day: String
    var first: Interval
    @Local var editing = false
    @Local var text = ""
    var body: some View {
        let custom = store.dayStart(project.id, day: day) != nil
        Button("\(project.name) from \(clock(first.start))") { text = clock(first.start); editing = true }
            .buttonStyle(.plain).font(.figure(11, .regular)).foregroundStyle(custom ? Theme.accent : Theme.muted)
            .help("Set the time you started working on \(project.name)")
            .popover(isPresented: $editing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Started working at").font(.headline)
                    TextField("HH:mm", text: $text).textFieldStyle(.roundedBorder)
                        .onSubmit { store.setDayStart(project.id, day: day, start: Day.time(day, text)); editing = false }
                    HStack {
                        Button("Use measured") { store.setDayStart(project.id, day: day, start: nil); editing = false }
                        Spacer()
                        Button("Save") { store.setDayStart(project.id, day: day, start: Day.time(day, text)); editing = false }.keyboardShortcut(.defaultAction)
                    }
                }
                .padding().frame(width: 220)
            }
    }
}
