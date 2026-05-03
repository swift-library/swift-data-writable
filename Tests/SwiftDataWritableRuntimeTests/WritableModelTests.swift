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

    let name = actions.write { person, _ in
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

    let name = actions.write { person, _ in
      person.name = "B"
      return person.name
    }

    #expect(name == "B")
    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    #expect(try fetchPeople(in: verificationContext).map(\.name) == ["B"])
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
}
