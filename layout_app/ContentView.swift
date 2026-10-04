import SwiftUI

// MARK: - Content View

struct ContentView: View {
  @State private var widgets: [WidgetItem] = []
  @State private var layout: LayoutNode?

  @State private var dockDragSlot: DockSlot?
  @State private var dockDragGlobalPos: CGPoint = .zero
  @State private var isDockDragOverCanvas = false

  @State private var canvasDragId: String?
  @State private var canvasDragGlobalPos: CGPoint = .zero

  @State private var canvasGlobalFrame: CGRect = .zero

  // MARK: - Display Layout (Preview)

  private var displayLayout: LayoutNode? {
    // ドックから追加中：キャンバス内にいるときだけ配置プレビューを表示する。
    if dockDragSlot != nil, isDockDragOverCanvas {
      let local = toCanvasLocal(dockDragGlobalPos)

      return LayoutEngine.adding(
        LayoutConfiguration.previewWidgetID,
        to: layout,
        at: local,
        in: canvasGlobalFrame.size
      ) ?? layout
    }

    // 配置済みウィジェットをドラッグ中：元の場所から一度取り除き、
    // ドラッグ位置に再配置して、追加時と同じルールで形状をプレビューする。
    if let draggedID = canvasDragId {
      // キャンバス外でもドラッグ元のビューをツリー内に残す。
      // ビュー自体を取り除くと SwiftUI の Gesture が途中でキャンセルされ、
      // onEnded が呼ばれず削除できないことがある。
      if isOutsideCanvas(canvasDragGlobalPos) {
        return layout
      }

      let remainingLayout =
        LayoutEngine.removing(
          draggedID,
          from: layout
        )

      return LayoutEngine.adding(
        draggedID,
        to: remainingLayout,
        at: toCanvasLocal(canvasDragGlobalPos),
        in: canvasGlobalFrame.size
      ) ?? layout
    }

    return layout
  }

  // MARK: - Body

  var body: some View {
    GeometryReader { rootGeo in
      ZStack {
        Color(.systemBackground)
          .ignoresSafeArea()

        VStack(spacing: 0) {
          Spacer()

          CanvasView(
            layout: displayLayout,
            widgets: widgets,
            previewSlot: dockDragSlot,
            draggingWidgetID: canvasDragId,
            isDraggingOutside: isOutsideCanvas(canvasDragGlobalPos),
            shouldAnimateLayout: dockDragSlot != nil || canvasDragId != nil,
            onWidgetDragChanged: handleCanvasDragChanged,
            onWidgetDragEnded: handleCanvasDragEnded
          )
          .padding(.horizontal, 24)

          Spacer()

          Text("\(widgets.count) 個")
            .font(
              .system(.caption, design: .monospaced)
                .weight(.medium)
            )
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
            .opacity(widgets.isEmpty ? 0 : 1)
            .accessibilityHidden(widgets.isEmpty)

          DockView(
            onDragChanged: handleDockDragChanged,
            onDragEnded: handleDockDragEnded
          )
          .padding(.bottom, 48)
        }

        // キャンバス外ではドラッグ中の円を表示し、内側に入ったら隠す。
        if let slot = dockDragSlot,
          !isDockDragOverCanvas {
          dragCircle(
            color: slot.color,
            globalPosition: dockDragGlobalPos,
            rootFrame: rootGeo.frame(in: .global)
          )
        }

        // 配置済みウィジェットも、削除のためキャンバス外へ運んでいる間は円で追従させる。
        if let draggedID = canvasDragId,
          isOutsideCanvas(canvasDragGlobalPos),
          let draggedWidget = widgets.first(
            where: { $0.id == draggedID }
          ) {
          dragCircle(
            color: draggedWidget.color,
            globalPosition: canvasDragGlobalPos,
            rootFrame: rootGeo.frame(in: .global)
          )
        }
      }
    }
    .onPreferenceChange(CanvasFrameKey.self) { frame in
      canvasGlobalFrame = frame
    }
  }

  // MARK: - Canvas Drag Handlers

  private func handleCanvasDragChanged(widget: WidgetItem, location: CGPoint) {
    canvasDragId = widget.id
    canvasDragGlobalPos = location
  }

  private func handleCanvasDragEnded(widget: WidgetItem, location: CGPoint) {
    var transaction = Transaction()
    transaction.disablesAnimations = true

    withTransaction(transaction) {
      if isOutsideCanvas(location) {
        // 外で離したらアニメーションせず、そのまま削除する。
        widgets.removeAll {
          $0.id == widget.id
        }

        layout = LayoutEngine.removing(
          widget.id,
          from: layout
        )
      } else {
        let remainingLayout =
          LayoutEngine.removing(
            widget.id,
            from: layout
          )

        // 最小サイズ未満になる配置は確定しない。
        if let updatedLayout =
          LayoutEngine.adding(
            widget.id,
            to: remainingLayout,
            at: toCanvasLocal(location),
            in: canvasGlobalFrame.size
          ) {
          layout = updatedLayout
        }
      }

      canvasDragId = nil
    }
  }

  // MARK: - Dock Drag Handlers

  private func handleDockDragChanged(slot: DockSlot, location: CGPoint) {
    dockDragSlot = slot
    dockDragGlobalPos = location
    isDockDragOverCanvas =
      checkIsOverCanvas(location)
  }

  private func handleDockDragEnded(slot: DockSlot, location: CGPoint) {
    var transaction = Transaction()
    transaction.disablesAnimations = true

    withTransaction(transaction) {
      if checkIsOverCanvas(location) {
        let local = toCanvasLocal(location)
        let newWidgetID = UUID().uuidString

        let newWidget = WidgetItem(
          id: newWidgetID,
          color: slot.color
        )

        // 最小サイズ未満になる追加は確定しない。
        if let updatedLayout =
          LayoutEngine.adding(
            newWidgetID,
            to: layout,
            at: local,
            in: canvasGlobalFrame.size
          ) {
          layout = updatedLayout
          widgets.append(newWidget)
        }
      }

      dockDragSlot = nil
      isDockDragOverCanvas = false
    }
  }

  // MARK: - Coordinate Helpers

  private func checkIsOverCanvas(
    _ point: CGPoint
  ) -> Bool {
    guard canvasGlobalFrame != .zero else {
      return false
    }

    return canvasGlobalFrame.contains(point)
  }

  private func toCanvasLocal(
    _ globalPoint: CGPoint
  ) -> CGPoint {
    CGPoint(
      x: globalPoint.x - canvasGlobalFrame.minX,
      y: globalPoint.y - canvasGlobalFrame.minY
    )
  }

  private func isOutsideCanvas(
    _ globalPoint: CGPoint
  ) -> Bool {
    guard canvasGlobalFrame != .zero else {
      return false
    }

    return !canvasGlobalFrame.contains(globalPoint)
  }

  // MARK: - Drag Circle

  private func dragCircle(
    color: Color,
    globalPosition: CGPoint,
    rootFrame: CGRect
  ) -> some View {
    Circle()
      .fill(color)
      .frame(width: 50, height: 50)
      .position(
        x: globalPosition.x - rootFrame.minX,
        y: globalPosition.y - rootFrame.minY
      )
      .allowsHitTesting(false)
  }
}

// MARK: - Preview

#Preview {
  ContentView()
}