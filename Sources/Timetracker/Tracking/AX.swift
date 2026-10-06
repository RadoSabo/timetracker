import AppKit
import ApplicationServices

/// Accessibility helpers: window titles and, for Electron apps, the web area title that carries the real context.
enum AX {
    static var trusted: Bool { AXIsProcessTrusted() }
    static func requestTrust() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    static func attribute(_ el: AXUIElement, _ name: String) -> AnyObject? {
        var v: AnyObject?
        return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
    }
    static func title(_ el: AXUIElement) -> String? { attribute(el, kAXTitleAttribute) as? String }
    static func children(_ el: AXUIElement) -> [AXUIElement] { attribute(el, kAXChildrenAttribute) as? [AXUIElement] ?? [] }

    static func focusedWindow(pid: pid_t) -> AXUIElement? {
        attribute(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute).map { $0 as! AXUIElement }
    }
    static func focusedWindowTitle(pid: pid_t) -> String? { focusedWindow(pid: pid).flatMap(title) }

    static func windowTitles(bundleId: String) -> [String] {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
              let wins = attribute(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        return wins.compactMap(title)
    }

    /// Electron/Chromium builds its accessibility tree only for clients that ask for it explicitly.
    static func enableManualAccessibility(pid: pid_t) {
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// First non-empty AXWebArea title (e.g. the Claude conversation name), focused window first.
    static func webAreaTitle(pid: pid_t) -> String? {
        func find(_ el: AXUIElement, depth: Int) -> String? {
            if attribute(el, kAXRoleAttribute) as? String == "AXWebArea", let t = title(el), !t.isEmpty { return t }
            guard depth < 14 else { return nil }
            for k in children(el) { if let f = find(k, depth: depth + 1) { return f } }
            return nil
        }
        let all = attribute(AXUIElementCreateApplication(pid), kAXWindowsAttribute) as? [AXUIElement] ?? []
        let windows = (focusedWindow(pid: pid).map { [$0] } ?? []) + all
        return windows.lazy.compactMap { find($0, depth: 0) }.first
    }

    /// Depth-first list of (role, first non-empty of title/value/description), capped at `limit` nodes.
    static func flatten(_ root: AXUIElement, limit: Int) -> [(role: String, text: String)] {
        var out: [(role: String, text: String)] = []
        func walk(_ el: AXUIElement, depth: Int) {
            guard out.count < limit, depth < 30 else { return }
            let text = [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute].lazy.compactMap { attribute(el, $0) as? String }.first { !$0.isEmpty } ?? ""
            out.append((attribute(el, kAXRoleAttribute) as? String ?? "", text))
            for k in children(el) { walk(k, depth: depth + 1) }
        }
        walk(root, depth: 0)
        return out
    }

    /// Debug: writing a bundle id into `dump-ax.txt` makes the tracker dump that app's window tree into `ax-dump.txt`.
    enum Dump {
        static let trigger = DB.dir.appendingPathComponent("dump-ax.txt")
        static let output = DB.dir.appendingPathComponent("ax-dump.txt")

        static func checkTrigger() {
            guard let bundleId = try? String(contentsOf: trigger, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                  !bundleId.isEmpty else { return }
            try? FileManager.default.removeItem(at: trigger)
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
                try? "app not running: \(bundleId)".write(to: output, atomically: true, encoding: .utf8); return
            }
            var out = ""
            let wins = attribute(AXUIElementCreateApplication(app.processIdentifier), kAXWindowsAttribute) as? [AXUIElement] ?? []
            for (i, w) in wins.enumerated() { out += "=== window \(i)\n"; walk(w, depth: 0, into: &out) }
            try? out.write(to: output, atomically: true, encoding: .utf8)
        }

        private static func walk(_ el: AXUIElement, depth: Int, into out: inout String) {
            guard depth < 25, out.count < 400_000 else { return }
            let text = [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute]
                .compactMap { (attribute(el, $0) as? String) ?? (attribute(el, $0) as? NSNumber)?.stringValue }
                .filter { !$0.isEmpty }.map { String($0.prefix(100)).replacingOccurrences(of: "\n", with: "⏎") }.joined(separator: " | ")
            let flags = [kAXSelectedAttribute, kAXFocusedAttribute, "AXExpanded"].filter { (attribute(el, $0) as? Bool) == true }.map { "[\($0.dropFirst(2))]" }.joined()
            if !text.isEmpty || depth < 3 { out += String(repeating: "  ", count: depth) + "\(attribute(el, kAXRoleAttribute) as? String ?? "?")\(flags) \(text)\n" }
            for k in children(el) { walk(k, depth: depth + 1, into: &out) }
        }
    }
}
