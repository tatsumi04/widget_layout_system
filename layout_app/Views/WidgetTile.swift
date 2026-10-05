import SwiftUI

// MARK: - Widget Tile

struct WidgetTile: View {
  let widget: WidgetItem
  let rect: CGRect
  let cornerRadius: CGFloat
  let shouldAnimateFrame: Bool
  var isSelectionMode: Bool = false
  var isSelected: Bool = false

  var body: some View {
    let minDimension = min(rect.width, rect.height)
    let badgeSize: CGFloat = minDimension < 60 ? 18 : 22
    let badgePadding: CGFloat = minDimension < 60 ? 4 : 8

    RoundedRectangle(
      cornerRadius: cornerRadius,
      style: .continuous
    )
    .fill(widget.color)
    .overlay(
      RoundedRectangle(
        cornerRadius: cornerRadius,
        style: .continuous
      )
      .strokeBorder(
        isSelected ? Color.white : Color.clear,
        lineWidth: 3
      )
    )
    .overlay(
      RoundedRectangle(
        cornerRadius: cornerRadius,
        style: .continuous
      )
      .strokeBorder(
        isSelected ? Color.black.opacity(0.2) : Color.clear,
        lineWidth: 1
      )
    )
    .overlay(alignment: .topTrailing) {
      if isSelectionMode {
        ZStack {
          Circle()
            .fill(isSelected ? Color.blue : Color.black.opacity(0.25))
            .frame(width: badgeSize, height: badgeSize)

          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: badgeSize * 0.55, weight: .bold))
              .foregroundColor(.white)
          } else {
            Circle()
              .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
              .frame(width: badgeSize, height: badgeSize)
          }
        }
        .padding(badgePadding)
      }
    }
    .shadow(
      color: isSelected ? Color.black.opacity(0.25) : Color.clear,
      radius: isSelected ? 6 : 0,
      y: isSelected ? 3 : 0
    )
    .scaleEffect(isSelectionMode && isSelected ? 0.96 : 1.0)
    .frame(
      width: max(rect.width, 0),
      height: max(rect.height, 0)
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
    .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
  }
}
