import SwiftUI

/// Draggable gap between two Day timeline columns; reports the drag's horizontal translation.
struct SplitHandle: View {
    var width: CGFloat
    var onDrag: (CGFloat) -> Void
    var onEnd: () -> Void
    @Local var hover = false

    var body: some View {
        Rectangle().fill(Color.clear).frame(width: width).contentShape(Rectangle())
            .overlay(Rectangle().fill(hover ? Theme.accent.opacity(0.6) : Color.clear).frame(width: 2))
            .onHover { inside in
                hover = inside
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(DragGesture(minimumDistance: 1).onChanged { onDrag($0.translation.width) }.onEnded { _ in onEnd() })
    }
}
