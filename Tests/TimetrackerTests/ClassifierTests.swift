import Foundation
import SQLite3
import Testing
@testable import Timetracker

@Test func classifierAnswerBecomesDecisionsAndUnknownProjectIsNone() {
    let workers = Project(row: Row(values: ["id": Int64(1), "name": "h2-workers"]))
    let answer = """
    [{"id": "w0", "project": "H2-Workers", "work": true, "why": "workers database"},
     {"id": "w1", "project": null, "work": true, "why": "infra research"},
     {"id": "w2", "project": "h2-prime-migration", "work": false, "why": "invented"},
     {"id": "s0", "project": null, "work": false, "why": "shopping"}]
    """
    let d = ClassifierPrompt.parse(answer, projects: [workers])!
    #expect(d["w0"] == .init(projectId: 1, work: true, why: "workers database"))
    #expect(d["w1"] == .init(projectId: nil, work: true, why: "infra research"))
    #expect(d["w2"]?.projectId == nil)
    #expect(d["s0"]?.work == false)
    #expect(ClassifierPrompt.parse("no json", projects: [workers]) == nil)
}

@Test func oldDatabaseKeepsItsTasksWhenProjectBecomesOptional() {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("tt-\(UUID()).sqlite").path
    var raw: OpaquePointer?
    sqlite3_open(path, &raw)
    sqlite3_exec(raw, "CREATE TABLE task(id INTEGER PRIMARY KEY, project_id INT NOT NULL, day TEXT NOT NULL, name TEXT NOT NULL, session_id TEXT, name_edited INT NOT NULL DEFAULT 0, adjustment REAL NOT NULL DEFAULT 0, adjustment_note TEXT NOT NULL DEFAULT ''); INSERT INTO task(project_id,day,name) VALUES(3,'2026-10-12','General')", nil, nil, nil)
    sqlite3_close(raw)
    let db = DB(path: path)
    #expect(db.query("SELECT project_id, name FROM task").map { "\($0.int("project_id")) \($0.str("name"))" } == ["3 General"])
    db.run("INSERT INTO task(project_id,day,name) VALUES(NULL,'2026-10-12','X')")
    #expect(db.scalar("SELECT COUNT(*) FROM task WHERE project_id IS NULL") == 1)
    #expect(FileManager.default.fileExists(atPath: path + ".bak-before-nullable-project"))
}
