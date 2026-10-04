import SwiftUI

// MARK: - Widget Tile

struct WidgetTile: View {
  let widget: WidgetItem
  let rect: CGRect
  let cornerRadius: CGFloat
  let shouldAnimateFrame: Bool

  var body: some View {
    RoundedRectangle(
      cornerRadius: cornerRadius,
      style: .continuous
    )
    .fill(widget.color)
    .frame(
      width: max(rect.width, 0),
      height: max(rect.height, 0)
    )
    .position(
      x: rect.midX,
      y: rect.midY
    )
    .animation(
      shouldAnimateFrame
        ? LayoutConfiguration.previewAnimation
        : nil,
      value: rect
    )
  }
}
