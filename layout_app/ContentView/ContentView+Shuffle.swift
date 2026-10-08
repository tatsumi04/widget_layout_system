import SwiftUI

extension ContentView {
  // MARK: - Shuffle UI

  var shuffleUndoToast: some View {
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

        Button("元に戻す", action: undoShuffle)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.accentColor)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .background {
        Capsule()
          .fill(.regularMaterial)
          .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 120)
    }
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  // MARK: - Shuffle Actions

  func shuffleWidgets() {
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
        layout = LayoutEngine.shuffling(layout, in: canvasGlobalFrame.size)
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

    showUndoToast()
  }

  private func showUndoToast() {
    shuffleUndoTask?.cancel()
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
      showShuffleUndoToast = true
    }

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
}
