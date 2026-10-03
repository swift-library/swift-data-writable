// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

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
    let models = offsets.sorted(by: >).compactMap { offset -> Element? in
      guard
        let index = value.index(
          value.startIndex,
          offsetBy: offset,
          limitedBy: value.endIndex
        ),
        index != value.endIndex
      else {
        return nil
      }

      return value[index]
    }

    try? _performWritableMutation(
      context: context,
      autosave: autosave,
      transaction: transaction,
      value: models
    ) {
      for model in models {
        context.delete(model)
      }
    }
  }

  /// Returns a writable projection for a model in the current query snapshot.
  public subscript(position: Base.Index) -> WritableModel<Element> {
    WritableModel(
      value: value[position],
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: [value[position]])
    )
  }
}
