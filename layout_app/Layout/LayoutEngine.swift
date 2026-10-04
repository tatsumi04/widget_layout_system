import SwiftUI

// MARK: - Layout Engine

struct LayoutEngine {
  static let spacing: CGFloat = 1
  static let cornerRadius: CGFloat = 20
  static let minimumTileSize: CGFloat = 54
  static let outerEdgeThreshold: CGFloat = 22
  static let dividerHitThreshold: CGFloat = 16
  private static let hitSlop: CGFloat = 8

  private struct DividerHit {
    let path: [Int]
    let insertionIndex: Int
    let depth: Int
    let distance: CGFloat
  }

  private struct EdgeTarget {
    let axis: SplitAxis
    let insertAtStart: Bool
    let distance: CGFloat
  }

  static func leafIDs(in node: LayoutNode?) -> [String] {
    guard let node else { return [] }

    switch node {
    case .leaf(let id):
      return [id]
    case .split(_, let children):
      return children.flatMap { leafIDs(in: $0) }
    }
  }

  static func frames(for node: LayoutNode?, in size: CGSize) -> [String: CGRect] {
    guard let node else { return [:] }
    return frames(for: node, in: CGRect(origin: .zero, size: size))
  }

  static func adding(
    _ id: String,
    to root: LayoutNode?,
    at rawPoint: CGPoint,
    in size: CGSize
  ) -> LayoutNode? {
    guard let root else {
      return .leaf(id)
    }

    let point = clamped(rawPoint, to: size)

    // 外周への追加
    if let edge = outerEdgeTarget(at: point, in: size) {
      let oldFrames = frames(for: root, in: size)
      var ids = leafIDs(in: root).sorted { first, second in
        let a = oldFrames[first] ?? .zero
        let b = oldFrames[second] ?? .zero

        if edge.axis == .columns {
          if a.midX != b.midX { return a.midX < b.midX }
          return a.midY < b.midY
        }

        if a.midY != b.midY { return a.midY < b.midY }
        return a.midX < b.midX
      }

      ids.insert(id, at: edge.insertAtStart ? 0 : ids.count)

      let candidate = linearGroup(ids, axis: edge.axis)
      return satisfiesMinimumTileSize(candidate, in: size)
        ? candidate
        : nil
    }

    // 境界線への追加
    if let hit = nearestDivider(
      in: root,
      point: point,
      rect: CGRect(origin: .zero, size: size)
    ) {
      let candidate = normalizeSimpleGrid(
        insertingLeaf(
          id,
          intoGroupAt: hit.path,
          index: hit.insertionIndex,
          in: root
        )
      )

      return satisfiesMinimumTileSize(candidate, in: size)
        ? candidate
        : nil
    }

    // ウィジェット内への追加
    let rects = frames(for: root, in: size)

    guard
      let targetID = leafID(at: point, in: root, size: size),
      let targetRect = rects[targetID]
    else {
      let candidate = linearGroup(
        leafIDs(in: root) + [id],
        axis: .columns
      )

      return satisfiesMinimumTileSize(candidate, in: size)
        ? candidate
        : nil
    }

    let target = splitTarget(at: point, in: targetRect)
    let oldLeaf = LayoutNode.leaf(targetID)

    let replacement: LayoutNode =
      target.insertAtStart
      ? .split(axis: target.axis, children: [.leaf(id), oldLeaf])
      : .split(axis: target.axis, children: [oldLeaf, .leaf(id)])

    let candidate = normalizeSimpleGrid(
      replacingLeaf(targetID, with: replacement, in: root)
    )

    return satisfiesMinimumTileSize(candidate, in: size)
      ? candidate
      : nil
  }

  static func satisfiesMinimumTileSize(
    _ node: LayoutNode,
    in size: CGSize
  ) -> Bool {
    let rects = frames(for: node, in: size)
    return rects.values.allSatisfy {
      $0.width >= minimumTileSize &&
      $0.height >= minimumTileSize
    }
  }

  static func leafID(
    at point: CGPoint,
    in root: LayoutNode?,
    size: CGSize
  ) -> String? {
    guard let root else { return nil }

    let rects = frames(for: root, in: size)

    if let direct = rects.first(where: { $0.value.contains(point) }) {
      return direct.key
    }

    return rects.min {
      distance(from: point, to: $0.value) <
      distance(from: point, to: $1.value)
    }?.key
  }

