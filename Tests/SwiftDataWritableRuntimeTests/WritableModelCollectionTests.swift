import Foundation
import SwiftData
import SwiftDataWritable
import Testing

@Suite
struct WritableModelCollectionTests {
  @MainActor
  @Test func appendInsertsIntoModelContextWithoutSaving() throws {
    let context = try makeContext()
    let actions = WritableModelCollection(value: [Person](), context: context)

    actions.append(Person(name: "A"))

    #expect(try fetchPeople(in: context).map(\.name) == ["A"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func removeOffsetsDeletesSelectedCurrentValuesWithoutSaving() throws {
    let context = try makeContext()
    let people = [
      Person(name: "A"),
      Person(name: "B"),
      Person(name: "C"),
    ]
    people.forEach(context.insert)
    let actions = WritableModelCollection(value: people, context: context)

    actions.remove(IndexSet([0, 2]))

    #expect(try fetchPeople(in: context).map(\.name) == ["B"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func explicitSavePersistsInsertedModels() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let actions = WritableModelCollection(value: [Person](), context: context)

    actions.append(Person(name: "A"))
    try actions.save()

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["A"])
  }

  @MainActor
  @Test func autosavePersistsAfterMutationWithoutThrowingCallSite() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let actions = WritableModelCollection(
      value: [Person](),
      context: context,
      autosave: true
    )

    actions.append(Person(name: "A"))

    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["A"])
  }

  @MainActor
  @Test func autosaveFailureIsSwallowed() throws {
    let context = try makeFailingSaveContext()
    let actions = WritableModelCollection(
      value: [Person](),
      context: context,
      autosave: true
    )

    actions.append(Person(name: "A"))

    #expect(context.hasChanges)
  }

  @MainActor
  @Test func explicitSaveStillThrows() throws {
    let context = try makeFailingSaveContext()
    let actions = WritableModelCollection(value: [Person](), context: context)
    actions.append(Person(name: "A"))

    do {
      try actions.save()
      Issue.record("Expected explicit save to throw")
    } catch {
      #expect(context.hasChanges)
    }
  }

  @MainActor
  @Test func valueAwareWriteProvidesSnapshotAndContext() throws {
    let context = try makeContext()
    let actions = WritableModelCollection(value: [Person](), context: context)

    let count = try actions.write { people, context in
      context.insert(Person(name: "A"))
      return people.count
    }

    #expect(count == 0)
    #expect(try fetchPeople(in: context).map(\.name) == ["A"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func subscriptReturnsWritableModelWithCollectionTransaction() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let person = Person(name: "A")
    context.insert(person)
    try context.save()
    var transactionCalls = 0
    let transaction = WritableTransaction<[Person]>(body: { _, models, mutation in
      transactionCalls += 1
      #expect(models.map(\.persistentModelID) == [person.persistentModelID])
      try mutation()
    })
    let actions = WritableModelCollection(
      value: [person],
      context: context,
      autosave: true,
      transaction: transaction
    )

    try actions[0].write { person, _ in
      person.name = "B"
    }

    #expect(transactionCalls == 1)
    #expect(person.name == "B")
    #expect(context.hasChanges)
  }
}

@Suite
struct ThrowsWritableModelCollectionTests {
  @MainActor
  @Test func autosavePersistsAfterMutation() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let actions = ThrowsWritableModelCollection(
      value: [Person](),
      context: context,
      autosave: true
    )

    try actions.append(Person(name: "A"))

    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["A"])
  }

  @MainActor
  @Test func autosaveFailureIsThrown() throws {
    let context = try makeFailingSaveContext()
    let actions = ThrowsWritableModelCollection(
      value: [Person](),
      context: context,
      autosave: true
    )

    do {
      try actions.append(Person(name: "A"))
      Issue.record("Expected autosave to throw")
    } catch {
      #expect(context.hasChanges)
    }
  }

  @MainActor
  @Test func throwsTrueWithoutAutosaveOnlyMutates() throws {
    let context = try makeContext()
    let actions = ThrowsWritableModelCollection(value: [Person](), context: context)

    try actions.append(Person(name: "A"))

    #expect(try fetchPeople(in: context).map(\.name) == ["A"])
    #expect(context.hasChanges)
  }
}
