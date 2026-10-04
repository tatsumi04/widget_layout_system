import Foundation

// MARK: - Layout Node

enum SplitAxis {
  case columns
  case rows
}

indirect enum LayoutNode {
  case leaf(String)
  case split(axis: SplitAxis, children: [LayoutNode])
}
