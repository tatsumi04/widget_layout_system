import SwiftUI

extension ContentView {
  // MARK: - Selection UI

  var selectionHeaderBar: some View {
    HStack {
      Button("キャンセル", action: cancelSelectionMode)
        .font(.system(size: 16, weight: .regular))

      Spacer()

      Text("\(selectedWidgetIDs.count) 個選択中")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)

      Spacer()

      Button("完了", action: exitSelectionMode)
        .font(.system(size: 16, weight: .bold))
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }

  var selectionBottomBar: some View {
    VStack(spacing: 16) {
      if showColorPicker {
        colorPicker
          .transition(.scale.combined(with: .opacity))
      }

      HStack(spacing: 8) {
        selectAllButton

        if selectedWidgetIDs.count == 2 {
          swapButton
            .transition(.scale.combined(with: .opacity))
        }

        colorButton
        deleteButton
      }
      .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedWidgetIDs.count == 2)
    }
    .padding(.bottom, 48)
  }

  private var colorPicker: some View {
    HStack(spacing: 16) {
      ForEach(DockSlot.all) { slot in
        Button {
          applyColorToSelectedWidgets(slot.color)
        } label: {
          Circle()
            .fill(slot.color)
            .frame(width: 36, height: 36)
            .overlay {
              Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
            }
            .shadow(color: slot.color.opacity(0.4), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 18)
    .background {
      Capsule()
        .fill(Color(.secondarySystemBackground))
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
    }
  }

  private var selectAllButton: some View {
    Button(action: toggleSelectAll) {
      Label(
        isAllSelected ? "全解除" : "全選択",
        systemImage: isAllSelected ? "checkmark.circle.fill" : "checkmark.circle"
      )
      .font(.system(size: 14, weight: .medium))
      .foregroundColor(.primary)
      .padding(.horizontal, 10)
      .padding(.vertical, 12)
      .background(selectionButtonBackground)
    }
    .disabled(widgets.isEmpty)
  }

  private var swapButton: some View {
    Button(action: swapSelectedWidgets) {
      Label("入れ替え", systemImage: "arrow.left.arrow.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(selectionButtonBackground.fill(Color.accentColor.opacity(0.18)))
    }
  }

  private var colorButton: some View {
    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
        showColorPicker.toggle()
      }
    } label: {
      Label("色を変更", systemImage: "paintpalette.fill")
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
          selectionButtonBackground.fill(
            showColorPicker
              ? Color.accentColor.opacity(0.15)
              : Color(.secondarySystemBackground)
          )
        )
    }
    .disabled(selectedWidgetIDs.isEmpty)
    .opacity(selectedWidgetIDs.isEmpty ? 0.45 : 1)
  }

  private var deleteButton: some View {
    Button(action: deleteSelectedWidgets) {
      Label("削除", systemImage: "trash.fill")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(selectedWidgetIDs.isEmpty ? .secondary : .red)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
          selectionButtonBackground.fill(
            selectedWidgetIDs.isEmpty
              ? Color(.secondarySystemBackground)
              : Color.red.opacity(0.12)
          )
        )
    }
    .disabled(selectedWidgetIDs.isEmpty)
    .opacity(selectedWidgetIDs.isEmpty ? 0.45 : 1)
  }

  private var selectionButtonBackground: RoundedRectangle {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
  }

  // MARK: - Selection Actions

  private var isAllSelected: Bool {
    !widgets.isEmpty && selectedWidgetIDs.count == widgets.count
  }

  private func swapSelectedWidgets() {
    guard selectedWidgetIDs.count == 2 else { return }
    let ids = Array(selectedWidgetIDs)

    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      layout = LayoutEngine.swapping(ids[0], ids[1], in: layout)
    }
  }

  func handleWidgetLongPressed(widget: WidgetItem) {
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

  func handleWidgetTapped(widget: WidgetItem) {
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
      selectedWidgetIDs = isAllSelected ? [] : Set(widgets.map(\.id))
    }
  }

  private func cancelSelectionMode() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(.easeInOut(duration: 0.2)) {
      widgets = snapshotWidgets
      layout = snapshotLayout
      clearSelectionMode()
    }
  }

  private func exitSelectionMode() {
    withAnimation(.easeInOut(duration: 0.2)) {
      clearSelectionMode()
    }
  }

  private func clearSelectionMode() {
    isSelectionMode = false
    selectedWidgetIDs.removeAll()
    showColorPicker = false
    snapshotWidgets = []
    snapshotLayout = nil
  }

  private func applyColorToSelectedWidgets(_ color: Color) {
    guard !selectedWidgetIDs.isEmpty else { return }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    withAnimation(.easeInOut(duration: 0.2)) {
      widgets = widgets.map { item in
        selectedWidgetIDs.contains(item.id)
          ? WidgetItem(id: item.id, color: color)
          : item
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
}
