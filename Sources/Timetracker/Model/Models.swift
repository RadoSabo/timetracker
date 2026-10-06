import Foundation

struct Project: Identifiable, Hashable {
    var id: Int64
    var path: String?
    var name: String
    var billable: Bool
    var rate: Double
    var colorIndex: Int
    var hidden: Bool
    /// Comma-separated words that identify the project in window titles, URLs and meeting names ("acme, Jane").
    var keywords: String

    var keywordList: [String] { keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    /// Project name or a keyword as a whole word in `text`, case-insensitive; returns what matched.
    func match(in text: String) -> String? {
        ([name] + keywordList).first { word in
            word.count >= 2 && text.range(of: "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: word) + "(?![\\p{L}\\p{N}])",
                                          options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    init(row r: Row) {
        id = r.int("id"); path = r.optStr("path"); name = r.str("name"); billable = r.bool("billable")
        rate = r.dbl("rate"); colorIndex = Int(r.int("color")); hidden = r.bool("hidden"); keywords = r.str("keywords")
    }
}

enum TimeOrigin: String { case tracked, manual }

struct Activity: Identifiable, Hashable {
    var id: Int64
    var interval: Interval
    var app: String
    var title: String
    var url: String?
    var projectId: Int64?
    var taskId: Int64?
    init(row r: Row) {
        id = r.int("id"); interval = Interval(start: r.dbl("start"), end: r.dbl("end"))
        app = r.str("app"); title = r.str("title"); url = r.optStr("url")
        projectId = r.optInt("project_id"); taskId = r.optInt("task_id")
    }
}

struct ManualEntry: Identifiable {
    var id: Int64
    var interval: Interval
    var projectId: Int64
    var note: String
    var taskId: Int64?
    init(row r: Row) {
        id = r.int("id"); interval = Interval(start: r.dbl("start"), end: r.dbl("end"))
        projectId = r.int("project_id"); note = r.str("note"); taskId = r.optInt("task_id")
    }
}

struct TaskItem: Identifiable, Hashable {
    var id: Int64
    var projectId: Int64
    var day: String
    var name: String
    var sessionId: String?
    var nameEdited: Bool
    var adjustment: Seconds
    var adjustmentNote: String
    /// Set when an AI draft was approved: until then the task's time is its approved ranges, after it live tracking.
    var rangesUntil: Seconds?
    /// Exists only because an AI draft was approved (no session, meeting or manual time): the next summary regenerates it.
    var fromDraft = false
    /// Filled by Store: tracked intervals (union), manual entry intervals.
    var tracked: [Interval] = []
    var manual: [Interval] = []
    var trackedSeconds: Seconds { tracked.total }
    var manualSeconds: Seconds { manual.total + adjustment }
    var totalSeconds: Seconds { max(0, (tracked + manual).total + adjustment) }
    var allIntervals: [Interval] { (tracked + manual).union() }
    init(row r: Row) {
        id = r.int("id"); projectId = r.int("project_id"); day = r.str("day"); name = r.str("name")
        sessionId = r.optStr("session_id"); nameEdited = r.bool("name_edited")
        adjustment = r.dbl("adjustment"); adjustmentNote = r.str("adjustment_note"); rangesUntil = r.optDbl("ranges_until")
    }
}

struct ClaudeSession {
    var id: String
    var cwd: String
    var branch: String?
    var projectId: Int64?
    var started: Seconds
    var ended: Seconds?
    var summary: String?
    var summarizedPrompts: Int
    var transcript: String?
    var transcriptPath: String { transcript ?? Transcript.defaultPath(sessionId: id, cwd: cwd) }
    init(row r: Row) {
        transcript = r.optStr("transcript")
        id = r.str("id"); cwd = r.str("cwd"); branch = r.optStr("branch"); projectId = r.optInt("project_id")
        started = r.dbl("started"); ended = r.optDbl("ended"); summary = r.optStr("summary")
        summarizedPrompts = Int(r.int("summarized_prompts"))
    }
}

/// One prompt → Stop stretch of a Claude Code agent working.
struct AgentRun {
    var interval: Interval
    var sessionId: String
    var projectId: Int64?
    /// The Task the session worked on, else its Session Summary, else the cwd folder.
    var label: String
}

/// AI-proposed time entry from the day summary; becomes real only when approved.
struct Draft: Identifiable {
    enum Status: String { case pending, approved, dismissed }
    var id: Int64
    var day: String
    var projectId: Int64
    var taskId: Int64?
    var name: String
    var description: String
    var ranges: [Interval]
    var status: Status
    var seconds: Seconds { ranges.total }
    /// A draft as the day summary proposes it, before it is stored.
    struct Proposal { var projectId: Int64; var taskId: Int64?; var name: String; var description: String; var ranges: [Interval] }
    init(row r: Row) {
        id = r.int("id"); day = r.str("day"); projectId = r.int("project_id"); taskId = r.optInt("task_id")
        name = r.str("name"); description = r.str("description"); status = Status(rawValue: r.str("status")) ?? .pending
        let pairs = (try? JSONSerialization.jsonObject(with: Data(r.str("ranges").utf8))) as? [[Double]] ?? []
        ranges = pairs.filter { $0.count == 2 }.map { Interval(start: $0[0], end: $0[1]) }
    }
}

struct Rule: Identifiable {
    var id: Int64
    var pattern: String
    var projectId: Int64
    init(row r: Row) { id = r.int("id"); pattern = r.str("pattern"); projectId = r.int("project_id") }
    func matches(_ text: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        return re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
