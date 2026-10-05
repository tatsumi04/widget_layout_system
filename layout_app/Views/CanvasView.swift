import SwiftUI

// MARK: - Canvas View

struct CanvasView: View {
  let layout: LayoutNode?
  let widgets: [WidgetItem]
  let previewSlot: DockSlot?
  let draggingWidgetID: String?
  let isDraggingOutside: Bool
  let shouldAnimateLayout: Bool
  var isSelectionMode: Bool = false
  var selectedWidgetIDs: Set<String> = []
  let onWidgetDragChanged: (WidgetItem, CGPoint) -> Void
  let onWidgetDragEnded: (WidgetItem, CGPoint) -> Void
  var onWidgetTapped: ((WidgetItem) -> Void)? = nil
  var onWidgetLongPressed: ((WidgetItem) -> Void)? = nil

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

            let isSelected = selectedWidgetIDs.contains(widget.id)

            let tile = WidgetTile(
              widget: widget,
              rect: rect,
              cornerRadius: LayoutEngine.cornerRadius,
              shouldAnimateFrame: shouldAnimateLayout,
              isSelectionMode: isSelectionMode,
              isSelected: isSelected
            )

            if isPreview {
              tile
                .position(x: rect.midX, y: rect.midY)
                .animation(
                  shouldAnimateLayout
                    ? LayoutConfiguration.previewAnimation
                    : nil,
                  value: rect
                )
            } else if isSelectionMode {
              // 選択モード中はタップで選択・選択解除を切り替え、ドラッグは無効化する。
              // .positionより前に.contentShapeと.onTapGestureを適用することで、
              // 他のタイルのタップ領域を遮断せず、各ウィジェット領域内のみでタップが反応する。
              tile
                .contentShape(
                  RoundedRectangle(
                    cornerRadius: LayoutEngine.cornerRadius,
                    style: .continuous
                  )
                )
                .onTapGesture {
                  onWidgetTapped?(widget)
                }
                .position(x: rect.midX, y: rect.midY)
                .animation(
                  shouldAnimateLayout
                    ? LayoutConfiguration.previewAnimation
                    : nil,
                  value: rect
                )
            } else {
              // 外へドラッグ中は元のタイルを透明にするが、ビューは保持して
              // Gesture が最後まで継続するようにする。
              let isHiddenDraggedTile =
                draggingWidgetID == widget.id &&
                isDraggingOutside

              tile
                .opacity(isHiddenDraggedTile ? 0 : 1)
                .contentShape(
                  RoundedRectangle(
                    cornerRadius: LayoutEngine.cornerRadius,
                    style: .continuous
                  )
                )
                .simultaneousGesture(
                  LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                      onWidgetLongPressed?(widget)
                    }
                )
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
                .position(x: rect.midX, y: rect.midY)
                .animation(
                  shouldAnimateLayout
                    ? LayoutConfiguration.previewAnimation
                    : nil,
                  value: rect
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