  static func removing(
    _ id: String,
    from root: LayoutNode?
  ) -> LayoutNode? {
    guard let root else { return nil }

    switch root {
    case .leaf(let currentID):
      return currentID == id ? nil : root

    case .split(let axis, let children):
      let remaining = children.compactMap {
        removing(id, from: $0)
      }

      guard !remaining.isEmpty else { return nil }
      if remaining.count == 1 { return remaining[0] }

      return .split(axis: axis, children: remaining)
    }
  }

  private static func frames(
    for node: LayoutNode,
    in rect: CGRect
  ) -> [String: CGRect] {
    switch node {
    case .leaf(let id):
      return [id: rect]

    case .split(let axis, let children):
      let rects = childRects(
        axis: axis,
        count: children.count,
        in: rect
      )

      var result: [String: CGRect] = [:]

      for (index, child) in children.enumerated()
      where index < rects.count {
        result.merge(
          frames(for: child, in: rects[index])
        ) { _, new in new }
      }

      return result
    }
  }

  private static func linearGroup(
    _ ids: [String],
    axis: SplitAxis
  ) -> LayoutNode {
    let leaves = ids.map { LayoutNode.leaf($0) }

    guard leaves.count > 1 else {
      return leaves.first ?? .split(axis: axis, children: [])
    }

    return .split(axis: axis, children: leaves)
  }

  private static func normalizeSimpleGrid(
    _ node: LayoutNode
  ) -> LayoutNode {
    guard case .split(let axis, let children) = node else {
      return node
    }

    let normalizedChildren = children.map {
      normalizeSimpleGrid($0)
    }

    guard axis == .columns, normalizedChildren.count > 1 else {
      return .split(axis: axis, children: normalizedChildren)
    }

    let rowGroups: [[LayoutNode]] = normalizedChildren.compactMap { child in
      guard
        case .split(.rows, let rowChildren) = child,
        !rowChildren.isEmpty,
        rowChildren.allSatisfy({
          if case .leaf = $0 { return true }
          return false
        })
      else {
        return nil
      }

      return rowChildren
    }

    guard
      rowGroups.count == normalizedChildren.count,
      let rowCount = rowGroups.first?.count,
      rowCount > 0,
      rowGroups.allSatisfy({ $0.count == rowCount })
    else {
      return .split(axis: axis, children: normalizedChildren)
    }

    let transposedRows = (0..<rowCount).map { rowIndex in
      LayoutNode.split(
        axis: .columns,
        children: rowGroups.map { $0[rowIndex] }
      )
    }

    return .split(
      axis: .rows,
      children: transposedRows
    )
  }

  private static func childRects(
    axis: SplitAxis,
    count: Int,
    in rect: CGRect
  ) -> [CGRect] {
    guard count > 0 else { return [] }
    if count == 1 { return [rect] }

    switch axis {
    case .columns:
      let usable = max(
        0,
        rect.width - spacing * CGFloat(count - 1)
      )
      let width = usable / CGFloat(count)

      return (0..<count).map { index in
        CGRect(
          x: rect.minX + CGFloat(index) * (width + spacing),
          y: rect.minY,
          width: width,
          height: rect.height
        )
      }

    case .rows:
      let usable = max(
        0,
        rect.height - spacing * CGFloat(count - 1)
      )
      let height = usable / CGFloat(count)

      return (0..<count).map { index in
        CGRect(
          x: rect.minX,
          y: rect.minY + CGFloat(index) * (height + spacing),
          width: rect.width,
          height: height
        )
      }
    }
  }

  private static func outerEdgeTarget(
    at point: CGPoint,
    in size: CGSize
  ) -> EdgeTarget? {
    let candidates: [EdgeTarget] = [
      EdgeTarget(axis: .columns, insertAtStart: true, distance: point.x),
      EdgeTarget(
        axis: .columns,
        insertAtStart: false,
        distance: size.width - point.x
      ),
      EdgeTarget(axis: .rows, insertAtStart: true, distance: point.y),
      EdgeTarget(
        axis: .rows,
        insertAtStart: false,
        distance: size.height - point.y
      ),
    ]

    guard
      let nearest = candidates.min(by: {
        $0.distance < $1.distance
      }),
      nearest.distance <= outerEdgeThreshold
    else {
      return nil
    }

    return nearest
  }

  private static func nearestDivider(
    in root: LayoutNode,
    point: CGPoint,
    rect: CGRect
  ) -> DividerHit? {
    var hits: [DividerHit] = []

    collectDividerHits(
      in: root,
      point: point,
      rect: rect,
      path: [],
      into: &hits
    )

    return hits.sorted {
      if $0.depth != $1.depth {
        return $0.depth > $1.depth
      }
      return $0.distance < $1.distance
    }.first
  }

