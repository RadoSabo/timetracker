import SwiftUI

/// "Summarize day" with its running state and last error; the drafts it produces are cards in the Timesheet column.
struct SummarizeControl: View {
    @EnvironmentObject var store: Store
    @ObservedObject var summary = DaySummary.shared
    var day: String

    var body: some View {
        let drafts = store.drafts(day: day)
        HStack(spacing: 8) {
            if let err = summary.lastError[day] {
                Text(err).font(.system(size: 11)).foregroundStyle(Theme.warn).lineLimit(1).help(err)
            }
            if summary.running.contains(day) {
                ProgressView().controlSize(.small)
                Text("Reading the day…").font(.label).foregroundStyle(Theme.muted)
            } else {
                if drafts.count > 1 { Button("Approve all") { store.approveAll(drafts) }.controlSize(.small) }
                Button(drafts.isEmpty ? "Summarize day" : "Summarize again") { summary.summarize(day: day) }
                    .controlSize(.small).buttonStyle(.borderedProminent).tint(Theme.accent)
            }
        }
    }
}
