import SwiftUI

struct ManualEntrySheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    var day: String
    @Local var start = Date()
    @Local var end = Date()
    @Local var projectId: Int64?
    @Local var taskId: Int64?
    @Local var note = ""

    var body: some View {
        let projects = store.projects()
        let tasks = store.tasks(day: day, rebuild: false).filter { $0.projectId == projectId }
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual entry").font(.title2)
            DatePicker("From", selection: $start, displayedComponents: [.date, .hourAndMinute])
            DatePicker("To", selection: $end, displayedComponents: [.date, .hourAndMinute])
            ProjectPicker(label: "Project", projects: projects, none: "—", selection: $projectId)
            Picker("Task", selection: $taskId) {
                Text("New task from note").tag(Int64?.none)
                ForEach(tasks) { t in Text(t.name).tag(Int64?.some(t.id)) }
            }
            TextField("Note / task name", text: $note)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") {
                    store.addManual(start: start.timeIntervalSince1970, end: end.timeIntervalSince1970, projectId: projectId!, note: note, taskId: taskId)
                    dismiss()
                }.keyboardShortcut(.defaultAction).disabled(projectId == nil || end <= start)
            }
        }
        .padding(20).frame(width: 420)
        .onAppear {
            let d = Calendar.current.startOfDay(for: Day.date(day))
            start = d.addingTimeInterval(9 * 3600); end = d.addingTimeInterval(10 * 3600)
            projectId = store.billableProjects().first?.id ?? projects.first?.id
        }
    }
}
