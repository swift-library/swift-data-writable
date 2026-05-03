import Foundation
import SwiftData
import SwiftDataWritable
import Testing

@Suite
struct WritableRelationshipCollectionTests {
  @MainActor
  @Test func relationshipAppendMutatesOwnerCollectionWithoutSaving() throws {
    let context = try makeRelationshipContext()
    let book = Book(title: "Library")
    context.insert(book)
    let tag = Tag(name: "Swift")
    let actions = WritableModel(value: book, context: context)

    actions.tags.append(tag)

    #expect(book.tags.map(\.name) == ["Swift"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func relationshipRemoveDoesNotDeleteModel() throws {
    let context = try makeRelationshipContext()
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    context.insert(book)
    book.tags.append(tag)
    try context.save()
    let actions = WritableModel(value: book, context: context)

    actions.tags.remove(tag)

    #expect(book.tags.isEmpty)
    #expect(try fetchTags(in: context).map(\.name) == ["Swift"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func relationshipRemoveOffsetsOnlyRemovesMembership() throws {
    let context = try makeRelationshipContext()
    let tags = [
      Tag(name: "A"),
      Tag(name: "B"),
      Tag(name: "C"),
    ]
    let book = Book(title: "Library", tags: tags)
    context.insert(book)
    try context.save()
    let actions = WritableModel(value: book, context: context)
    let initialTags = book.tags
    let offsets = IndexSet([0, 2])
    let expectedRemainingIDs = initialTags.enumerated()
      .filter { !offsets.contains($0.offset) }
      .map { $0.element.persistentModelID }

    actions.tags.remove(atOffsets: offsets)

    #expect(book.tags.map(\.persistentModelID) == expectedRemainingIDs)
    #expect(try fetchTags(in: context).map(\.name) == ["A", "B", "C"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func relationshipSubscriptReturnsWritableModelAndChains() throws {
    let context = try makeRelationshipContext()
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    let document = NoteDocument(title: "Draft")
    context.insert(book)
    book.tags.append(tag)
    try context.save()
    let actions = WritableModel(value: book, context: context)

    actions.tags[0].documents.append(document)
    let title = try actions.tags[0].documents[0].write { document, _ in
      document.title = "Published"
      return document.title
    }

    #expect(tag.documents.map(\.title) == ["Published"])
    #expect(title == "Published")
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func relationshipChainPersistsAfterManualSave() throws {
    let container = try makeRelationshipContainer()
    let context = ModelContext(container)
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    let document = NoteDocument(title: "Draft")
    context.insert(book)
    book.tags.append(tag)
    try context.save()
    let actions = WritableModel(value: book, context: context)

    actions.tags[0].documents.append(document)
    try actions.tags[0].documents[0].write { document, _ in
      document.title = "Published"
    }
    try actions.save()

    let verificationContext = ModelContext(container)
    let books = try fetchBooks(in: verificationContext)
    #expect(books.first?.tags.first?.documents.map(\.title) == ["Published"])
  }

  @MainActor
  @Test func relationshipAppendDetachedRelatedModelPersistsAfterManualSave() throws {
    let container = try makeRelationshipContainer()
    let context = ModelContext(container)
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    context.insert(book)
    try context.save()
    let actions = WritableModel(value: book, context: context)

    actions.tags.append(tag)
    try actions.save()

    let verificationContext = ModelContext(container)
    let books = try fetchBooks(in: verificationContext)
    #expect(books.first?.tags.map(\.name) == ["Swift"])
    #expect(try fetchTags(in: verificationContext).map(\.name) == ["Swift"])
  }

  @MainActor
  @Test func autosaveRelationshipAppendSavesDetachedRelatedModelThroughOwnerGraph() throws {
    let container = try makeRelationshipContainer()
    let context = ModelContext(container)
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    context.insert(book)
    try context.save()
    let actions = WritableModel(value: book, context: context, autosave: true)

    actions.tags.append(tag)

    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    let books = try fetchBooks(in: verificationContext)
    #expect(books.first?.tags.map(\.name) == ["Swift"])
    #expect(try fetchTags(in: verificationContext).map(\.name) == ["Swift"])
  }

  @MainActor
  @Test func autosaveRelationshipSubscriptChainsAndSaves() throws {
    let container = try makeRelationshipContainer()
    let context = ModelContext(container)
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    let document = NoteDocument(title: "Draft")
    context.insert(book)
    book.tags.append(tag)
    try context.save()
    let actions = WritableModel(value: book, context: context, autosave: true)

    actions.tags[0].documents.append(document)
    let title = try actions.tags[0].documents[0].write { document, _ in
      document.title = "Published"
      return document.title
    }

    #expect(tag.documents.map(\.title) == ["Published"])
    #expect(title == "Published")
    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    let books = try fetchBooks(in: verificationContext)
    #expect(books.first?.tags.first?.documents.map(\.title) == ["Published"])
  }

  @MainActor
  @Test func relationshipAppendUsesRootTransaction() throws {
    let context = try makeRelationshipContext()
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    context.insert(book)
    var transactionCalls = 0
    let transaction = WritableTransaction<Book> { _, models, mutation in
      transactionCalls += 1
      #expect(models.map(\.persistentModelID) == [book.persistentModelID])
      try mutation()
    }
    let actions = WritableModel(
      value: book,
      context: context,
      autosave: true,
      transaction: transaction
    )

    actions.tags.append(tag)

    #expect(transactionCalls == 1)
    #expect(book.tags.map(\.name) == ["Swift"])
    #expect(context.hasChanges)
  }

  @MainActor
  @Test func relationshipSubscriptWrapsRootTransactionForChildModel() throws {
    let context = try makeRelationshipContext()
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    let document = NoteDocument(title: "Draft")
    context.insert(book)
    book.tags.append(tag)
    tag.documents.append(document)
    try context.save()
    var transactionCalls = 0
    let transaction = WritableTransaction<Book> { _, models, mutation in
      transactionCalls += 1
      #expect(models.map(\.persistentModelID) == [book.persistentModelID])
      try mutation()
    }
    let actions = WritableModel(
      value: book,
      context: context,
      autosave: true,
      transaction: transaction
    )

    try actions.tags[0].documents[0].write { document, _ in
      document.title = "Published"
    }

    #expect(transactionCalls == 1)
    #expect(document.title == "Published")
    #expect(context.hasChanges)
  }
}

@Suite
struct ThrowsWritableRelationshipCollectionTests {
  @MainActor
  @Test func autosaveRelationshipAppendSavesExistingRelatedModelMembership() throws {
    let container = try makeRelationshipContainer()
    let context = ModelContext(container)
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    context.insert(book)
    context.insert(tag)
    try context.save()
    let actions = ThrowsWritableModel(value: book, context: context, autosave: true)

    try actions.tags.append(tag)

    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    let books = try fetchBooks(in: verificationContext)
    #expect(books.first?.tags.map(\.name) == ["Swift"])
  }

  @MainActor
  @Test func autosaveRelationshipSubscriptReturnsThrowsWritableModelAndChains() throws {
    let container = try makeRelationshipContainer()
    let context = ModelContext(container)
    let book = Book(title: "Library")
    let tag = Tag(name: "Swift")
    let document = NoteDocument(title: "Draft")
    context.insert(book)
    book.tags.append(tag)
    try context.save()
    let actions = ThrowsWritableModel(value: book, context: context, autosave: true)

    try actions.tags[0].documents.append(document)
    let title = try actions.tags[0].documents[0].write { document, _ in
      document.title = "Published"
      return document.title
    }

    #expect(tag.documents.map(\.title) == ["Published"])
    #expect(title == "Published")
    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    let books = try fetchBooks(in: verificationContext)
    #expect(books.first?.tags.first?.documents.map(\.title) == ["Published"])
  }
}
