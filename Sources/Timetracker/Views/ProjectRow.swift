import SwiftUI

/// One Project in Settings. The AI classification assigns work by its name, description, keywords and folder.
/// Text fields carry their hint as a prompt and a border: in a grouped Form a title becomes a side label that squeezes
/// the field away, and a borderless field looks like plain text.
struct ProjectRow: View {
    @EnvironmentObject var store: Store
    /// As saved; a generated description arrives through it.
    var stored: Project
    @Local var project: Project
    @Local var confirmDelete = false
    @Local var generating = false

    var body: some View {
        HStack(spacing: 10) {
            ColorDot(index: $project.colorIndex)
            TextField("", text: $project.name, prompt: Text("Name")).labelsHidden().textFieldStyle(.roundedBorder).frame(width: 180)
            Spacer()
            Toggle("Billable", isOn: $project.billable)
            TextField("", value: $project.rate, format: .number, prompt: Text("€/h")).labelsHidden().textFieldStyle(.roundedBorder).frame(width: 60).disabled(!project.billable)
            Toggle("Hidden", isOn: $project.hidden)
            Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Description").font(.caption).foregroundStyle(Theme.muted)
            HStack(alignment: .top) {
                TextField("", text: $project.description, prompt: Text("What it is about, for the AI (product, client, technologies, typical topics)"), axis: .vertical)
                    .labelsHidden().textFieldStyle(.roundedBorder).lineLimit(1...4)
                Button(generating ? "Generating…" : "Generate") {
                    generating = true
                    ProjectDescriber.shared.generate(project.id, overwrite: true) { generating = false }
                }
                .disabled(generating).help("Write the description from the folder's README, tasks, windows and your corrections")
            }
            Text("Keywords").font(.caption).foregroundStyle(Theme.muted).padding(.top, 4)
            TextField("", text: $project.keywords, prompt: Text("Comma separated, e.g. acme, Jane")).labelsHidden().textFieldStyle(.roundedBorder)
            HStack {
                Text("Folder").font(.caption).foregroundStyle(Theme.muted)
                Text(project.path ?? "none").font(.caption).foregroundStyle(Theme.ink).lineLimit(1).truncationMode(.head)
                Spacer()
                Button(project.path == nil ? "Choose folder…" : "Change…", action: chooseFolder)
                if project.path != nil { Button("Clear") { project.path = nil } }
            }
            .controlSize(.small)
        }
        .padding(.leading, 60)
        .onChange(of: stored.description) { _, d in if project.description != d { project.description = d } }
        .onChange(of: project) { old, p in
            store.update(p)
            if (old.name, old.description, old.keywords, old.path) != (p.name, p.description, p.keywords, p.path) { store.reclassifyToday() }
        }
        .confirmationDialog("Delete \(project.name)?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { store.deleteProject(project.id) }
        } message: {
            Text("Its windows become unassigned again; Claude sessions and manual time stay, as No project.")
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.directoryURL = project.path.map(URL.init(fileURLWithPath:))
        if panel.runModal() == .OK, let url = panel.url { project.path = url.path }
    }
}

/// The project's color as a dot; a click opens the palette. A Picker can't show swatches: its NSMenu drops SwiftUI shapes.
private struct ColorDot: View {
    @Binding var index: Int
    @Local var open = false
    var body: some View {
        Button { open = true } label: { Circle().fill(Project.palette[index % Project.palette.count]).frame(width: 16, height: 16) }
            .buttonStyle(.plain).help("Project color")
            .popover(isPresented: $open) {
                HStack(spacing: 8) {
                    ForEach(Project.palette.indices, id: \.self) { i in
                        Button { index = i; open = false } label: {
                            Circle().fill(Project.palette[i]).frame(width: 18, height: 18)
                                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: i == index ? 2 : 0).padding(-3))
                        }.buttonStyle(.plain)
                    }
                }.padding(12)
            }
    }
}
