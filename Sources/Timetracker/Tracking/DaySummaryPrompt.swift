import Foundation

/// What the AI day summary is asked (the instructions sent before DayInput) and how its JSON answer becomes drafts.
enum DaySummaryPrompt {
    static let instructions = """
    You write a contractor's timesheet for one day from raw computer activity, like Timely's AI drafts.
    The input lists projects, Claude Code sessions (agent runs + every prompt), meetings, every foreground window switch
    (app · window title · URL), shell commands and git commits.

    WHAT AN ENTRY IS
    - One entry = one topic as a client would read it on an invoice: a feature, a bug, a setup, a review, a meeting.
      Granularity: a typical day has 3–8 entries; an entry is usually 30 minutes or more.
    - Keep one topic together even when it spans several PRs, sessions, iterations and fixes: setting up a CI review,
      then tuning its model, then fixing its failures, then adjusting its rules is ONE entry ("Claude code review CI setup").
      Put the steps (PR numbers, fixes) into the description, not into separate entries.
    - Split only when the topic really changes: a different feature, area or deliverable. A session can contain several
      topics (its prompts switch to something unrelated) → several entries. Short side tasks (< 15 min) that serve a
      topic belong to it. When unsure whether to split, don't.
    - Find the topics from evidence across sources at the same time: prompts, PR/issue titles and branch names in URLs
      and window titles, file names in editor titles, commit subjects, shell commands, meeting titles.

    NAMES
    - 3–8 English words naming the topic, specific: "Claude code review CI setup", "Worker list import parser",
      "Cloudflare and DigitalOcean hosting setup". Use concrete nouns from the evidence (feature, service, area).
    - Never a bare project, app or tool name ("Acme-api", "Claude", "Chrome", "Superset", "General").
    - Session labels marked "auto label (often wrong)" are hints only; write your own name when they are vague.
    - Description: one or two English sentences listing what was done, with PR/issue numbers.

    PROJECTS
    - The project of the work, not of the window: a session started in one repo but discussing another project's PR,
      repo or keyword belongs to the other project. Use keywords, repo paths, URLs (github.com/<org>/<repo>), prompts.
    - Browsing, chat and docs that clearly serve an entry's topic belong to that entry.
    - Leave out personal activity (shopping, social media, entertainment, private chats) and anything with no evidence
      for a project.

    TIME
    - Ranges cover when that work actually happened: its windows and the agent runs of its sessions.
    - Work can overlap: while an agent runs for entry A the user may do entry B; give both their real ranges.
    - Merge gaps shorter than 10 minutes inside the same work. Never invent time outside recorded activity.
    - Every minute of project-related activity should end up in some entry; do not drop work because it is short.

    TASK IDS
    - task_id: the existing task the entry continues (its session task_id, or an "Other existing task"), else null.
    - When a session is split into several entries, only the entry that is its main work keeps the session's task_id.
    - Two entries never share a task_id.

    Answer with ONLY a JSON array, no prose, in this shape:
    [{"project": "<exact project name>", "task_id": <existing task id or null>, "name": "<3-8 word English task name>",
      "description": "<what was done, with PR/issue numbers>", "ranges": [["HH:MM", "HH:MM"], ...]}]
    """

    /// The JSON array in the answer as drafts; nil when there is none. Unknown projects and entries without valid
    /// ranges are dropped; two drafts for one task would overwrite each other on approval, so only the longest keeps it.
    static func parse(_ text: String, day: String, projects: [Project]) -> [Draft.Proposal]? {
        guard let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"),
              let items = try? JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [[String: Any]] else { return nil }
        let dayStart = Day.interval(day).start
        var drafts = items.compactMap { i -> Draft.Proposal? in
            guard let pname = i["project"] as? String, let p = projects.first(where: { $0.name.caseInsensitiveCompare(pname) == .orderedSame }),
                  let name = i["name"] as? String else { return nil }
            let ranges = (i["ranges"] as? [[String]] ?? []).compactMap { r -> Interval? in
                guard r.count == 2, let s = minutes(r[0]), let e = minutes(r[1]), e > s else { return nil }
                return Interval(start: dayStart + s * 60, end: dayStart + e * 60)
            }
            guard !ranges.isEmpty else { return nil }
            return Draft.Proposal(projectId: p.id, taskId: (i["task_id"] as? NSNumber)?.int64Value, name: name, description: i["description"] as? String ?? "", ranges: ranges)
        }
        for i in drafts.indices {
            if let tid = drafts[i].taskId, drafts.indices.contains(where: { $0 != i && drafts[$0].taskId == tid && drafts[$0].ranges.total > drafts[i].ranges.total }) {
                drafts[i].taskId = nil
            }
        }
        return drafts
    }

    private static func minutes(_ hhmm: String) -> Double? {
        let p = hhmm.split(separator: ":").compactMap { Double($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : nil
    }
}
