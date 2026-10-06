import SwiftUI

/// Every activity row of the day as stored, no grouping or minimum length. Select rows and delete them for good.
struct RawView: View {
    @EnvironmentObject var store: Store
    @Binding var day: String
    @Local var selection = Set<Int64>()
    @Local var sortOrder = [KeyPathComparator(\Activity.interval.start)]

    var body: some View {
        let _ = store.tick
        let acts = store.activities(day: day).sorted(using: sortOrder)
        let byId = Dictionary(uniqueKeysWithValues: store.projects(includeHidden: true).map { ($0.id, $0) })
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                DateNav(title: Format.date(Day.date(day), "EEEE d MMMM"), subtitle: "\(acts.count) raw rows",
                        onShift: { day = Day.key(Calendar.current.date(byAdding: .day, value: $0, to: Day.date(day))!) },
                        onToday: { day = Day.key(Date()) })
                Button("Delete \(selection.count)", role: .destructive, action: deleteSelected)
                    .buttonStyle(.bordered).controlSize(.small).disabled(selection.isEmpty)
            }
            .padding(Theme.gutter)
            .background(Theme.surface)

            Table(acts, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Start", value: \.interval.start) { Text(clock($0.interval.start)).font(.figure(11, .regular)) }.width(50)
                TableColumn("End", value: \.interval.end) { Text(clock($0.interval.end)).font(.figure(11, .regular)) }.width(50)
                TableColumn("Length", value: \.interval.duration) { Text(hm($0.interval.duration)).font(.figure(11, .regular)) }.width(50)
                TableColumn("App", value: \.app) { Text($0.app).font(.system(size: 12, weight: .semibold)) }.width(min: 80, ideal: 120)
                TableColumn("Title", value: \.title) { Text($0.title).font(.system(size: 12)).help($0.url ?? $0.title) }
                TableColumn("Project", value: \.projectSortKey) { a in
                    Text(a.projectId.flatMap { byId[$0]?.name } ?? "—").font(.label)
                        .foregroundStyle(a.projectId == nil ? Theme.warn : Theme.muted)
                }.width(min: 80, ideal: 120)
            }
            .onDeleteCommand(perform: deleteSelected)
        }
    }

    private func deleteSelected() {
        Log.write("raw", "deleting \(selection.count) activity rows on \(day)")
        selection.forEach(store.deleteActivity)
        selection = []
    }
}

private extension Activity { var projectSortKey: Int64 { projectId ?? .max } }
