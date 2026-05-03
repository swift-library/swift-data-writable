import Foundation
import SwiftData

extension ThrowsWritableModelCollection where Base: Collection {
  /// Deletes models at offsets in the current query snapshot.
  public func remove(atOffsets offsets: IndexSet) throws {
    for offset in offsets.sorted(by: >) {
      guard
        let index = value.index(value.startIndex, offsetBy: offset, limitedBy: value.endIndex),
        index != value.endIndex
      else {
        continue
      }

      context.delete(value[index])
    }

    try _autosave()
  }

  private func _autosave() throws {
    guard autosave else {
      return
    }

    try context.save()
  }
}
