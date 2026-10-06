import SwiftUI

/// Invoice: controls on the left, the time report as a sheet of paper on the right.
struct ReportView: View {
    @EnvironmentObject var store: Store
    @Binding var tab: Tab
    @Binding var day: String
    @Local var projectId: Int64?
    @Local var period = "This month"
    @Local var from = Date()
    @Local var to = Date()
    @Local var rounding = Settings.roundingMinutes
    @Local var overlap = Settings.overlapPolicy
    @Local var flash = ""

    private static let periods = ["This month", "Last month", "This week", "Custom"]

    var body: some View {
        let _ = store.tick
        let billable = store.billableProjects()
        let report = projectId.flatMap(store.project).map { Report.build(project: $0, from: from, to: to) }
        HStack(spacing: 0) {
            controls(billable, report).frame(width: 240).padding(Theme.gutter).background(Theme.surface)
            Divider()
            ScrollView {
                if let r = report { ReportPaper(report: r, tab: $tab, day: $day).padding(Theme.gutter * 2) }
                else { Text("Mark the client project as billable in Settings, then its invoice appears here.").foregroundStyle(Theme.muted).padding(Theme.gutter * 2) }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { if projectId == nil { projectId = billable.first?.id }; applyPeriod() }
    }

    // MARK: controls
    private func controls(_ billable: [Project], _ r: Report?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Invoice").font(.heading).foregroundStyle(Theme.ink)
            field("Project") {
                VStack(spacing: 2) {
                    ForEach(billable) { p in
                        Button { projectId = p.id } label: {
                            HStack(spacing: 8) {
                                ProjectDot(project: p)
                                Text(p.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(Format.euro(p.rate)) /h").font(.figure(10, .regular)).foregroundStyle(Theme.muted)
                            }
                            .padding(8).contentShape(Rectangle())
                            .background(RoundedRectangle(cornerRadius: Theme.radius).fill(projectId == p.id ? Theme.sunken : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            field("Period") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(Self.periods, id: \.self) { p in
                        Button(p) { period = p; applyPeriod() }.buttonStyle(.plain).font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: Theme.radius).fill(period == p ? Theme.ink : Theme.sunken))
                            .foregroundStyle(period == p ? Theme.surface : Theme.ink)
                    }
                }
                if period == "Custom" {
                    HStack {
                        DatePicker("", selection: $from, displayedComponents: .date).labelsHidden()
                        DatePicker("", selection: $to, displayedComponents: .date).labelsHidden()
                    }
                }
            }
            field("Round each day to") {
                Picker("", selection: $rounding) { Text("Off").tag(0); Text("15 min").tag(15); Text("30 min").tag(30) }
                    .labelsHidden().pickerStyle(.segmented).onChange(of: rounding) { _, v in Settings.roundingMinutes = v; store.refresh() }
            }
            field("Overlap with other billable projects") {
                Picker("", selection: $overlap) { ForEach(OverlapPolicy.allCases) { Text($0.rawValue).tag($0) } }
                    .labelsHidden().pickerStyle(.segmented).onChange(of: overlap) { _, v in Settings.overlapPolicy = v; store.refresh() }
            }
            Spacer()
            if let r {
                VStack(spacing: 6) {
                    Button { copy(r.claudePrompt(), "Copied the prompt for Claude") } label: { Label("Copy for Claude", systemImage: "sparkles").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).tint(Theme.accent).controlSize(.large)
                    HStack(spacing: 6) {
                        Button("Copy Markdown") { copy(r.markdown, "Copied Markdown") }.frame(maxWidth: .infinity)
                        Button("Save CSV…") { save(r) }.frame(maxWidth: .infinity)
                    }
                    Text(flash).font(.label).foregroundStyle(Theme.muted).frame(height: 14)
                }
            }
        }
    }

    private func field<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.label).foregroundStyle(Theme.muted)
            content()
        }
    }

    // MARK: actions
    private func applyPeriod() {
        let cal = Calendar.current, now = Date()
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        switch period {
        case "This month": from = thisMonth; to = now
        case "Last month": from = cal.date(byAdding: .month, value: -1, to: thisMonth)!; to = cal.date(byAdding: .day, value: -1, to: thisMonth)!
        case "This week": from = Day.weekStart(now); to = cal.date(byAdding: .day, value: 6, to: Day.weekStart(now))!
        default: break
        }
    }
    private func copy(_ s: String, _ message: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string); flash = message
    }
    private func save(_ r: Report) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\(r.project.name)-\(Day.key(r.from))-\(Day.key(r.to)).csv"
        if panel.runModal() == .OK, let url = panel.url { try? r.csv.write(to: url, atomically: true, encoding: .utf8); flash = "Saved \(url.lastPathComponent)" }
    }
}
