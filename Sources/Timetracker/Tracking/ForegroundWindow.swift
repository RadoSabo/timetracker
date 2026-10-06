import AppKit

/// What is in front: the window title (or the app-specific context from WindowContext) and, for Chrome, the tab URL.
final class ForegroundWindow {
    private var chrome: (title: String, url: String?) = ("", nil)
    private var contextCache: [pid_t: String] = [:]
    private var manualAXEnabled: Set<pid_t> = []
    private static let chromeBundle = "com.google.Chrome"

    /// Window title, or the app-specific context (Claude conversation, Superset tab, Teams chat), refreshed every 5 s.
    func title(_ app: NSRunningApplication, tick: Int) -> String {
        let pid = app.processIdentifier
        let bundle = app.bundleIdentifier ?? ""
        if WindowContext.apps.contains(bundle), tick % 5 == 0 || contextCache[pid] == nil {
            if manualAXEnabled.insert(pid).inserted { AX.enableManualAccessibility(pid: pid) }
            let ctx = WindowContext.read(bundleId: bundle, pid: pid)
            if ctx != contextCache[pid] { Log.write("ax", "\(app.localizedName ?? bundle) context: \(ctx ?? "nil")") }
            contextCache[pid] = ctx
        }
        if let t = contextCache[pid], !t.isEmpty { return t }
        return AX.focusedWindowTitle(pid: pid) ?? ""
    }

    /// AppleScript into Chrome is slow, so the URL is refreshed only when the tab title changes.
    private func chromeURL(for title: String) -> String? {
        if title != chrome.title {
            var err: NSDictionary?
            let script = NSAppleScript(source: "tell application \"Google Chrome\" to get URL of active tab of front window")
            chrome = (title, script?.executeAndReturnError(&err).stringValue)
        }
        return chrome.url
    }

    func url(_ app: NSRunningApplication, title: String) -> String? {
        app.bundleIdentifier == Self.chromeBundle ? chromeURL(for: title) : nil
    }
}
