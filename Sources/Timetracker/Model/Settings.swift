import Foundation

enum OverlapPolicy: String, CaseIterable, Identifiable {
    case billBoth = "Bill both", exclusive = "Exclusive"
    var id: String { rawValue }
}

/// User settings backed by the `setting` table, plus tuning constants.
enum Settings {
    private static var db: DB { DB.shared }

    static var idleMinutes: Double {
        get { Double(db.setting("idle_minutes") ?? "") ?? 5 }
        set { db.setSetting("idle_minutes", "\(newValue)") }
    }
    static var roundingMinutes: Int {
        get { Int(db.setting("rounding_minutes") ?? "") ?? 30 }
        set { db.setSetting("rounding_minutes", "\(newValue)") }
    }
    static var overlapPolicy: OverlapPolicy {
        get { OverlapPolicy(rawValue: db.setting("overlap_policy") ?? "") ?? .billBoth }
        set { db.setSetting("overlap_policy", newValue.rawValue) }
    }
    static var workCalendars: Set<String> {
        get { Set(lines(db.setting("work_calendars"))) }
        set { db.setSetting("work_calendars", newValue.joined(separator: "\n")) }
    }
    static var fullPromptsInExport: Bool {
        get { db.setting("full_prompts") == "1" }
        set { db.setSetting("full_prompts", newValue ? "1" : "0") }
    }
    static var launchAtLogin: Bool {
        get { db.setting("launch_at_login") != "0" }
        set { db.setSetting("launch_at_login", newValue ? "1" : "0") }
    }

    /// Activities shorter than this are window flicking: hidden in Memory and ignored for the unassigned count, but still counted in time.
    static let minVisibleSeconds: Double = 60
    /// Memory cards (one app over a stretch) shorter than this are hidden.
    static let minMemoryCardSeconds: Double = 120
    /// Gaps inside a project's day shorter than this are closed; longer ones up to `breakMaxMinutes` become a Break.
    static let fillGapMinutes: Double = 30
    static let breakMaxMinutes: Double = 90
    static var fillGapSeconds: Seconds { fillGapMinutes * 60 }
    static var breakMaxSeconds: Seconds { breakMaxMinutes * 60 }
    /// Claude Code sessions with no Stop for this long are treated as finished.
    static let maxRunHours: Double = 3
    static var maxRunSeconds: Double { maxRunHours * 3600 }

    private static func lines(_ s: String?) -> [String] {
        (s ?? "").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
