import Foundation
import SwiftData

extension WritableModelCollection where Base: Collection {
  /// A function value compatible with SwiftUI `.onDelete(perform:)`.
  ///
  /// This preserves `$items.remove` call sites while keeping
  /// `remove(atOffsets:)` as the labeled operation.
  public var remove: (IndexSet) -> Void {
    { offsets in
      remove(atOffsets: offsets)
    }
  }

  /// Deletes models at offsets in the current query snapshot.
  public func remove(atOffsets offsets: IndexSet) {
    for offset in offsets.sorted(by: >) {
      guard
        let index = value.index(value.startIndex, offsetBy: offset, limitedBy: value.endIndex),
        index != value.endIndex
      else {
        continue
      }

      context.delete(value[index])
    }

    _autosave()
  }

  private func _autosave() {
    guard autosave else {
      return
    }

    try? context.save()
  }
}
