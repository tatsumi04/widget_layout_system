import SwiftUI

// MARK: - Empty Placeholder View

struct EmptyPlaceholderView: View {
  var body: some View {
    ZStack {
      RoundedRectangle(
        cornerRadius: LayoutEngine.cornerRadius,
        style: .continuous
      )
      .strokeBorder(
        Color.secondary.opacity(0.3),
        style: StrokeStyle(
          lineWidth: 2,
          dash: [8]
        )
      )

      VStack(spacing: 10) {
        Text("👋")
          .font(.system(size: 44))
          .padding(.bottom, 2)

        Text(
          "Hi\nDrag and Drop your widget to unleash your creativity!"
        )
        .font(.subheadline.weight(.medium))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      }
    }
    .frame(
      maxWidth: .infinity,
      maxHeight: .infinity
    )
    .padding(LayoutEngine.spacing)
  }
}
