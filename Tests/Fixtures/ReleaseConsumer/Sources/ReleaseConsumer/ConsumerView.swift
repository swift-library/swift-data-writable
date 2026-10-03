// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import SwiftData
import SwiftDataWritable
import SwiftUI

@Model
public final class Entry {
  public var title: String
  public var rank: Int
  public var children: [Child]

  public init(title: String, rank: Int = 0, children: [Child] = []) {
    self.title = title
    self.rank = rank
    self.children = children
  }
}

@Model
public final class Child {
  public var name: String

  public init(name: String) {
    self.name = name
  }
}

@MainActor
public final class ContextProbe {
  public var didAppear = false
  public var didDisappear = false
  public init() {}
}

public struct ConsumerView: View {
  @Writable(autosave: true, throws: true, mutableBy: \Entry.rank)
  @Query(sort: \Entry.rank)
  private var entries: [Entry]

  private let probe: ContextProbe
  @State private var didInsert = false

  public init(probe: ContextProbe) {
    self.probe = probe
  }

  public var body: some View {
    Color.clear
      .frame(width: 10, height: 10)
      .onAppear {
        guard !didInsert else { return }
        didInsert = true
        probe.didAppear = true
        try? $entries.append(Entry(title: "Hosted", rank: 1))
      }
      .onDisappear {
        probe.didDisappear = true
      }
  }
}
