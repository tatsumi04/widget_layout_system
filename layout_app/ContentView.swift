import SwiftUI

struct ContentView: View {
  @State var widgets: [WidgetItem] = []
  @State var layout: LayoutNode?

  @State var dockDragSlot: DockSlot?
  @State var dockDragGlobalPos: CGPoint = .zero
  @State var isDockDragOverCanvas = false

  @State var canvasDragId: String?
  @State var canvasDragGlobalPos: CGPoint = .zero
  @State var canvasGlobalFrame: CGRect = .zero

  // MARK: - Selection State

  @State var isSelectionMode = false
  @State var selectedWidgetIDs: Set<String> = []
  @State var showColorPicker = false
  @State var snapshotWidgets: [WidgetItem] = []
  @State var snapshotLayout: LayoutNode?

  // MARK: - Shuffle State

  // キャンバス全体にだけ適用する演出用の角度。レイアウトの座標には影響しない。
  @State var canvasSpinAngle: Double = 0
  @State var showShuffleUndoToast = false
  // シャッフルはウィジェット自体を変更しないため、復元対象はレイアウトだけでよい。
  @State var shuffleSnapshot: LayoutNode?
  // 新しいシャッフルのUndo期限を、以前のタスクが消去しないよう保持する。
  @State var shuffleUndoTask: Task<Void, Never>?
  // 渦巻きの起点になったドラッグのonEndedで、再配置・削除を確定しないためのフラグ。
  @State var didSwirlDuringDrag = false
  // シャッフル開始時はドラッグ状態を解除するため、タイルの変形アニメーションを別途維持する。
  @State var isShuffleLayoutAnimating = false

  var body: some View {
    GeometryReader { rootGeo in
      ZStack {
        Color(.systemBackground)
          .ignoresSafeArea()

        mainContent
        dragOverlays(rootFrame: rootGeo.frame(in: .global))

        if showShuffleUndoToast {
          shuffleUndoToast
        }
      }
    }
    .onPreferenceChange(CanvasFrameKey.self) { frame in
      canvasGlobalFrame = frame
    }
  }

  private var mainContent: some View {
    VStack(spacing: 0) {
      if isSelectionMode {
        selectionHeaderBar
          .transition(.move(edge: .top).combined(with: .opacity))
      } else {
        Spacer()
      }

      canvasSection

      if isSelectionMode {
        Spacer()
        selectionBottomBar
          .transition(.move(edge: .bottom).combined(with: .opacity))
      } else {
        Spacer()
        widgetCount
        DockView(
          onDragChanged: handleDockDragChanged,
          onDragEnded: handleDockDragEnded
        )
        .padding(.bottom, 48)
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelectionMode)
  }

  private var widgetCount: some View {
    Text("\(widgets.count) 個")
      .font(.system(.caption, design: .monospaced).weight(.medium))
      .foregroundColor(.secondary)
      .padding(.bottom, 6)
      .opacity(widgets.isEmpty ? 0 : 1)
      .accessibilityHidden(widgets.isEmpty)
  }

  @ViewBuilder
  private func dragOverlays(rootFrame: CGRect) -> some View {
    if let slot = dockDragSlot, !isDockDragOverCanvas {
      dragCircle(
        color: slot.color,
        globalPosition: dockDragGlobalPos,
        rootFrame: rootFrame
      )
    }

    if let draggedID = canvasDragId,
      isOutsideCanvas(canvasDragGlobalPos),
      let draggedWidget = widgets.first(where: { $0.id == draggedID }) {
      dragCircle(
        color: draggedWidget.color,
        globalPosition: canvasDragGlobalPos,
        rootFrame: rootFrame
      )
    }
  }

  @ViewBuilder
  private var canvasSection: some View {
    CanvasView(
      layout: displayLayout,
      widgets: widgets,
      previewSlot: dockDragSlot,
      draggingWidgetID: canvasDragId,
      isDraggingOutside: isOutsideCanvas(canvasDragGlobalPos),
      // シャッフル中はドラッグIDをクリア済みでも、位置とサイズの補間を有効にする。
      shouldAnimateLayout: dockDragSlot != nil || canvasDragId != nil || isShuffleLayoutAnimating,
      isSelectionMode: isSelectionMode,
      selectedWidgetIDs: selectedWidgetIDs,
      onWidgetDragChanged: handleCanvasDragChanged,
      onWidgetDragEnded: handleCanvasDragEnded,
      onWidgetTapped: handleWidgetTapped,
      onWidgetLongPressed: handleWidgetLongPressed,
      onSwirl: shuffleWidgets
    )
    .rotationEffect(.degrees(canvasSpinAngle))
    .padding(.horizontal, 24)
  }

  private var displayLayout: LayoutNode? {
    if isSelectionMode {
      return layout
    }

    if dockDragSlot != nil, isDockDragOverCanvas {
      return LayoutEngine.adding(
        LayoutConfiguration.previewWidgetID,
        to: layout,
        at: toCanvasLocal(dockDragGlobalPos),
        in: canvasGlobalFrame.size
      ) ?? layout
    }

    if let draggedID = canvasDragId {
      // ビューをツリーから外すとGestureがキャンセルされ、onEndedが呼ばれないことがある。
      if isOutsideCanvas(canvasDragGlobalPos) {
        return layout
      }

      let remainingLayout = LayoutEngine.removing(draggedID, from: layout)
      return LayoutEngine.adding(
        draggedID,
        to: remainingLayout,
        at: toCanvasLocal(canvasDragGlobalPos),
        in: canvasGlobalFrame.size
      ) ?? layout
    }

    return layout
  }
}

#Preview {
  ContentView()
}
