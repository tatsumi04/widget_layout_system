import SwiftUI

extension ContentView {
  // MARK: - Canvas Drag

  func handleCanvasDragChanged(widget: WidgetItem, location: CGPoint) {
    guard !isSelectionMode else { return }
    canvasDragId = widget.id
    canvasDragGlobalPos = location
  }

  func handleCanvasDragEnded(widget: WidgetItem, location: CGPoint) {
    if didSwirlDuringDrag {
      didSwirlDuringDrag = false
      canvasDragId = nil
      return
    }

    guard !isSelectionMode else {
      canvasDragId = nil
      return
    }

    withoutAnimation {
      if isOutsideCanvas(location) {
        widgets.removeAll { $0.id == widget.id }
        layout = LayoutEngine.removing(widget.id, from: layout)
      } else {
        let remainingLayout = LayoutEngine.removing(widget.id, from: layout)
        if let updatedLayout = LayoutEngine.adding(
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

  // MARK: - Dock Drag

  func handleDockDragChanged(slot: DockSlot, location: CGPoint) {
    dockDragSlot = slot
    dockDragGlobalPos = location
    isDockDragOverCanvas = checkIsOverCanvas(location)
  }

  func handleDockDragEnded(slot: DockSlot, location: CGPoint) {
    if didSwirlDuringDrag {
      didSwirlDuringDrag = false
      dockDragSlot = nil
      isDockDragOverCanvas = false
      return
    }

    withoutAnimation {
      if checkIsOverCanvas(location) {
        let id = UUID().uuidString
        let widget = WidgetItem(id: id, color: slot.color)

        if let updatedLayout = LayoutEngine.adding(
          id,
          to: layout,
          at: toCanvasLocal(location),
          in: canvasGlobalFrame.size
        ) {
          layout = updatedLayout
          widgets.append(widget)
        }
      }

      dockDragSlot = nil
      isDockDragOverCanvas = false
    }
  }

  // MARK: - Geometry

  func isOutsideCanvas(_ point: CGPoint) -> Bool {
    guard canvasGlobalFrame != .zero else { return false }
    return !canvasGlobalFrame.contains(point)
  }

  private func checkIsOverCanvas(_ point: CGPoint) -> Bool {
    guard canvasGlobalFrame != .zero else { return false }
    return canvasGlobalFrame.contains(point)
  }

  func toCanvasLocal(_ globalPoint: CGPoint) -> CGPoint {
    CGPoint(
      x: globalPoint.x - canvasGlobalFrame.minX,
      y: globalPoint.y - canvasGlobalFrame.minY
    )
  }

  // MARK: - Drag Overlay

  func dragCircle(
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

  private func withoutAnimation(_ action: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, action)
  }
}
