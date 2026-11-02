import Foundation
import Combine

/// Single source of truth for views. All reads go through DB; `tick` bumps to refresh views.
/// Responsibilities are split across extensions: Assignment, Activities, Tasks, Sessions.
final class Store: ObservableObject {
    static let shared = Store()
    let db = DB.shared
    @Published var tick = 0
    @Published var currentProjectName: String = "—"
    @Published var currentTaskName: String = ""
    @Published var currentSince: Seconds = now()
    @Published var trackingPaused = false
    /// End of the pause the user started from the menu bar; nil while not paused by the user.
    @Published var pausedUntil: Seconds?
    /// "0:12": time left of that pause, for the menu bar.
    @Published var pauseLeft = ""
    /// Day tasks are rebuilt at most once per `tick`; Week and Invoice ask for many days in one render.
    var taskCache: [String: (tick: Int, tasks: [TaskItem])] = [:]

    func refresh() { DispatchQueue.main.async { self.tick += 1 } }

    // MARK: Projects
    func projects(includeHidden: Bool = false) -> [Project] {
        db.query("SELECT * FROM project \(includeHidden ? "" : "WHERE hidden=0") ORDER BY billable DESC, name").map(Project.init)
    }
    func billableProjects() -> [Project] { projects().filter(\.billable) }
    func project(_ id: Int64?) -> Project? {
        guard let id else { return nil }
        return db.query("SELECT * FROM project WHERE id=?", [id]).first.map(Project.init)
    }
    /// Project whose folder holds `cwd`, the deepest one wins (a worktree counts as its main repo; the home folder holds
    /// everything, so it never counts); nil when none does. Projects are never created here: the user adds them in
    /// Settings, the AI classification decides the rest.
    func projectId(forCwd cwd: String) -> Int64? {
        let root = Git.mainRoot(of: cwd) ?? cwd
        return projects(includeHidden: true)
            .filter { p in p.path.map { $0 != NSHomeDirectory() && (root == $0 || root.hasPrefix($0 + "/")) } == true }
            .max { $0.path!.count < $1.path!.count }?.id
    }
    func createProject(name: String) -> Int64 {
        let id = db.run("INSERT INTO project(name,color) VALUES(?,?)", [name, Int(db.scalar("SELECT COUNT(*) FROM project"))])
        Log.write("project", "created #\(id) '\(name)'")
        refresh(); return id
    }
    func update(_ p: Project) {
        db.run("UPDATE project SET name=?, billable=?, rate=?, color=?, hidden=?, path=?, keywords=?, description=? WHERE id=?",
               [p.name, p.billable, p.rate, p.colorIndex, p.hidden, p.path, p.keywords, p.description, p.id])
        refresh()
    }
}

extension Store {
    /// "Acme-api" says which project, not what was done: no good as a task name.
    func isBareProjectName(_ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return projects(includeHidden: true).contains { p in ([p.name] + p.keywordList).contains { $0.caseInsensitiveCompare(n) == .orderedSame } }
    }
    /// Project whose name or keyword appears in `text`; the longest match wins ("acme-api" beats "acme").
    func projectMatching(_ text: String) -> (project: Project, word: String)? {
        projects().compactMap { p in p.match(in: text).map { (p, $0) } }.max { $0.1.count < $1.1.count }
    }
}