  private static func collectDividerHits(
    in node: LayoutNode,
    point: CGPoint,
    rect: CGRect,
    path: [Int],
    into hits: inout [DividerHit]
  ) {
    guard
      case .split(let axis, let children) = node,
      children.count > 1
    else {
      return
    }

    let rects = childRects(
      axis: axis,
      count: children.count,
      in: rect
    )

    for index in 0..<(rects.count - 1) {
      let distance: CGFloat
      let withinSpan: Bool

      switch axis {
      case .columns:
        let dividerX =
          (rects[index].maxX + rects[index + 1].minX) / 2

        distance = abs(point.x - dividerX)
        withinSpan =
          point.y >= rect.minY - hitSlop &&
          point.y <= rect.maxY + hitSlop

      case .rows:
        let dividerY =
          (rects[index].maxY + rects[index + 1].minY) / 2

        distance = abs(point.y - dividerY)
        withinSpan =
          point.x >= rect.minX - hitSlop &&
          point.x <= rect.maxX + hitSlop
      }

      if distance <= dividerHitThreshold, withinSpan {
        hits.append(
          DividerHit(
            path: path,
            insertionIndex: index + 1,
            depth: path.count,
            distance: distance
          )
        )
      }
    }

    for (index, child) in children.enumerated()
    where index < rects.count {
      collectDividerHits(
        in: child,
        point: point,
        rect: rects[index],
        path: path + [index],
        into: &hits
      )
    }
  }

  private static func splitTarget(
    at point: CGPoint,
    in rect: CGRect
  ) -> EdgeTarget {
    let x = point.x - rect.minX
    let y = point.y - rect.minY
    let width = max(rect.width, 1)
    let height = max(rect.height, 1)

    let candidates: [EdgeTarget] = [
      EdgeTarget(
        axis: .columns,
        insertAtStart: true,
        distance: x / width
      ),
      EdgeTarget(
        axis: .columns,
        insertAtStart: false,
        distance: (rect.width - x) / width
      ),
      EdgeTarget(
        axis: .rows,
        insertAtStart: true,
        distance: y / height
      ),
      EdgeTarget(
        axis: .rows,
        insertAtStart: false,
        distance: (rect.height - y) / height
      ),
    ]

    let nearest = candidates.min {
      $0.distance < $1.distance
    }!

    if nearest.distance <= 0.30 {
      return nearest
    }

    if rect.width >= rect.height {
      return EdgeTarget(
        axis: .columns,
        insertAtStart: x < rect.width / 2,
        distance: 0.5
      )
    }

    return EdgeTarget(
      axis: .rows,
      insertAtStart: y < rect.height / 2,
      distance: 0.5
    )
  }

  private static func insertingLeaf(
    _ id: String,
    intoGroupAt path: [Int],
    index: Int,
    in node: LayoutNode
  ) -> LayoutNode {
    if path.isEmpty {
      guard
        case .split(let axis, let children) = node
      else {
        return node
      }

      var updated = children
      updated.insert(
        .leaf(id),
        at: max(0, min(index, updated.count))
      )

      return .split(
        axis: axis,
        children: updated
      )
    }

    guard
      case .split(let axis, let children) = node
    else {
      return node
    }

    var updated = children
    let childIndex = path[0]

    guard updated.indices.contains(childIndex) else {
      return node
    }

    updated[childIndex] = insertingLeaf(
      id,
      intoGroupAt: Array(path.dropFirst()),
      index: index,
      in: updated[childIndex]
    )

    return .split(
      axis: axis,
      children: updated
    )
  }

  private static func replacingLeaf(
    _ id: String,
    with replacement: LayoutNode,
    in node: LayoutNode
  ) -> LayoutNode {
    switch node {
    case .leaf(let currentID):
      return currentID == id ? replacement : node

    case .split(let axis, let children):
      return .split(
        axis: axis,
        children: children.map {
          replacingLeaf(
            id,
            with: replacement,
            in: $0
          )
        }
      )
    }
  }

  private static func clamped(
    _ point: CGPoint,
    to size: CGSize
  ) -> CGPoint {
    CGPoint(
      x: min(max(point.x, 0), max(size.width, 0)),
      y: min(max(point.y, 0), max(size.height, 0))
    )
  }

  private static func distance(
    from point: CGPoint,
    to rect: CGRect
  ) -> CGFloat {
    let dx = max(
      rect.minX - point.x,
      0,
      point.x - rect.maxX
    )

    let dy = max(
      rect.minY - point.y,
      0,
      point.y - rect.maxY
    )

    return hypot(dx, dy)
  }
}
