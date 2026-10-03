// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import SwiftData
import SwiftDataWritable
import SwiftUI
import Testing

@Suite
struct BindableWritableTests {
  @MainActor
  @Test func bindableWritableBridgesAttachedModel() throws {
    let context = try makeContext()
    let person = Person(name: "A")
    context.insert(person)
    let bindable = Bindable(wrappedValue: person)

    try bindable.writable.write { person, _ in
      person.name = "B"
    }

    #expect(try fetchPeople(in: context).map(\.name) == ["B"])
  }

  @MainActor
  @Test func bindableWritableAutosaveBridgeSavesAttachedModel() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let person = Person(name: "A")
    context.insert(person)
    try context.save()
    let bindable = Bindable(wrappedValue: person)

    try bindable.writable(autosave: true).write { person, _ in
      person.name = "B"
    }

    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["B"])
  }

  @MainActor
  @Test func bindableThrowsWritableAutosaveBridgeSavesAttachedModel() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let person = Person(name: "A")
    context.insert(person)
    try context.save()
    let bindable = Bindable(wrappedValue: person)

    try bindable.throwsWritable(autosave: true).write { person, _ in
      person.name = "B"
    }

    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["B"])
  }

  @MainActor
  @Test func bindableWritableBridgeAcceptsTransaction() throws {
    let context = try makeContext()
    let person = Person(name: "A")
    context.insert(person)
    var transactionCalls = 0
    let transaction = WritableTransaction<Person>(body: { _, model, mutation in
      transactionCalls += 1
      #expect(model.persistentModelID == person.persistentModelID)
      try mutation()
    })
    let bindable = Bindable(wrappedValue: person)

    try bindable.writable(
      autosave: true,
      transaction: transaction
    ).write { person, _ in
      person.name = "B"
    }

    #expect(transactionCalls == 1)
    #expect(person.name == "B")
  }

  @MainActor
  @Test func bindableWritableThrowsForDetachedModel() throws {
    let bindable = Bindable(wrappedValue: Person(name: "A"))

    do {
      _ = try bindable.writable
      Issue.record("Expected detached model to throw")
    } catch WritableModelError.detachedModel {
    } catch {
      Issue.record("Expected detachedModel, got \(error)")
    }
  }
}
