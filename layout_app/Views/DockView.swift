import SwiftUI

// MARK: - Dock View

struct DockView: View {
  let onDragChanged: (DockSlot, CGPoint) -> Void
  let onDragEnded: (DockSlot, CGPoint) -> Void

  var body: some View {
    HStack(spacing: 16) {
      ForEach(DockSlot.all) { slot in
        Circle()
          .fill(slot.color)
          .overlay(
            Circle()
              .strokeBorder(
                Color.white.opacity(0.3),
                lineWidth: 1.5
              )
          )
          .shadow(
            color: slot.color.opacity(0.45),
            radius: 6,
            x: 0,
            y: 3
          )
          .gesture(
            DragGesture(
              minimumDistance: 1,
              coordinateSpace: .global
            )
            .onChanged { value in
              onDragChanged(slot, value.location)
            }
            .onEnded { value in
              onDragEnded(slot, value.location)
            }
          )
          .frame(width: 48, height: 48)
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
    .background(
      Capsule()
        .fill(.ultraThinMaterial)
        .shadow(
          color: Color.black.opacity(0.12),
          radius: 16,
          x: 0,
          y: 6
        )
    )
  }
}
