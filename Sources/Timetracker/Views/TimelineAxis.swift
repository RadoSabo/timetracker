import SwiftUI

/// Half-hour labels on the Day timeline's clock.
struct TimelineAxis: View {
    var firstHour: Int
    var hours: Int
    var scale: TimeScale
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<(hours * 2), id: \.self) { i in
                Text(String(format: "%02d:%02d", firstHour + i / 2, i % 2 * 30)).font(.figure(10, .regular)).foregroundStyle(Theme.muted)
                    .offset(y: scale.y(scale.origin + Double(i) * 1800) - 6)
            }
        }
    }
}

/// Hour (stronger) and half-hour lines across the columns.
struct TimelineGrid: View {
    var hours: Int
    var scale: TimeScale
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<(hours * 2), id: \.self) { i in
                Rectangle().fill(Theme.faint.opacity(i % 2 == 0 ? 0.7 : 0.35)).frame(height: 0.5).offset(y: scale.y(scale.origin + Double(i) * 1800))
            }
        }
    }
}

/// Current time across the columns, its label over the axis.
struct NowLine: View {
    var scale: TimeScale
    var leading: CGFloat
    var body: some View {
        let ts = now()
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.ink).frame(height: 1.5).padding(.leading, leading)
            Text(clock(ts)).font(.figure(10)).foregroundStyle(Theme.surface).padding(.horizontal, 5).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.ink)).offset(y: -8)
        }
        .offset(y: scale.y(ts))
    }
}
