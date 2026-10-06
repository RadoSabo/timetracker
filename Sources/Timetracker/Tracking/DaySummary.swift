import Foundation

/// AI day summary (Timely-style drafts): sends the day's raw data to `claude -p` and stores the proposed entries as Drafts.
/// Runs automatically for yesterday once per day, or on demand from the Day view.
final class DaySummary: ObservableObject {
    static let shared = DaySummary()
    private let store = Store.shared
    @Published private(set) var running: Set<String> = []
    @Published private(set) var lastError: [String: String] = [:]

    static let model = "sonnet"

    func startSchedule() {
        runYesterdayIfNeeded()
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in self?.runYesterdayIfNeeded() }
    }

    /// Debug: writing a day ("2026-09-29") into `summarize.txt` runs the summary for it and saves the input to `day-input.txt`.
    static let trigger = DB.dir.appendingPathComponent("summarize.txt")
    func checkTrigger() {
        guard let day = try? String(contentsOf: DaySummary.trigger, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !day.isEmpty else { return }
        try? FileManager.default.removeItem(at: DaySummary.trigger)
        try? DayInput.build(day: day, store: store).write(to: DB.dir.appendingPathComponent("day-input.txt"), atomically: true, encoding: .utf8)
        summarize(day: day)
    }

    private func runYesterdayIfNeeded() {
        let day = Day.key(Date().addingTimeInterval(-86400))
        guard store.db.setting("summary_done_\(day)") == nil, !store.activities(day: day).isEmpty else { return }
        summarize(day: day)
    }

    func summarize(day: String) {
        guard !running.contains(day) else { return }
        running.insert(day); lastError[day] = nil
        let input = DayInput.build(day: day, store: store)
        Log.write("day-summary", "\(day): sending \(input.count) chars to claude -p (\(DaySummary.model))")
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try Self.runClaude(prompt: DaySummaryPrompt.instructions + "\n\n" + input) }
            DispatchQueue.main.async {
                self.running.remove(day)
                switch result {
                case .success(let text): self.store(text, day: day)
                case .failure(let e): self.fail(day, "\(e)")
                }
            }
        }
    }

    private func store(_ text: String, day: String) {
        guard let drafts = DaySummaryPrompt.parse(text, day: day, projects: store.projects(includeHidden: true)) else {
            return fail(day, "unparseable answer: \(text.prefix(300))")
        }
        store.replaceDrafts(day: day, with: drafts)
        store.db.setSetting("summary_done_\(day)", "\(now())")
        Log.write("day-summary", "\(day): \(drafts.count) drafts")
    }

    private func fail(_ day: String, _ message: String) {
        lastError[day] = message
        Log.write("day-summary", "\(day) failed: \(message)")
    }

    /// Runs `claude -p` through a login shell (for PATH) with the prompt on stdin.
    private static func runClaude(prompt: String) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", "claude -p --model \(model)"]
        p.currentDirectoryURL = DB.dir
        p.environment = ProcessInfo.processInfo.environment.merging(["TIMETRACKER_INTERNAL": "1"]) { $1 }
        let input = Pipe(), output = Pipe(), errors = Pipe()
        p.standardInput = input; p.standardOutput = output; p.standardError = errors
        try p.run()
        input.fileHandleForWriting.write(Data(prompt.utf8)); try input.fileHandleForWriting.close()
        let out = output.fileHandleForReading.readDataToEndOfFile()
        let err = errors.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw NSError(domain: "claude", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: String(decoding: err + out, as: UTF8.self).prefix(400)])
        }
        return String(decoding: out, as: UTF8.self)
    }

}
