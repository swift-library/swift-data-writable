import SwiftData
import SwiftDataWritable
import Testing

@Suite
struct WritableModelTests {
  @MainActor
  @Test func writeProvidesModelAndContextWithoutSaving() throws {
    let context = try makeContext()
    let person = Person(name: "A")
    context.insert(person)
    let actions = WritableModel(value: person, context: context)

    let name = try actions.write { person, _ in
      person.name = "B"
      return person.name
    }

    #expect(name == "B")
    #expect(try fetchPeople(in: context).map(\.name) == ["B"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func autosavePersistsAfterWriteWithoutThrowingCallSite() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let person = Person(name: "A")
    context.insert(person)
    try context.save()
    let actions = WritableModel(value: person, context: context, autosave: true)

    let name = try actions.write { person, _ in
      person.name = "B"
      return person.name
    }

    #expect(name == "B")
    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["B"])
  }

  @MainActor
  @Test func autosaveFalseDoesNotCallTransaction() throws {
    let context = try makeContext()
    let person = Person(name: "A")
    context.insert(person)
    var transactionCalls = 0
    let transaction = WritableTransaction<Person>(body: { _, _, _ in
      transactionCalls += 1
      throw TransactionTestError.failed
    })
    let actions = WritableModel(
      value: person,
      context: context,
      transaction: transaction
    )

    let name = try actions.write { person, _ in
      person.name = "B"
      return person.name
    }

    #expect(name == "B")
    #expect(transactionCalls == 0)
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func autosaveTrueUsesTransactionWithoutDefaultSave() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let person = Person(name: "A")
    context.insert(person)
    try context.save()
    var transactionCalls = 0
    let transaction = WritableTransaction<Person>(body: { context, model, mutation in
      transactionCalls += 1
      #expect(model.persistentModelID == person.persistentModelID)
      #expect(!context.hasChanges)
      try mutation()
      #expect(context.hasChanges)
    })
    let actions = WritableModel(
      value: person,
      context: context,
      autosave: true,
      transaction: transaction
    )

    let name = try actions.write { person, _ in
      person.name = "B"
      return person.name
    }

    #expect(name == "B")
    #expect(transactionCalls == 1)
    #expect(context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["A"])
  }

  @MainActor
  @Test func transactionAutosaveFailureAfterMutationIsSwallowed() throws {
    let context = try makeContext()
    let person = Person(name: "A")
    context.insert(person)
    let transaction = WritableTransaction<Person>(body: { _, _, mutation in
      try mutation()
      throw TransactionTestError.failed
    })
    let actions = WritableModel(
      value: person,
      context: context,
      autosave: true,
      transaction: transaction
    )

    let name = try actions.write { person, _ in
      person.name = "B"
      return person.name
    }

    #expect(name == "B")
    #expect(person.name == "B")
    #expect(context.hasChanges)
  }
}

@Suite
struct ThrowsWritableModelTests {
  @MainActor
  @Test func autosavePersistsAfterWrite() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let person = Person(name: "A")
    context.insert(person)
    try context.save()
    let actions = ThrowsWritableModel(value: person, context: context, autosave: true)

    let name = try actions.write { person, _ in
      person.name = "B"
      return person.name
    }

    #expect(name == "B")
    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["B"])
  }

  @MainActor
  @Test func autosaveFailureIsThrown() throws {
    let context = try makeFailingSaveContext()
    let person = Person(name: "A")
    context.insert(person)
    let actions = ThrowsWritableModel(value: person, context: context, autosave: true)

    do {
      try actions.write { person, _ in
        person.name = "B"
      }
      Issue.record("Expected autosave to throw")
    } catch {
      #expect(context.hasChanges)
    }
  }

  @MainActor
  @Test func transactionAutosaveFailureIsThrown() throws {
    let context = try makeContext()
    let person = Person(name: "A")
    context.insert(person)
    let transaction = WritableTransaction<Person>(body: { _, _, mutation in
      try mutation()
      throw TransactionTestError.failed
    })
    let actions = ThrowsWritableModel(
      value: person,
      context: context,
      autosave: true,
      transaction: transaction
    )

    do {
      try actions.write { person, _ in
        person.name = "B"
      }
      Issue.record("Expected transaction to throw")
    } catch TransactionTestError.failed {
      #expect(person.name == "B")
      #expect(context.hasChanges)
    } catch {
      Issue.record("Expected TransactionTestError.failed, got \(error)")
    }
  }
}
