import SwiftUI

/// Something the user has to fix before tracking works fully, with a button that does it.
struct Issue: Identifiable {
    var id: String { title }
    var title: String
    var detail: String
    var action: String
    var run: () -> Void

    static func current(openSettings: @escaping () -> Void) -> [Issue] {
        var out: [Issue] = []
        if !AX.trusted {
            out.append(Issue(title: "Window titles can't be read",
                             detail: "Turn on Timetracker in Privacy & Security → Accessibility. If it's already on, remove it and add /Applications/Timetracker.app again.",
                             action: "Open Accessibility settings", run: openAccessibilitySettings))
        }
        if !Hooks.installed {
            out.append(Issue(title: "Claude Code sessions aren't tracked",
                             detail: "The hooks in ~/.claude/settings.json are missing. They install at launch; if this stays, check the file is valid JSON.",
                             action: "Install hooks", run: Hooks.installIfNeeded))
        } else if !Hooks.zshInstalled {
            out.append(Issue(title: "Shell commands aren't recorded", detail: "The zsh hook is missing from ~/.zshrc.", action: "Install hook", run: Hooks.installIfNeeded))
        }
        if !Summarizer.available {
            out.append(Issue(title: "Session names use the first prompt",
                             detail: "Turn on Apple Intelligence to let the on-device model name sessions that Claude Code hasn't titled.",
                             action: "Open Apple Intelligence settings", run: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!) }))
        }
        if Store.shared.billableProjects().isEmpty {
            out.append(Issue(title: "No project is billable yet", detail: "Mark the client project as billable and set its hourly rate to build invoices.",
                             action: "Set up projects", run: openSettings))
        }
        return out
    }
}

func openAccessibilitySettings() {
    AX.requestTrust()
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
}

struct IssuesBanner: View {
    @EnvironmentObject var store: Store
    @Binding var tab: Tab
    var body: some View {
        let _ = store.tick
        let issues = Issue.current { tab = .settings }
        if !issues.isEmpty {
            VStack(spacing: 1) {
                ForEach(issues) { i in
                    HStack(alignment: .center, spacing: 12) {
                        Rectangle().fill(Theme.warn).frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(i.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                            Text(i.detail).font(.system(size: 11)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 20)
                        Button(i.action, action: i.run).controlSize(.small)
                    }
                    .padding(.vertical, 8).padding(.trailing, Theme.gutter)
                    .background(Theme.surface)
                }
            }
        }
    }
}
