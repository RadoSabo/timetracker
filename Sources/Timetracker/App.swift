import SwiftUI
import ServiceManagement

@main
struct TimetrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var store = Store.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPopover().environmentObject(store)
        } label: {
            MenuLabel().environmentObject(store)
        }
        .menuBarExtraStyle(.window)
        Window("Timetracker", id: "main") {
            MainView().environmentObject(store).frame(minWidth: 1100, minHeight: 700)
        }
        .defaultSize(width: 1300, height: 820)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AX.requestTrust()
        Tracker.shared.start()
        Hooks.installIfNeeded()
        EventIngest.shared.start()
        Summarizer.shared.summarizeRecent()
        DaySummary.shared.startSchedule()
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in Store.shared.closeStaleRuns() }
        // Launch at login is on by default; re-registered on every launch so a moved .app keeps working.
        if Settings.launchAtLogin { try? SMAppService.mainApp.register() }
        // Menu bar app: show in Dock only while the main window is open.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { n in
            guard (n.object as? NSWindow)?.title == "Timetracker" else { return }
            DispatchQueue.main.async {
                if !NSApp.windows.contains(where: { $0.title == "Timetracker" && $0.isVisible }) { NSApp.setActivationPolicy(.accessory) }
            }
        }
    }

    /// Spotlight / Finder launch while already running lands here.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NotificationCenter.default.post(name: .openMain, object: nil)
        return true
    }
}

extension Notification.Name { static let openMain = Notification.Name("openMain") }

func showMain(_ openWindow: OpenWindowAction) {
    NSApp.setActivationPolicy(.regular)
    openWindow(id: "main")
    NSApp.activate(ignoringOtherApps: true)
    NSApp.windows.first { $0.title == "Timetracker" }?.makeKeyAndOrderFront(nil)
}

struct MenuLabel: View {
    static let icon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "png"), let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true; img.size = NSSize(width: 18, height: 18); return img
    }()
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Group {
            // Paused by the user: a pause icon and the time left (the tracker updates it; a TimelineView here loops forever).
            if store.pausedUntil != nil {
                HStack(spacing: 3) { Image(systemName: "pause.circle.fill"); Text(store.pauseLeft) }
            } else if let img = MenuLabel.icon { Image(nsImage: img) } else { Image(systemName: "clock.badge.checkmark") }
        }
        .task {
            guard DB.shared.setting("first_run") == nil else { return }
            DB.shared.setSetting("first_run", "done")
            showMain(openWindow)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMain)) { _ in showMain(openWindow) }
    }
}
