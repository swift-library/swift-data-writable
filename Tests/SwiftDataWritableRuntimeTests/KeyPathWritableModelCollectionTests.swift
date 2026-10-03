// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SwiftData
import SwiftDataWritable
import Testing

@Suite
struct KeyPathWritableModelCollectionTests {
  @MainActor
  @Test func moveRewritesComparableValuesWithoutSaving() throws {
    let context = try makeContext()
    let people = [
      Person(name: "A", priority: 10),
      Person(name: "B", priority: 20),
      Person(name: "C", priority: 30),
    ]
    people.forEach(context.insert)
    try context.save()
    let actions = KeyPathWritableModelCollection(
      value: people,
      context: context,
      mutableBy: \Person.priority
    )

    actions.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

    #expect(people[0].priority == 30)
    #expect(people[1].priority == 10)
    #expect(people[2].priority == 20)
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func autosaveMovePersistsAfterMutation() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let people = [
      Person(name: "A", priority: 10),
      Person(name: "B", priority: 20),
      Person(name: "C", priority: 30),
    ]
    people.forEach(context.insert)
    try context.save()
    let actions = KeyPathWritableModelCollection(
      value: people,
      context: context,
      autosave: true,
      mutableBy: \Person.priority
    )

    actions.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

    #expect(people[0].priority == 30)
    #expect(people[1].priority == 10)
    #expect(people[2].priority == 20)
    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeopleByPriority(in: verificationContext).map(\.name) == ["B", "C", "A"])
  }

  @MainActor
  @Test func valueAwareWriteProvidesSnapshotAndContextWithoutSaving() throws {
    let context = try makeContext()
    let people = [
      Person(name: "A", priority: 10),
      Person(name: "B", priority: 20),
    ]
    people.forEach(context.insert)
    let actions = KeyPathWritableModelCollection(
      value: people,
      context: context,
      mutableBy: \Person.priority
    )

    let count = try actions.write { people, context in
      context.insert(Person(name: "C", priority: 30))
      return people.count
    }

    #expect(count == 2)
    #expect(try fetchPeople(in: context).map(\.name) == ["A", "B", "C"])
    #expect(context.hasChanges)
  }
}

@Suite
struct KeyPathThrowsWritableModelCollectionTests {
  @MainActor
  @Test func autosaveMovePersistsAfterMutation() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let people = [
      Person(name: "A", priority: 10),
      Person(name: "B", priority: 20),
      Person(name: "C", priority: 30),
    ]
    people.forEach(context.insert)
    try context.save()
    let actions = KeyPathThrowsWritableModelCollection(
      value: people,
      context: context,
      autosave: true,
      mutableBy: \Person.priority
    )

    try actions.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeopleByPriority(in: verificationContext).map(\.name) == ["B", "C", "A"])
  }
}
