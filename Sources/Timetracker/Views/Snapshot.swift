import AppKit

/// Debug: writing a tab name ("Day", "Week", "Invoice", "Settings") into `snapshot.txt` opens the main window
/// on that tab and renders it into `snapshot.png`, so the UI can be reviewed without screen recording rights.
enum Snapshot {
    static let trigger = DB.dir.appendingPathComponent("snapshot.txt")
    static let output = DB.dir.appendingPathComponent("snapshot.png")

    static func checkTrigger() {
        guard let tab = try? String(contentsOf: trigger, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !tab.isEmpty else { return }
        try? FileManager.default.removeItem(at: trigger)
        NotificationCenter.default.post(name: .openMain, object: nil)
        NotificationCenter.default.post(name: .selectTab, object: tab)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { render() }
    }

    private static func render() {
        guard let view = NSApp.windows.first(where: { $0.title == "Timetracker" && $0.isVisible })?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: output)
    }
}
