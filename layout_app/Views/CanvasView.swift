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
  /// キャンバス内を2周（720°）指でなぞった時に呼ばれる
  var onSwirl: (() -> Void)? = nil

  // 渦巻き検知のための状態（ジェスチャー1回分だけCanvasView内で保持）
  @State private var canvasSize: CGSize = .zero
  // 角度差の符号付き合計。時計回り・反時計回りのどちらでも2周で発動する。
  @State private var swirlAccumulated: CGFloat = 0
  @State private var swirlLastAngle: CGFloat? = nil
  // 閾値到達後、同じドラッグ中に複数回シャッフルしないためのラッチ。
  @State private var swirlTriggered = false

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
          .onAppear {
            canvasSize = g.size
          }
          .onChange(of: g.size) { newSize in
            canvasSize = newSize
          }
      }
    )
    .clipShape(
      RoundedRectangle(
        cornerRadius: 24,
        style: .continuous
      )
    )
    .simultaneousGesture(
      // 渦巻き検知：ウィジェットまたはスロットをドラッグ中に並列で動作する
      DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .onChanged { value in
          // 選択モード中、またはドラッグ中でない場合は無効
          guard !isSelectionMode, onSwirl != nil, !swirlTriggered else { return }
          guard draggingWidgetID != nil || previewSlot != nil else { return }

          let currentSize = canvasSize == .zero ? CGSize(width: 270, height: 360) : canvasSize
          let cx = currentSize.width / 2
          let cy = currentSize.height / 2
          let dx = value.location.x - cx
          let dy = value.location.y - cy
          let radius = sqrt(dx * dx + dy * dy)

          // 中心に近すぎる（50pt以内）指の動きは誤判定回避のためスキップ
          guard radius > 50 else {
            swirlLastAngle = nil
            return
          }

          let angle = atan2(dy, dx)

          if let last = swirlLastAngle {
            var delta = angle - last
            // 角度の折り返しを補正（-π〜π の範囲に正規化）
            if delta > .pi  { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }

            swirlAccumulated += delta

            // 2周（±720° = ±4π）に達したらシャッフル発動
            if abs(swirlAccumulated) >= 4 * .pi {
              swirlTriggered = true
              UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
              onSwirl?()
            }
          }

          swirlLastAngle = angle
        }
        .onEnded { _ in
          resetSwirl()
        }
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

  private func resetSwirl() {
    // DragGestureの終了ごとに検知状態を捨て、次のドラッグを独立して判定する。
    swirlAccumulated = 0
    swirlLastAngle = nil
    swirlTriggered = false
  }
}
