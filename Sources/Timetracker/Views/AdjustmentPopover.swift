import SwiftUI

struct AdjustmentPopover: View {
    @EnvironmentObject var store: Store
    var task: TaskItem
    @Local var hoursText = ""
    @Local var note = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adjust \(task.name)").font(.headline)
            Text("Measured \(hm(task.trackedSeconds)). Enter how many hours to add or remove, for example 2 or -0.5. The change shows as hatched time.")
                .font(.caption).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            TextField("Hours", text: $hoursText).textFieldStyle(.roundedBorder)
            TextField("Why (optional)", text: $note).textFieldStyle(.roundedBorder)
            HStack {
                Button("Remove adjustment") { store.setAdjustment(task.id, seconds: 0, note: "") }
                Spacer()
                Button("Save adjustment") { store.setAdjustment(task.id, seconds: (Double(hoursText.replacingOccurrences(of: ",", with: ".")) ?? 0) * 3600, note: note) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding().frame(width: 320)
        .onAppear { hoursText = task.adjustment == 0 ? "" : String(task.adjustment / 3600); note = task.adjustmentNote }
    }
}
