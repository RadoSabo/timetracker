import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct Row {
    let values: [String: Any]
    subscript(_ key: String) -> Any? { values[key] }
    func str(_ k: String) -> String { values[k] as? String ?? "" }
    func optStr(_ k: String) -> String? { values[k] as? String }
    func dbl(_ k: String) -> Double { (values[k] as? Double) ?? Double(values[k] as? Int64 ?? 0) }
    func optDbl(_ k: String) -> Double? { values[k] == nil ? nil : dbl(k) }
    func int(_ k: String) -> Int64 { (values[k] as? Int64) ?? Int64(values[k] as? Double ?? 0) }
    func optInt(_ k: String) -> Int64? { values[k] == nil ? nil : int(k) }
    func bool(_ k: String) -> Bool { int(k) != 0 }
}

/// Thin synchronous SQLite wrapper. All access is serialized on one queue.
final class DB {
    static let dir: URL = {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Timetracker")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()
    static let shared = DB(path: dir.appendingPathComponent("timetracker.sqlite").path)

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "timetracker.db")

    init(path: String) {
        sqlite3_open(path, &db)
        sqlite3_busy_timeout(db, 2000)
        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA foreign_keys=ON")
        migrate()
    }

    private func migrate() {
        exec("""
        CREATE TABLE IF NOT EXISTS project(id INTEGER PRIMARY KEY, path TEXT UNIQUE, name TEXT NOT NULL, billable INT NOT NULL DEFAULT 0, rate REAL NOT NULL DEFAULT 0, color INT NOT NULL DEFAULT 0, hidden INT NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS activity(id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL NOT NULL, app TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', url TEXT, project_id INT, task_id INT, user_set INT NOT NULL DEFAULT 0);
        CREATE INDEX IF NOT EXISTS activity_start ON activity(start);
        CREATE TABLE IF NOT EXISTS session(id TEXT PRIMARY KEY, cwd TEXT NOT NULL, branch TEXT, project_id INT, started REAL NOT NULL, ended REAL, last_event REAL NOT NULL, summary TEXT, summarized_prompts INT NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS prompt(id INTEGER PRIMARY KEY, session_id TEXT NOT NULL, ts REAL NOT NULL, text TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS run(id INTEGER PRIMARY KEY, session_id TEXT NOT NULL, start REAL NOT NULL, end REAL);
        CREATE INDEX IF NOT EXISTS run_start ON run(start);
        CREATE TABLE IF NOT EXISTS shell(id INTEGER PRIMARY KEY, ts REAL NOT NULL, cwd TEXT NOT NULL, cmd TEXT NOT NULL, project_id INT);
        CREATE TABLE IF NOT EXISTS meeting(id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL, title TEXT NOT NULL, project_id INT, task_id INT);
        CREATE TABLE IF NOT EXISTS manual(id INTEGER PRIMARY KEY, start REAL NOT NULL, end REAL NOT NULL, project_id INT NOT NULL, note TEXT NOT NULL DEFAULT '', task_id INT);
        CREATE TABLE IF NOT EXISTS task(id INTEGER PRIMARY KEY, project_id INT NOT NULL, day TEXT NOT NULL, name TEXT NOT NULL, session_id TEXT, name_edited INT NOT NULL DEFAULT 0, adjustment REAL NOT NULL DEFAULT 0, adjustment_note TEXT NOT NULL DEFAULT '');
        CREATE INDEX IF NOT EXISTS task_day ON task(day);
        CREATE TABLE IF NOT EXISTS rule(id INTEGER PRIMARY KEY, pattern TEXT NOT NULL, project_id INT NOT NULL);
        CREATE TABLE IF NOT EXISTS setting(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS draft(id INTEGER PRIMARY KEY, day TEXT NOT NULL, project_id INT NOT NULL, task_id INT, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', ranges TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending');
        CREATE INDEX IF NOT EXISTS draft_day ON draft(day);
        CREATE TABLE IF NOT EXISTS pause(project_id INT NOT NULL, start REAL NOT NULL, billable INT NOT NULL DEFAULT 0, PRIMARY KEY(project_id, start));
        CREATE TABLE IF NOT EXISTS day_start(project_id INT NOT NULL, day TEXT NOT NULL, start REAL NOT NULL, PRIMARY KEY(project_id, day));
        CREATE TABLE IF NOT EXISTS task_range(task_id INT NOT NULL, start REAL NOT NULL, end REAL NOT NULL);
        CREATE INDEX IF NOT EXISTS task_range_task ON task_range(task_id);
        """)
        addColumnIfMissing("activity", "reason TEXT")
        addColumnIfMissing("session", "transcript TEXT")
        addColumnIfMissing("project", "keywords TEXT NOT NULL DEFAULT ''")
        addColumnIfMissing("task", "ranges_until REAL")
        addColumnIfMissing("draft", "source TEXT")
        addColumnIfMissing("task", "project_edited INT NOT NULL DEFAULT 0")
    }

