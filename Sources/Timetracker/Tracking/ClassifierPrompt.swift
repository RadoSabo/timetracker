import Foundation

/// What the Project classification asks `claude -p` and how its JSON answer becomes decisions.
enum ClassifierPrompt {
    struct Item { var id: String; var line: String }
    struct Decision: Equatable { var projectId: Int64?; var work: Bool; var why: String }

    static let instructions = """
    You assign a contractor's computer activity to their projects. Each item is a foreground window (app · title · URL)
    or a Claude Code session (folder, label, prompts).

    - Give an item a project only when its content clearly serves that project's work: the project name, description,
      keywords, repo, GitHub org, domain or topic. Research for a project's topic belongs to it (googling cloud
      infrastructure for a migration project, reading docs of a library that project uses).
    - The user's past corrections are the strongest evidence: similar items go where the user put them.
    - project null when no project fits or you are unsure between several. Never invent a project name.
    - work true for professional work (coding, docs, research, admin, work communication) even when no project fits;
      false for personal things (shopping, social media, entertainment, private chats, own freelancer profiles) and for
      windows with no topic (Finder, System Settings, a new tab, a lock screen).

    Answer with ONLY a JSON array, no prose:
    [{"id": "<item id>", "project": "<exact project name>" or null, "work": true or false, "why": "<at most 8 words>"}]
    """

    static func build(projects: [Project], corrections: [(text: String, project: String?)], items: [Item]) -> String {
        var s = instructions + "\n\n## Projects\n"
        for p in projects {
            s += "- \(p.name)" + (p.description.isEmpty ? "" : " — \(p.description)") + (p.keywords.isEmpty ? "" : " — keywords: \(p.keywords)")
                + (p.path.map { " — repo: \($0)" } ?? "") + "\n"
        }
        if !corrections.isEmpty {
            s += "\n## Past corrections by the user (newest first)\n"
            for c in corrections { s += "- \(c.text) → \(c.project ?? "no project")\n" }
        }
        s += "\n## Items\n"
        for i in items { s += "\(i.id) · \(i.line)\n" }
        return s
    }

    /// Decisions by item id; nil when the answer has no JSON array. A project name not in `projects` counts as none.
    static func parse(_ text: String, projects: [Project]) -> [String: Decision]? {
        guard let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"),
              let items = try? JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [[String: Any]] else { return nil }
        var out: [String: Decision] = [:]
        for i in items {
            guard let id = i["id"] as? String else { continue }
            let name = i["project"] as? String
            let pid = name.flatMap { n in projects.first { $0.name.caseInsensitiveCompare(n) == .orderedSame }?.id }
            out[id] = Decision(projectId: pid, work: pid != nil || (i["work"] as? Bool ?? false), why: i["why"] as? String ?? "")
        }
        return out
    }
}
