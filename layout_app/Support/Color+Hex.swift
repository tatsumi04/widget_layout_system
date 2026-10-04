import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
  init(hex: String) {
    let h = hex.trimmingCharacters(
      in: CharacterSet.alphanumerics.inverted
    )

    var int: UInt64 = 0
    Scanner(string: h).scanHexInt64(&int)

    self.init(
      red: Double((int >> 16) & 0xFF) / 255,
      green: Double((int >> 8) & 0xFF) / 255,
      blue: Double(int & 0xFF) / 255
    )
  }
}