    private func addColumnIfMissing(_ table: String, _ column: String) {
        let name = String(column.split(separator: " ")[0])
        if !query("PRAGMA table_info(\(table))").contains(where: { $0.str("name") == name }) {
            exec("ALTER TABLE \(table) ADD COLUMN \(column)")
        }
    }

    @discardableResult
    func exec(_ sql: String) -> Bool {
        queue.sync { sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK }
    }

    @discardableResult
    func run(_ sql: String, _ args: [Any?] = []) -> Int64 {
        queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                NSLog("sqlite prepare failed: \(String(cString: sqlite3_errmsg(db))) :: \(sql)"); return 0
            }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, args)
            let rc = sqlite3_step(stmt)
            if rc != SQLITE_DONE && rc != SQLITE_ROW { NSLog("sqlite step failed: \(String(cString: sqlite3_errmsg(db))) :: \(sql)") }
            return sqlite3_last_insert_rowid(db)
        }
    }

    func query(_ sql: String, _ args: [Any?] = []) -> [Row] {
        queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                NSLog("sqlite prepare failed: \(String(cString: sqlite3_errmsg(db))) :: \(sql)"); return []
            }
            defer { sqlite3_finalize(stmt) }
            bind(stmt, args)
            var rows: [Row] = []
            let n = sqlite3_column_count(stmt)
            while sqlite3_step(stmt) == SQLITE_ROW {
                var v: [String: Any] = [:]
                for i in 0..<n {
                    let name = String(cString: sqlite3_column_name(stmt, i))
                    switch sqlite3_column_type(stmt, i) {
                    case SQLITE_INTEGER: v[name] = sqlite3_column_int64(stmt, i)
                    case SQLITE_FLOAT: v[name] = sqlite3_column_double(stmt, i)
                    case SQLITE_TEXT: v[name] = String(cString: sqlite3_column_text(stmt, i))
                    default: break
                    }
                }
                rows.append(Row(values: v))
            }
            return rows
        }
    }

    func scalar(_ sql: String, _ args: [Any?] = []) -> Double {
        query(sql, args).first?.values.values.first.map { ($0 as? Double) ?? Double($0 as? Int64 ?? 0) } ?? 0
    }

    private func bind(_ stmt: OpaquePointer?, _ args: [Any?]) {
        for (i, a) in args.enumerated() {
            let idx = Int32(i + 1)
            switch a {
            case nil: sqlite3_bind_null(stmt, idx)
            case let s as String: sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            case let d as Double: sqlite3_bind_double(stmt, idx, d)
            case let n as Int64: sqlite3_bind_int64(stmt, idx, n)
            case let n as Int: sqlite3_bind_int64(stmt, idx, Int64(n))
            case let b as Bool: sqlite3_bind_int64(stmt, idx, b ? 1 : 0)
            case let d as Date: sqlite3_bind_double(stmt, idx, d.timeIntervalSince1970)
            default: sqlite3_bind_text(stmt, idx, "\(a!)", -1, SQLITE_TRANSIENT)
            }
        }
    }

    // MARK: settings
    func setting(_ key: String) -> String? { query("SELECT value FROM setting WHERE key=?", [key]).first?.str("value") }
    func setSetting(_ key: String, _ value: String) { run("INSERT OR REPLACE INTO setting(key,value) VALUES(?,?)", [key, value]) }
}
