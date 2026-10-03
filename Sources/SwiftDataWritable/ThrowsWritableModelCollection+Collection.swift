// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SwiftData

extension ThrowsWritableModelCollection where Base: Collection {
  /// Deletes models at offsets in the current query snapshot.
  public func remove(atOffsets offsets: IndexSet) throws {
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

    try _performThrowsWritableMutation(
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

  /// Returns an error-transparent writable projection for a model in the snapshot.
  public subscript(position: Base.Index) -> ThrowsWritableModel<Element> {
    ThrowsWritableModel(
      value: value[position],
      context: context,
      autosave: autosave,
      transaction: transaction?.wrapping(root: [value[position]])
    )
  }
}
