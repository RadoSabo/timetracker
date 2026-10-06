import Foundation

/// Reads a Claude Code session transcript (JSONL). Internal format of Claude Code, so every field is optional.
struct Transcript {
    /// Claude Code's own session title (`{"type":"ai-title","aiTitle":...}`), last one wins.
    var aiTitle: String?
    /// User-typed messages from the whole session, oldest first; slash commands and meta messages skipped.
    var userMessages: [String]

    /// `~/.claude/projects/<cwd with / and . as ->/<session>.jsonl`, used when the hook path is unknown.
    static func defaultPath(sessionId: String, cwd: String) -> String {
        let dir = cwd.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects/\(dir)/\(sessionId).jsonl").path
    }

    // ponytail: reads the whole file on every Stop (a few MB at most); tail-read if transcripts grow large
    static func read(path: String) -> Transcript? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        var t = Transcript(aiTitle: nil, userMessages: [])
        for line in text.split(separator: "\n") {
            guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            switch o["type"] as? String {
            case "ai-title":
                if let title = o["aiTitle"] as? String, !title.isEmpty { t.aiTitle = title }
            case "user" where o["isMeta"] as? Bool != true:
                if let msg = userText(o["message"]), !msg.hasPrefix("<"), !t.userMessages.contains(msg) { t.userMessages.append(msg) }
            default: break
            }
        }
        return t
    }

    private static func userText(_ message: Any?) -> String? {
        let content = (message as? [String: Any])?["content"]
        if let s = content as? String { return s }
        let texts = (content as? [[String: Any]])?.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }
        return texts?.isEmpty == false ? texts!.joined(separator: " ") : nil
    }
}
