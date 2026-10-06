import SwiftUI

/// Design tokens. Cool graphite surfaces, slate ink, one ultramarine accent; project colors carry the rest.
enum Theme {
    static let canvas = Color(light: 0xEEF0F3, dark: 0x15181D)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1D2127)
    static let sunken = Color(light: 0xE4E7EC, dark: 0x0F1216)
    static let ink = Color(light: 0x1B2430, dark: 0xE6E9EE)
    static let muted = Color(light: 0x5B6675, dark: 0x9AA3AF)
    static let faint = Color(light: 0xC9CED6, dark: 0x373D46)
    static let accent = Color(light: 0x3347D6, dark: 0x8190FF)
    static let warn = Color(light: 0xB4541C, dark: 0xF0A060)
    /// Something works (permission granted, hook installed).
    static let ok = Color(light: 0x2E8A57, dark: 0x5CC48A)
    /// Warm card behind "what is being tracked right now".
    static let warm = Color(light: 0xFBF3E8, dark: 0x2B251C)

    static let gutter: CGFloat = 20
    static let radius: CGFloat = 6
}

extension Project {
    /// Muted, evenly spaced hues that stay distinguishable on the ribbon in light and dark mode.
    static let palette: [Color] = [0x3347D6, 0xD98A1F, 0x2E9E6B, 0xA8457E, 0x1F8FB3, 0x7A6BD1, 0xC2542D, 0x6F8E2A, 0x4A6378, 0xB8912E].map(Color.init(hex:))
    var color: Color { Project.palette[colorIndex % Project.palette.count] }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

extension Font {
    /// Time and money figures: SF Expanded with tabular digits, like a punch-clock dial.
    static func figure(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.expanded).monospacedDigit()
    }
    static let heading = Font.system(size: 22, weight: .semibold).width(.expanded)
    static let label = Font.system(size: 12, weight: .medium)
}

/// Diagonal hatching: the visual mark for manual time everywhere in the app.
struct Hatch: View {
    var color: Color
    var spacing: CGFloat = 5
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x = -size.height
            while x < size.width { path.move(to: CGPoint(x: x, y: size.height)); path.addLine(to: CGPoint(x: x + size.height, y: 0)); x += spacing }
            ctx.stroke(path, with: .color(color), lineWidth: 1.2)
        }
        .background(color.opacity(0.14))
    }
}
