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
    /// Project for a working directory: its git root, created on first sight. Temporary and scratch directories
    /// (Claude Code scratchpads, Claude app scratch workspaces) get none; a keyword in the Session Summary decides.
    @discardableResult
    func projectId(forCwd cwd: String) -> Int64? {
        if Self.scratchPrefixes.contains(where: { cwd.hasPrefix($0) }) { return nil }
        let path = Git.root(of: cwd) ?? cwd
        if let r = db.query("SELECT id FROM project WHERE path=?", [path]).first { return r.int("id") }
        return insertProject(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
    }
    static let scratchPrefixes = ["/tmp/", "/private/tmp/", "/private/var/folders/", "/var/folders/",
                                  NSHomeDirectory() + "/Library/Application Support/Claude/"]
    func createProject(name: String) -> Int64 { insertProject(name: name, path: nil) }
    private func insertProject(name: String, path: String?) -> Int64 {
        let color = Int(db.scalar("SELECT COUNT(*) FROM project"))
        let id = db.run("INSERT INTO project(path,name,color) VALUES(?,?,?)", [path, name, color])
        refresh(); return id
    }
    func update(_ p: Project) {
        db.run("UPDATE project SET name=?, billable=?, rate=?, color=?, hidden=?, path=?, keywords=? WHERE id=?",
               [p.name, p.billable, p.rate, p.colorIndex, p.hidden, p.path, p.keywords, p.id])
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
