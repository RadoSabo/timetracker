import Foundation
import FoundationModels

/// Session Summary: one label for the whole Claude Session.
/// 1. Claude Code's own `ai-title` from the transcript (free, sees the whole session).
/// 2. Fallback: on-device model over every user message in the transcript (or the hooked prompts if there is no transcript),
///    re-run when the message count crosses 1, 3, 6, 12, 24… so late follow-ups cannot hijack the label.
final class Summarizer {
    static let shared = Summarizer()
    private let store = Store.shared
    private let db = DB.shared
    private var inFlight: Set<String> = []

    static var available: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Next message count that triggers a model summary: 1, 3, 6, 12, 24, …
    static func threshold(after n: Int) -> Int {
        var t = 1
        while t <= n { t = t < 3 ? 3 : t * 2 }
        return t
    }

    /// Summarizes every session active in the last day; run at launch so older sessions get fixed too.
    func summarizeRecent() {
        for r in db.query("SELECT id FROM session WHERE last_event>?", [now() - 86400]) { summarize(sessionId: r.str("id"), force: true) }
    }

    func summarize(sessionId: String, force: Bool = false) {
        guard !inFlight.contains(sessionId), let s = store.session(sessionId) else { return }
        let transcript = Transcript.read(path: s.transcriptPath)
        if let title = transcript?.aiTitle, !store.isBareProjectName(title) {
            save(title, session: s, messages: s.summarizedPrompts, source: "ai-title")
            return
        }
        let messages = (transcript?.userMessages ?? store.prompts(session: sessionId).map(\.text))
            .map { $0.replacingOccurrences(of: "\n", with: " ") }.filter { $0.count > 12 }
        guard Summarizer.available, !messages.isEmpty,
              force || messages.count >= Summarizer.threshold(after: s.summarizedPrompts) else { return }
        inFlight.insert(sessionId)
        Task {
            defer { inFlight.remove(sessionId) }
            do {
                let label = try await modelLabel(messages, project: store.project(s.projectId)?.name ?? "?")
                save(label, session: s, messages: messages.count, source: "model over \(transcript == nil ? "hooked prompts" : "transcript")")
            } catch { Log.write("summary", "session \(sessionId.prefix(8)) failed: \(error)") }
        }
    }

    private func save(_ label: String, session s: ClaudeSession, messages: Int, source: String) {
        guard label.count > 3, label != s.summary else { return }
        db.run("UPDATE session SET summary=?, summarized_prompts=? WHERE id=?", [label, messages, s.id])
        db.run("UPDATE task SET name=? WHERE session_id=? AND name_edited=0", [label, s.id])
        Log.write("summary", "session \(s.id.prefix(8)) → '\(label)' (\(source), was '\(s.summary ?? "-")')")
        store.refresh()
    }

    private func modelLabel(_ messages: [String], project: String) async throws -> String {
        // ponytail: ~3k char budget for the 3B model; first messages kept, the rest sampled evenly
        var chosen = messages
        if messages.count > 40 {
            let rest = Array(messages.dropFirst(6)), step = Double(rest.count) / 34
            chosen = Array(messages.prefix(6)) + (0..<34).map { rest[Int(Double($0) * step)] }
        }
        let quoted = chosen.map { "\"" + $0.prefix(90) + "\"" }.joined(separator: " ")
        let session = LanguageModelSession(instructions: """
            You write one task label for a timesheet. Output exactly one line: a label of 3 to 10 words, English, \
            no quotes, no list, no explanation.
            Examples of labels: Build macOS time tracker app / CSV import of workers with validation / Fix login redirect loop
            """)
        let raw = try await session.respond(to: """
            In project \(project) a developer sent these prompts, in order, during one coding session: \(quoted)
            The session has one overall goal; later prompts are follow-ups. What is the overall goal? Answer with the label only.
            """).content
        let line = raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty && !$0.hasPrefix("```") } ?? ""
        return line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`.*- "))
            .replacingOccurrences(of: "^(Label|Goal):\\s*", with: "", options: .regularExpression)
    }
}
