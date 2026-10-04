import SwiftUI

// MARK: - Canvas View

struct CanvasView: View {
  let layout: LayoutNode?
  let widgets: [WidgetItem]
  let previewSlot: DockSlot?
  let draggingWidgetID: String?
  let isDraggingOutside: Bool
  let shouldAnimateLayout: Bool
  let onWidgetDragChanged: (WidgetItem, CGPoint) -> Void
  let onWidgetDragEnded: (WidgetItem, CGPoint) -> Void

  var body: some View {
    GeometryReader { geo in
      let size = geo.size
      let rects = LayoutEngine.frames(
        for: layout,
        in: size
      )
      let orderedIDs = LayoutEngine.leafIDs(
        in: layout
      )

      ZStack(alignment: .topLeading) {
        // 1個だけ配置されている状態で、そのウィジェットを外へドラッグしたら、
        // Gesture を維持したまま空状態のプレースホルダーを表示する。
        let isRemovingLastWidget =
          draggingWidgetID != nil &&
          widgets.count == 1 &&
          isDraggingOutside

        if layout == nil || isRemovingLastWidget {
          EmptyPlaceholderView()
        }

        ForEach(orderedIDs, id: \.self) { id in
          if let rect = rects[id],
            let widget = resolveWidget(for: id) {

            let isPreview =
              id == LayoutConfiguration.previewWidgetID

            let tile = WidgetTile(
              widget: widget,
              rect: rect,
              cornerRadius: LayoutEngine.cornerRadius,
              shouldAnimateFrame: shouldAnimateLayout
            )

            if isPreview {
              tile
            } else {
              // 外へドラッグ中は元のタイルを透明にするが、ビューは保持して
              // Gesture が最後まで継続するようにする。
              let isHiddenDraggedTile =
                draggingWidgetID == widget.id &&
                isDraggingOutside

              tile
                .opacity(isHiddenDraggedTile ? 0 : 1)
                .gesture(
                  DragGesture(
                    minimumDistance: 1,
                    coordinateSpace: .global
                  )
                  .onChanged { value in
                    onWidgetDragChanged(widget, value.location)
                  }
                  .onEnded { value in
                    onWidgetDragEnded(widget, value.location)
                  }
                )
            }
          }
        }
      }
    }
    .aspectRatio(3 / 4, contentMode: .fit)
    .frame(maxWidth: 360)
    .background(
      GeometryReader { g in
        Color(.systemBackground)
          .preference(
            key: CanvasFrameKey.self,
            value: g.frame(in: .global)
          )
      }
    )
    .clipShape(
      RoundedRectangle(
        cornerRadius: 24,
        style: .continuous
      )
    )
  }

  private func resolveWidget(for id: String) -> WidgetItem? {
    if id == LayoutConfiguration.previewWidgetID,
      let slot = previewSlot {
      return WidgetItem(
        id: LayoutConfiguration.previewWidgetID,
        color: slot.color
      )
    }

    return widgets.first { $0.id == id }
  }
}
