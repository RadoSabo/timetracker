import Foundation

/// Installs the Claude Code and zsh hooks that append events to events.jsonl. Idempotent; runs on every launch.
enum Hooks {
    static let eventsFile = DB.dir.appendingPathComponent("events.jsonl")
    static let hookScript = DB.dir.appendingPathComponent("tt-hook.sh")
    static let zshFile = DB.dir.appendingPathComponent("tt.zsh")
    static let marker = "# timetracker"
    static let events = ["SessionStart", "UserPromptSubmit", "Stop", "SessionEnd"]
    static var claudeSettings: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json") }
    static var zshrc: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc") }

    static let hookScriptBody = """
    #!/bin/sh
    # Appends one JSON line per Claude Code hook event. Prints nothing (stdout would enter Claude's context).
    # The app's own `claude -p` calls set TIMETRACKER_INTERNAL so they are not tracked as work.
    [ -n "$TIMETRACKER_INTERNAL" ] && { cat >/dev/null; exit 0; }
    printf '{"event":"%s","ts":%s,"payload":' "$1" "$(date +%s)" >> "\(eventsFile.path)"
    tr -d '\\n' >> "\(eventsFile.path)"
    printf '}\\n' >> "\(eventsFile.path)"
    exit 0
    """
    static let zshBody = """
    \(marker)
    _tt_preexec() {
      local c="${1//\\\\/\\\\\\\\}"; c="${c//\\"/\\\\\\"}"; c="${c//$'\\n'/ }"; c="${c//$'\\t'/ }"
      local d="${PWD//\\\\/\\\\\\\\}"; d="${d//\\"/\\\\\\"}"
      printf '{"event":"shell","ts":%s,"payload":{"cwd":"%s","cmd":"%s"}}\\n' "$(date +%s)" "$d" "$c" >> "\(eventsFile.path)" 2>/dev/null
    }
    autoload -Uz add-zsh-hook && add-zsh-hook preexec _tt_preexec
    """

    static var installed: Bool {
        guard FileManager.default.isExecutableFile(atPath: hookScript.path), let hooks = readSettings()["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { (hooks[$0] as? [[String: Any]])?.contains(where: isOurs) == true }
    }
    static var zshInstalled: Bool { (try? String(contentsOf: zshrc, encoding: .utf8))?.contains(marker) == true }

    static func installIfNeeded() {
        do { try install() } catch { Log.write("hooks", "install failed: \(error)") }
    }

    static func install() throws {
        try hookScriptBody.write(to: hookScript, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScript.path)
        try zshBody.write(to: zshFile, atomically: true, encoding: .utf8)
        var json = readSettings()
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var list = (hooks[event] as? [[String: Any]] ?? []).filter { !isOurs($0) }
            list.append(["hooks": [["type": "command", "command": "\"\(hookScript.path)\" \(event)"]]])
            hooks[event] = list
        }
        json["hooks"] = hooks
        try writeSettings(json)
        var rc = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
        if !rc.contains(marker) {
            rc += "\n\(marker)\n[ -f \"\(zshFile.path)\" ] && source \"\(zshFile.path)\"\n"
            try rc.write(to: zshrc, atomically: true, encoding: .utf8)
        }
        Store.shared.refresh()
    }

    static func uninstall() throws {
        var json = readSettings()
        if var hooks = json["hooks"] as? [String: Any] {
            for (event, value) in hooks { hooks[event] = (value as? [[String: Any]])?.filter { !isOurs($0) } ?? value }
            json["hooks"] = hooks
            try writeSettings(json)
        }
        if let rc = try? String(contentsOf: zshrc, encoding: .utf8) {
            try rc.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.contains(marker) && !$0.contains(zshFile.path) }.joined(separator: "\n")
                .write(to: zshrc, atomically: true, encoding: .utf8)
        }
        Store.shared.refresh()
    }

    private static func isOurs(_ entry: [String: Any]) -> Bool {
        (entry["hooks"] as? [[String: Any]])?.contains { ($0["command"] as? String)?.contains(hookScript.path) == true } == true
    }
    private static func readSettings() -> [String: Any] {
        (try? Data(contentsOf: claudeSettings)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
    }
    private static func writeSettings(_ json: [String: Any]) throws {
        try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: claudeSettings)
    }
}
