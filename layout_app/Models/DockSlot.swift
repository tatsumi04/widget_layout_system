import SwiftUI

// MARK: - Dock Slot

struct DockSlot: Identifiable {
  let id: String
  let color: Color

  static let all: [DockSlot] = [
    DockSlot(id: "cyan", color: Color(hex: "#00b4f8")),
    DockSlot(id: "pink", color: Color(hex: "#ff3f7f")),
    DockSlot(id: "yellow", color: Color(hex: "#fed330")),
    DockSlot(id: "lime", color: Color(hex: "#9fe100")),
    DockSlot(id: "orange", color: Color(hex: "#ff6d00")),
  ]
}
