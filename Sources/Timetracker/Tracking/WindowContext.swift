import AppKit

/// Per-app readers that replace a useless window title with the real context, read via Accessibility.
enum WindowContext {
    static let claude = "com.anthropic.claudefordesktop"
    static let superset = "com.superset.desktop"
    static let teams = "com.microsoft.teams2"
    /// Apps with a reader; all are Electron/WebView apps that need AXManualAccessibility.
    static let apps: Set<String> = [claude, superset, teams]

    static func read(bundleId: String, pid: pid_t) -> String? {
        switch bundleId {
        case claude: return AX.webAreaTitle(pid: pid).map(claudeTitle)
        case teams: return AX.webAreaTitle(pid: pid).map(teamsTitle)
        case superset: return supersetTitle(pid: pid)
        default: return nil
        }
    }

    /// "Acme - Claude Code" → "Acme (Code)", "Best todo app - Claude" → "Best todo app (Chat)".
    static func claudeTitle(_ raw: String) -> String {
        if raw.hasSuffix(" - Claude Code") { return String(raw.dropLast(14)) + " (Code)" }
        if raw.hasSuffix(" - Claude") { return String(raw.dropLast(9)) + " (Chat)" }
        return raw
    }

    /// "Chat | Jane Smith | Microsoft Teams" → "Chat | Jane Smith".
    static func teamsTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"\s*\|\s*Microsoft Teams$"#, with: "", options: .regularExpression)
    }

    /// Superset exposes no active-workspace marker; the focused tab label and the git branch are the reliable bits.
    static func supersetTitle(pid: pid_t) -> String? {
        guard let win = AX.focusedWindow(pid: pid) else { return nil }
        let nodes = AX.flatten(win, limit: 600)
        let tab = nodes.indices.first { nodes[$0].role == "AXButton" && nodes[$0].text == "Close tab" }
            .flatMap { i in nodes[..<i].last { $0.role == "AXStaticText" && !$0.text.isEmpty }?.text }
        let branch = nodes.indices.first { nodes[$0].role == "AXStaticText" && nodes[$0].text == "vs" }
            .flatMap { i in nodes[(i + 1)...].first { $0.role == "AXPopUpButton" }?.text }
        let parts = [tab, branch.map { "branch " + $0 }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
