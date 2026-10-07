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

  // MARK: - Selection Mode State

  @State private var isSelectionMode = false
  @State private var selectedWidgetIDs: Set<String> = []
  @State private var showColorPicker = false
  @State private var snapshotWidgets: [WidgetItem] = []
  @State private var snapshotLayout: LayoutNode?

  // MARK: - Shuffle State

  // キャンバス全体にだけ適用する演出用の角度。レイアウトの座標には影響しない。
  @State private var canvasSpinAngle: Double = 0
  @State private var showShuffleUndoToast = false
  // シャッフルはウィジェット自体を変更しないため、復元対象はレイアウトだけでよい。
  @State private var shuffleSnapshot: LayoutNode? = nil
  // 新しいシャッフルのUndo期限を、以前のタスクが消去しないよう保持する。
  @State private var shuffleUndoTask: Task<Void, Never>? = nil
  // 渦巻きの起点になったドラッグのonEndedで、再配置・削除を確定しないためのフラグ。
  @State private var didSwirlDuringDrag = false
  // シャッフル開始時はドラッグ状態を解除するため、タイルの変形アニメーションを別途維持する。
  @State private var isShuffleLayoutAnimating = false

  // MARK: - Display Layout (Preview)

  private var displayLayout: LayoutNode? {
    // 選択モード中はプレビュー計算を行わない
    if isSelectionMode {
      return layout
    }

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
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelectionMode)

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

        // シャッフル後のトーストUndoバー
        if showShuffleUndoToast {
          VStack {
            Spacer()

            HStack(spacing: 12) {
              Image(systemName: "shuffle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

              Text("シャッフルしました")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)

              Spacer()

              Button("元に戻す") {
                undoShuffle()
              }
              .font(.system(size: 15, weight: .bold))
              .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
              Capsule()
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
    .onPreferenceChange(CanvasFrameKey.self) { frame in
      canvasGlobalFrame = frame
    }
  }

  // CanvasViewをbody外のプロパティに分離（ViewBuilderのlet制約回避）
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
      onSwirl: {
        shuffleWidgets()
      }
    )
    .rotationEffect(.degrees(canvasSpinAngle))
    .padding(.horizontal, 24)
  }

  // MARK: - Selection Header Bar

  private var selectionHeaderBar: some View {
    HStack {
      Button("キャンセル") {
        cancelSelectionMode()
      }
      .font(.system(size: 16, weight: .regular))

      Spacer()

      Text("\(selectedWidgetIDs.count) 個選択中")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)

      Spacer()

      Button("完了") {
        exitSelectionMode()
      }
      .font(.system(size: 16, weight: .bold))
    }
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .padding(.bottom, 16)
  }

  // MARK: - Selection Bottom Bar

  private var selectionBottomBar: some View {
    VStack(spacing: 16) {
      if showColorPicker {
        HStack(spacing: 16) {
          ForEach(DockSlot.all) { slot in
            Button(action: {
              applyColorToSelectedWidgets(slot.color)
            }) {
              Circle()
                .fill(slot.color)
                .frame(width: 36, height: 36)
                .overlay(
                  Circle()
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                )
                .shadow(color: slot.color.opacity(0.4), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(
          Capsule()
            .fill(Color(.secondarySystemBackground))
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
        )
        .transition(.scale.combined(with: .opacity))
      }

      HStack(spacing: 8) {
        // 全選択・全解除ボタン
        Button(action: toggleSelectAll) {
          Label(
            isAllSelected ? "全解除" : "全選択",
            systemImage: isAllSelected ? "checkmark.circle.fill" : "checkmark.circle"
          )
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.primary)
          .padding(.horizontal, 10)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(Color(.secondarySystemBackground))
          )
        }
        .disabled(widgets.isEmpty)

        // 2つ選択時のみ表示される入れ替えボタン
        if selectedWidgetIDs.count == 2 {
          Button(action: swapSelectedWidgets) {
            Label("入れ替え", systemImage: "arrow.left.arrow.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.primary)
              .padding(.horizontal, 10)
              .padding(.vertical, 12)
              .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(Color.accentColor.opacity(0.18))
              )
          }
          .transition(.scale.combined(with: .opacity))
        }

        // 色変更ボタン
        Button(action: {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showColorPicker.toggle()
          }
        }) {
          Label("色を変更", systemImage: "paintpalette.fill")
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                  showColorPicker
                    ? Color.accentColor.opacity(0.15)
                    : Color(.secondarySystemBackground)
                )
            )
        }
        .disabled(selectedWidgetIDs.isEmpty)
        .opacity(selectedWidgetIDs.isEmpty ? 0.45 : 1)

        // 削除ボタン
        Button(action: deleteSelectedWidgets) {
          Label("削除", systemImage: "trash.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(selectedWidgetIDs.isEmpty ? .secondary : .red)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                  selectedWidgetIDs.isEmpty
                    ? Color(.secondarySystemBackground)
                    : Color.red.opacity(0.12)
                )
            )
        }
        .disabled(selectedWidgetIDs.isEmpty)
        .opacity(selectedWidgetIDs.isEmpty ? 0.45 : 1)
      }
      .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedWidgetIDs.count == 2)
    }
    .padding(.bottom, 48)
  }

  // MARK: - Selection Actions

  private func swapSelectedWidgets() {
    guard selectedWidgetIDs.count == 2 else { return }
    let ids = Array(selectedWidgetIDs)
    let firstID = ids[0]
    let secondID = ids[1]

    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      layout = LayoutEngine.swapping(firstID, secondID, in: layout)
    }
  }

  private var isAllSelected: Bool {
    !widgets.isEmpty && selectedWidgetIDs.count == widgets.count
  }

  private func handleWidgetLongPressed(widget: WidgetItem) {
    guard !isSelectionMode else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    snapshotWidgets = widgets
    snapshotLayout = layout
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      canvasDragId = nil
      isSelectionMode = true
      selectedWidgetIDs = [widget.id]
      showColorPicker = false
    }
  }

  private func handleWidgetTapped(widget: WidgetItem) {
    guard isSelectionMode else { return }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.easeInOut(duration: 0.15)) {
      if selectedWidgetIDs.contains(widget.id) {
        selectedWidgetIDs.remove(widget.id)
      } else {
        selectedWidgetIDs.insert(widget.id)
      }
    }
  }

  private func toggleSelectAll() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.easeInOut(duration: 0.2)) {
      if isAllSelected {
        selectedWidgetIDs.removeAll()
      } else {
        selectedWidgetIDs = Set(widgets.map { $0.id })
      }
    }
  }

  private func cancelSelectionMode() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(.easeInOut(duration: 0.2)) {
      widgets = snapshotWidgets
      layout = snapshotLayout
      isSelectionMode = false
      selectedWidgetIDs.removeAll()
      showColorPicker = false
      snapshotWidgets = []
      snapshotLayout = nil
    }
  }

  private func exitSelectionMode() {
    withAnimation(.easeInOut(duration: 0.2)) {
      isSelectionMode = false
      selectedWidgetIDs.removeAll()
      showColorPicker = false
      snapshotWidgets = []
      snapshotLayout = nil
    }
  }

  private func applyColorToSelectedWidgets(_ color: Color) {
    guard !selectedWidgetIDs.isEmpty else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(.easeInOut(duration: 0.2)) {
      widgets = widgets.map { item in
        if selectedWidgetIDs.contains(item.id) {
          return WidgetItem(id: item.id, color: color)
        }
        return item
      }
    }
  }

  private func deleteSelectedWidgets() {
    guard !selectedWidgetIDs.isEmpty else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    withAnimation(.easeInOut(duration: 0.2)) {
      widgets.removeAll { selectedWidgetIDs.contains($0.id) }
      layout = LayoutEngine.removing(selectedWidgetIDs, from: layout)
      selectedWidgetIDs.removeAll()
      showColorPicker = false
    }
  }

  // MARK: - Shuffle Actions

  private func shuffleWidgets() {
    guard widgets.count >= 2 else { return }

    // ドラッグ中にシャッフルされた場合、ドラッグ終了時の再配置や誤削除を防止
    didSwirlDuringDrag = true
    canvasDragId = nil
    dockDragSlot = nil
    isDockDragOverCanvas = false
    isShuffleLayoutAnimating = true

    // シャッフル前のスナップショットを保存（1回分だけ保持）
    shuffleSnapshot = layout

    // ステップ1: キャンバスがキュッと巻き込まれる予兆アニメーション
    withAnimation(.easeIn(duration: 0.25)) {
      canvasSpinAngle = 15
    }

    // ステップ2: 渦巻きスピンからシャッフル展開
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
        canvasSpinAngle = 720
      }
    }

    // ステップ3: スピン中盤で、配置ツリーごと作り直す。
    // 画面上の実サイズを渡し、最小タイルサイズを満たす候補だけを採用する。
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
        layout = LayoutEngine.shuffling(
          layout,
          in: canvasGlobalFrame.size
        )
      }
    }

    // ステップ4: 720°と0°は見た目が同じなので、アニメーションなしで正規化する。
    // ここをアニメーションすると逆方向の回転として描画される。
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) {
        canvasSpinAngle = 0
        isShuffleLayoutAnimating = false
      }
    }

    // トーストUndoバーを表示（前のタスクがあればキャンセル）
    shuffleUndoTask?.cancel()
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
      showShuffleUndoToast = true
    }

    // 5秒後に自動消滅
    let task = Task {
      try? await Task.sleep(for: .seconds(5))
      guard !Task.isCancelled else { return }
      await MainActor.run {
        withAnimation(.easeOut(duration: 0.3)) {
          showShuffleUndoToast = false
          shuffleSnapshot = nil
        }
      }
    }
    shuffleUndoTask = task
  }

  private func undoShuffle() {
    guard let snapshot = shuffleSnapshot else { return }
    shuffleUndoTask?.cancel()
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
      layout = snapshot
      showShuffleUndoToast = false
      shuffleSnapshot = nil
    }
  }

  // MARK: - Canvas Drag Handlers

  private func handleCanvasDragChanged(widget: WidgetItem, location: CGPoint) {
    guard !isSelectionMode else { return }
    canvasDragId = widget.id
    canvasDragGlobalPos = location
  }

  private func handleCanvasDragEnded(widget: WidgetItem, location: CGPoint) {
    if didSwirlDuringDrag {
      didSwirlDuringDrag = false
      canvasDragId = nil
      return
    }

    guard !isSelectionMode else {
      canvasDragId = nil
      return
    }

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
    if didSwirlDuringDrag {
      didSwirlDuringDrag = false
      dockDragSlot = nil
      isDockDragOverCanvas = false
      return
    }
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
