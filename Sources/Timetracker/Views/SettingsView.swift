import SwiftUI
import EventKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Local var idle = Settings.idleMinutes
    @Local var fullPrompts = Settings.fullPromptsInExport
    @Local var workCalendars = Settings.workCalendars
    @Local var newRule = ""
    @Local var newRuleProject: Int64?
    @Local var newProject = ""
    @Local var message = ""
    @Local var launchAtLogin = Settings.launchAtLogin

    var body: some View {
        let _ = store.tick
        Form {
            Section("Projects") {
                ForEach(store.projects(includeHidden: true)) { p in ProjectRow(project: p) }
                HStack {
                    TextField("New project (no folder)", text: $newProject)
                    Button("Add") { _ = store.createProject(name: newProject); newProject = "" }.disabled(newProject.isEmpty)
                }
                Text("Projects from Claude Code and the shell appear automatically (git root).").font(.caption).foregroundStyle(Theme.muted)
            }
            Section("Rules (regex on “app | window title | url” → project)") {
                ForEach(store.rules()) { r in
                    HStack {
                        Text(r.pattern).font(.system(.body, design: .monospaced))
                        Spacer()
                        Text(store.project(r.projectId)?.name ?? "?")
                        Button(role: .destructive) { store.deleteRule(r.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                }
                HStack {
                    TextField("e.g. github\\.com/acme-api|jira", text: $newRule)
                    ProjectPicker(label: "", projects: store.projects(), none: "Project", selection: $newRuleProject).frame(width: 180)
                    Button("Add") { if let pid = newRuleProject { store.addRule(pattern: newRule, projectId: pid); newRule = "" } }.disabled(newRule.isEmpty || newRuleProject == nil)
                }
            }
            Section("Tracking") {
                HStack { Text("Idle after"); TextField("", value: $idle, format: .number).frame(width: 60); Text("minutes") }
                    .onChange(of: idle) { _, v in Settings.idleMinutes = v }
                Toggle("Include full prompts in “Copy for Claude”", isOn: $fullPrompts).onChange(of: fullPrompts) { _, v in Settings.fullPromptsInExport = v }
                Toggle("Launch at login", isOn: $launchAtLogin).onChange(of: launchAtLogin) { _, v in
                    Settings.launchAtLogin = v
                    if v { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                }
                if SMAppService.mainApp.status != .enabled && launchAtLogin {
                    Text("Not registered yet: macOS may require approval under System Settings → General → Login Items, and the app should live in /Applications (make install).").font(.caption).foregroundStyle(Theme.warn)
                }
            }
            Section("Work calendars (events count as meetings)") {
                let status = EKEventStore.authorizationStatus(for: .event)
                if status == .fullAccess {
                    ForEach(Tracker.shared.meetings.eventStore.calendars(for: .event), id: \.calendarIdentifier) { c in
                        Toggle(c.title + " (" + c.source.title + ")", isOn: Binding(
                            get: { workCalendars.contains(c.calendarIdentifier) },
                            set: { on in if on { workCalendars.insert(c.calendarIdentifier) } else { workCalendars.remove(c.calendarIdentifier) }; Settings.workCalendars = workCalendars }))
                    }
                } else {
                    Button("Grant calendar access") {
                        Tracker.shared.meetings.eventStore.requestFullAccessToEvents { _, _ in store.refresh() }
                    }
                }
            }
            Section("Permissions & hooks") {
                Text("Accessibility: enable Timetracker in System Settings → Privacy & Security → Accessibility. After every rebuild with ad-hoc signing, remove it there and add it again.").font(.caption).foregroundStyle(Theme.muted)
                HStack {
                    Text("Accessibility (window titles)"); Spacer()
                    if AX.trusted { Text("Granted").foregroundStyle(Theme.ok) } else { Button("Open System Settings") { openAccessibilitySettings() } }
                }
                HStack {
                    Text("On-device model (Session Summary)"); Spacer()
                    Text(Summarizer.available ? "Available" : "Unavailable – enable Apple Intelligence").foregroundStyle(Summarizer.available ? Theme.ok : Theme.warn)
                }
                HStack {
                    Text("Claude Code hooks"); Spacer()
                    Text(Hooks.installed ? "Installed" : "Not installed").foregroundStyle(Hooks.installed ? Theme.ok : Theme.warn)
                    Button(Hooks.installed ? "Uninstall" : "Install") {
                        do { try Hooks.installed ? Hooks.uninstall() : Hooks.install(); message = "Done. Restart Claude Code sessions and open a new terminal." }
                        catch { message = "Failed: \(error.localizedDescription)" }
                    }
                    Text("(installed automatically at launch)").font(.caption).foregroundStyle(Theme.muted)
                }
                HStack {
                    Text("zsh hook"); Spacer()
                    Text(Hooks.zshInstalled ? "Installed" : "Not installed").foregroundStyle(Hooks.zshInstalled ? Theme.ok : Theme.warn)
                }
                Text("Hooks write to \(Hooks.eventsFile.path)").font(.caption).foregroundStyle(Theme.muted)
                HStack {
                    Text("Decision log: \(Log.file.path)").font(.caption).foregroundStyle(Theme.muted)
                    Button("Open") { NSWorkspace.shared.open(Log.file) }
                }
                if !message.isEmpty { Text(message).foregroundStyle(Theme.muted) }
            }
        }
        .formStyle(.grouped)
    }
}

struct ProjectRow: View {
    @EnvironmentObject var store: Store
    @Local var project: Project
    var body: some View {
        HStack(spacing: 10) {
            Picker("", selection: $project.colorIndex) {
                ForEach(0..<Project.palette.count, id: \.self) { i in Circle().fill(Project.palette[i]).frame(width: 12, height: 12).tag(i) }
            }.frame(width: 50).labelsHidden()
            TextField("Name", text: $project.name).frame(width: 160)
            Text(project.path ?? "").font(.caption).foregroundStyle(Theme.muted).lineLimit(1).truncationMode(.head)
            Spacer()
            Toggle("Billable", isOn: $project.billable)
            TextField("€/h", value: $project.rate, format: .number).frame(width: 60).disabled(!project.billable)
            Toggle("Hidden", isOn: $project.hidden)
        }
        TextField("Keywords, comma separated (e.g. acme, Jane)", text: $project.keywords).font(.caption).padding(.leading, 60)
        .onChange(of: project) { _, p in store.update(p) }
    }
}
