import SwiftUI

struct ProjectDot: View {
    var project: Project?
    var size: CGFloat = 8
    var body: some View { Circle().fill(project?.color ?? Theme.faint).frame(width: size, height: size) }
}

/// Tracked vs manual shown by shape: a solid swatch or a hatched one, followed by the duration.
struct OriginMark: View {
    var origin: TimeOrigin
    var seconds: Seconds
    var color: Color
    var body: some View {
        HStack(spacing: 4) {
            Group {
                if origin == .manual { Hatch(color: color, spacing: 3) } else { color }
            }
            .frame(width: 10, height: 10).clipShape(RoundedRectangle(cornerRadius: 2))
            Text((origin == .manual && seconds > 0 ? "+" : "") + hm(seconds)).font(.figure(11, .regular)).foregroundStyle(Theme.muted)
        }
        .help(origin == .manual ? "Added by hand" : "Measured by the tracker")
    }
}

struct Chip: View {
    var text: String
    var color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.label).foregroundStyle(Theme.ink)
        }
    }
}

/// Icon of an app by its display name (cached).
struct AppIcon: View {
    private static var cache: [String: NSImage] = [:]
    var app: String
    var size: CGFloat = 18
    var body: some View {
        Group {
            if let img = AppIcon.icon(app) { Image(nsImage: img).resizable() } else { Image(systemName: "app.dashed").foregroundStyle(Theme.muted) }
        }.frame(width: size, height: size)
    }
    private static func icon(_ app: String) -> NSImage? {
        if let c = cache[app] { return c }
        guard let path = NSWorkspace.shared.fullPath(forApplication: app) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: path); cache[app] = img; return img
    }
}

/// Picker of a project id, with an optional "none" entry.
struct ProjectPicker: View {
    var label: String
    var projects: [Project]
    var none: String? = nil
    @Binding var selection: Int64?
    var body: some View {
        Picker(label, selection: $selection) {
            if let none { Text(none).tag(Int64?.none) }
            ForEach(projects) { p in Text(p.name).tag(Int64?.some(p.id)) }
        }
    }
}

/// Previous / today / next with the period title, shared by Day and Week.
struct DateNav: View {
    var title: String
    var subtitle: String
    var onShift: (Int) -> Void
    var onToday: () -> Void
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.heading).foregroundStyle(Theme.ink)
                Text(subtitle).font(.label).foregroundStyle(Theme.muted)
            }
            Spacer()
            HStack(spacing: 4) {
                Button { onShift(-1) } label: { Image(systemName: "chevron.left").frame(width: 22, height: 22) }.help("Previous")
                Button("Today", action: onToday)
                Button { onShift(1) } label: { Image(systemName: "chevron.right").frame(width: 22, height: 22) }.help("Next")
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
    }
}

/// White rounded panel on the canvas, shared by the menu bar popover and the Week view.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
    }
}

/// One thin bar split by share: today's or the week's time per project.
struct SplitBar: View {
    var parts: [(Color, Seconds)]
    var height: CGFloat = 5
    var body: some View {
        let total = max(parts.reduce(0) { $0 + $1.1 }, 1)
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(parts.indices, id: \.self) { i in parts[i].0.frame(width: max(0, geo.size.width * parts[i].1 / total - 1)) }
            }
        }
        .frame(height: height).clipShape(Capsule()).background(Capsule().fill(Theme.sunken))
    }
}
