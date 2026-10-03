// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import ReleaseConsumer
import SwiftData
import SwiftDataWritable
import SwiftUI
import Testing

#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

@Suite
struct ConsumerTests {
  @MainActor
  private func container() throws -> ModelContainer {
    try ModelContainer(
      for: Entry.self, Child.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
  }

  @MainActor
  @Test func queryMutationAndExplicitSave() throws {
    let container = try container()
    let context = ModelContext(container)
    let writable = WritableModelCollection(value: [Entry](), context: context)
    let entry = Entry(title: "Draft")
    writable.append(entry)
    #expect(context.hasChanges)
    try writable.save()
    let verification = ModelContext(container)
    #expect(try verification.fetch(FetchDescriptor<Entry>()).map(\.title) == ["Draft"])
    writable.delete(entry)
    try writable.save()
    #expect(try ModelContext(container).fetch(FetchDescriptor<Entry>()).isEmpty)
  }

  @MainActor
  @Test func relationshipChainAndTransaction() throws {
    let container = try container()
    let context = ModelContext(container)
    let entry = Entry(title: "Parent")
    context.insert(entry)
    try context.save()
    var transactionCalls = 0
    let writable = ThrowsWritableModel(
      value: entry, context: context, autosave: true,
      transaction: WritableTransaction<Entry> { context, _, mutation in
        transactionCalls += 1
        try mutation()
        try context.save()
      }
    )
    try writable.children.append(Child(name: "New"))
    try writable.children[0].write { child, _ in child.name = "Saved" }
    #expect(transactionCalls == 2)
    #expect(try ModelContext(container).fetch(FetchDescriptor<Child>()).map(\.name) == ["Saved"])
  }

  @MainActor
  @Test func detachedBindableReportsItsError() {
    let bindable = Bindable(Entry(title: "Detached"))
    #expect(throws: WritableModelError.detachedModel) {
      try bindable.writable()
    }
  }

  #if canImport(AppKit) || canImport(UIKit)
    @MainActor
    @Test func macroUsesTheHostedSwiftUIContext() throws {
      let container = try container()
      let probe = ContextProbe()
      let view = ConsumerView(probe: probe).modelContainer(container)
      #if canImport(AppKit)
        let window = NSWindow(
          contentRect: NSRect(x: 0, y: 0, width: 20, height: 20),
          styleMask: .borderless, backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.orderFrontRegardless()
        defer { window.close() }
      #elseif canImport(UIKit)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        defer {
          window.isHidden = true
          window.rootViewController = nil
        }
      #endif
      let deadline = Date().addingTimeInterval(5)
      var names = [String]()
      repeat {
        _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        names = try container.mainContext.fetch(FetchDescriptor<Entry>()).map(\.title)
      } while !names.contains("Hosted") && Date() < deadline
      #expect(probe.didAppear)
      #expect(names == ["Hosted"])
    }
  #endif
}
