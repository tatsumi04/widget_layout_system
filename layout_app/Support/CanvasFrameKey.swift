import SwiftUI

// MARK: - Canvas Frame Preference Key

struct CanvasFrameKey: PreferenceKey {
  static var defaultValue: CGRect = .zero

  static func reduce(
    value: inout CGRect,
    nextValue: () -> CGRect
  ) {
    let next = nextValue()
    if next != .zero {
      value = next
    }
  }
}
