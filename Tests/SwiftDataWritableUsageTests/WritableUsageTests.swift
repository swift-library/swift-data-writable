// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SwiftData
import SwiftDataWritable
import SwiftUI
import Testing

#if canImport(AppKit)
  import AppKit
#elseif canImport(UIKit)
  import UIKit
#endif

@Model
private final class Person {
  var name: String
  var priority: Int

  init(name: String, priority: Int = 0) {
    self.name = name
    self.priority = priority
  }
}

@Model
private final class Book {
  var title: String
  @Relationship
  var tags: [Tag]

  init(title: String, tags: [Tag] = []) {
    self.title = title
    self.tags = tags
  }
}

@Model
private final class Tag {
  var name: String
  @Relationship
  var documents: [NoteDocument]

  init(name: String, documents: [NoteDocument] = []) {
    self.name = name
    self.documents = documents
  }
}

@Model
private final class NoteDocument {
  var title: String
  var folder: NoteFolder?

  init(title: String, folder: NoteFolder? = nil) {
    self.title = title
    self.folder = folder
  }
}

@Model
private final class NoteFolder {
  var name: String

  init(name: String) {
    self.name = name
  }
}

@Model
private final class Bookmark {
  var document: NoteDocument

  init(document: NoteDocument) {
    self.document = document
  }
}

private func testPersonTransaction(
  _ context: ModelContext,
  _ person: Person,
  _ mutation: () throws -> Void
) throws {
  try mutation()
}

private func testPeopleTransaction(
  _ context: ModelContext,
  _ persons: [Person],
  _ mutation: () throws -> Void
) throws {
  try mutation()
}

private func testBookTransaction(
  _ context: ModelContext,
  _ book: Book,
  _ mutation: () throws -> Void
) throws {
  try mutation()
}

private func testDocumentTransaction(
  _ context: ModelContext,
  _ document: NoteDocument,
  _ mutation: () throws -> Void
) throws {
  try mutation()
}

private enum TestWriteback {
  static var transaction: TestWritebackHook {
    TestWritebackHook()
  }
}

private struct TestWritebackHook {
  func callAsFunction(
    _ context: ModelContext,
    _ person: Person,
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
  }

  func callAsFunction(
    _ context: ModelContext,
    _ persons: [Person],
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
  }
}

private struct WritablePeopleView: View {
  @Writable
  @Query(sort: \Person.name)
  private var persons: [Person]

  var body: some View {
    VStack {
      List {
        ForEach(persons) { person in
          Text(person.name)
        }
        .onDelete(perform: $persons.remove)
      }

      Button("Add") {
        $persons.append(Person(name: "New Person"))
      }
    }
  }
}

private struct OverloadedFunctionTransactionPeopleView: View {
  @Writable(autosave: true, throws: true, transaction: TestWriteback.transaction)
  @Query(sort: \Person.name)
  private var persons: [Person]

  @Writable(autosave: true, throws: true, transaction: TestWriteback.transaction)
  private var selectedPerson: Person

  init(selectedPerson: Person) {
    self.selectedPerson = selectedPerson
  }

  var body: some View {
    VStack {
      Button("Rename") {
        try? $selectedPerson.write { person, _ in
          person.name = "Renamed"
        }
      }

      Button("Batch") {
        try? $persons.write { persons, _ in
          persons.first?.name = "Updated"
        }
      }
    }
  }
}

private struct KeyPathWritablePeopleView: View {
  @Writable(mutableBy: \Person.priority)
  @Query(sort: \Person.priority)
  private var persons: [Person]

  var body: some View {
    List {
      ForEach(persons) { person in
        Text(person.name)
      }
      .onMove(perform: $persons.move)
    }
  }
}

private struct AutosavePeopleView: View {
  @Writable(autosave: true)
  @Query(sort: \Person.name)
  private var persons: [Person]

  var body: some View {
    Button("Add") {
      $persons.append(Person(name: "Saved Person"))
    }
  }
}

private struct AutosaveKeyPathPeopleView: View {
  @Writable(autosave: true, mutableBy: \Person.priority)
  @Query(sort: \Person.priority)
  private var persons: [Person]

  var body: some View {
    Button("Move") {
      $persons.move(fromOffsets: IndexSet(integer: 0), toOffset: 1)
    }
  }
}

private struct ThrowsAutosavePeopleView: View {
  @Writable(autosave: true, throws: true)
  @Query(sort: \Person.name)
  private var persons: [Person]

  var body: some View {
    Button("Add") {
      try? $persons.append(Person(name: "Saved Person"))
    }
  }
}

private struct TransactionPeopleView: View {
  @Writable(autosave: true, throws: true, transaction: testPeopleTransaction)
  @Query(sort: \Person.name)
  private var persons: [Person]

  var body: some View {
    Button("Add") {
      try? $persons.append(Person(name: "Saved Person"))
    }
  }
}

private struct TransactionKeyPathPeopleView: View {
  @Writable(
    autosave: true,
    throws: true,
    mutableBy: \Person.priority,
    transaction: testPeopleTransaction
  )
  @Query(sort: \Person.priority)
  private var persons: [Person]

  var body: some View {
    Button("Move") {
      try? $persons.move(fromOffsets: IndexSet(integer: 0), toOffset: 1)
    }
  }
}

private struct WritablePersonView: View {
  @Writable
  private var person: Person

  init(person: Person) {
    self.person = person
  }

  var body: some View {
    Text(person.name)
      .onAppear {
        try? $person.write { person, _ in
          person.name = "Writable Person"
        }
      }
  }
}

private struct AutosaveWritablePersonView: View {
  @Writable(autosave: true)
  private var person: Person

  init(person: Person) {
    self.person = person
  }

  var body: some View {
    Text(person.name)
      .onAppear {
        try? $person.write { person, _ in
          person.name = "Autosave Writable Person"
        }
      }
  }
}

private struct ThrowsAutosaveWritablePersonView: View {
  @Writable(autosave: true, throws: true)
  private var person: Person

  init(person: Person) {
    self.person = person
  }

  var body: some View {
    Text(person.name)
      .onAppear {
        try? $person.write { person, _ in
          person.name = "Throws Autosave Writable Person"
        }
      }
  }
}

private struct TransactionWritablePersonView: View {
  @Writable(autosave: true, throws: true, transaction: testPersonTransaction)
  private var person: Person

  init(person: Person) {
    self.person = person
  }

  var body: some View {
    Text(person.name)
      .onAppear {
        try? $person.write { person, _ in
          person.name = "Transaction Writable Person"
        }
      }
  }
}

private struct OptionalWritablePersonView: View {
  @Writable
  private var person: Person?

  init(person: Person?) {
    self.person = person
  }

  var body: some View {
    Text(person?.name ?? "")
      .onAppear {
        try? $person?.write { person, _ in
          person.name = "Optional Writable Person"
        }
      }
  }
}

private struct BindableWritablePersonView: View {
  @Writable
  @Bindable
  private var person: Person

  init(person: Person) {
    self.person = person
  }

  var body: some View {
    Text(person.name)
      .onAppear {
        try? $person.writable.write { person, _ in
          person.name = "Bindable Writable Person"
        }
      }
  }
}

private struct WritableBookRelationshipView: View {
  @Writable
  private var book: Book

  private let tag: Tag
  private let document: NoteDocument

  init(book: Book, tag: Tag, document: NoteDocument) {
    self.book = book
    self.tag = tag
    self.document = document
  }

  var body: some View {
    Color.clear
      .onAppear {
        $book.tags.append(tag)
        $book.tags[0].documents.append(document)
        try? $book.tags[0].documents[0].write { document, _ in
          document.title = "Writable Document"
        }
      }
  }
}

private struct WritableDocumentFolderRelationshipView: View {
  @Writable(autosave: true, throws: true, transaction: testDocumentTransaction)
  private var document: NoteDocument

  init(document: NoteDocument) {
    self.document = document
  }

  var body: some View {
    Color.clear
      .onAppear {
        try? $document.folder?.write { folder, _ in
          folder.name = "Writable Folder"
        }
      }
  }
}

private struct WritableBookmarkDocumentRelationshipView: View {
  @Writable
  private var bookmark: Bookmark

  init(bookmark: Bookmark) {
    self.bookmark = bookmark
  }

  var body: some View {
    Color.clear
      .onAppear {
        try? $bookmark.document.write { document, _ in
          document.title = "Writable Bookmark Document"
        }
      }
  }
}

private struct BindableWritableBookRelationshipView: View {
  @Writable
  @Bindable
  private var book: Book

  private let tag: Tag

  init(book: Book, tag: Tag) {
    self.book = book
    self.tag = tag
  }

  var body: some View {
    Color.clear
      .onAppear {
        if let writable = try? $book.writable {
          writable.tags.append(tag)
        }
      }
  }
}

private struct BindableThrowsWritableBookRelationshipView: View {
  @Writable
  @Bindable
  private var book: Book

  private let tag: Tag

  init(book: Book, tag: Tag) {
    self.book = book
    self.tag = tag
  }

  var body: some View {
    Color.clear
      .onAppear {
        if let writable = try? $book.throwsWritable(autosave: true) {
          try? writable.tags.append(tag)
        }
      }
  }
}

private struct BindableTransactionWritableBookRelationshipView: View {
  @Writable
  @Bindable
  private var book: Book

  private let tag: Tag

  init(book: Book, tag: Tag) {
    self.book = book
    self.tag = tag
  }

  var body: some View {
    Color.clear
      .onAppear {
        let transaction = WritableTransaction<Book>(body: testBookTransaction)
        if let writable = try? $book.throwsWritable(
          autosave: true,
          transaction: transaction
        ) {
          try? writable.tags.append(tag)
        }
      }
  }
}

private struct AutosaveWritableBookRelationshipView: View {
  @Writable(autosave: true)
  private var book: Book

  private let tag: Tag

  init(book: Book, tag: Tag) {
    self.book = book
    self.tag = tag
  }

  var body: some View {
    Color.clear
      .onAppear {
        $book.tags.append(tag)
      }
  }
}

@MainActor
private final class WritableContextProbe {
  var didAppear = false
  var didDisappear = false
}

private struct WritableContextProbeView: View {
  @Writable
  @Query(sort: \Person.name)
  private var persons: [Person]

  let probe: WritableContextProbe

  @State private var didAppend = false

  init(probe: WritableContextProbe) {
    self.probe = probe
  }

  var body: some View {
    Color.clear
      .frame(width: 1, height: 1)
      .onAppear {
        guard !didAppend else {
          return
        }

        probe.didAppear = true
        didAppend = true
        $persons.append(Person(name: "Hosted Person"))
      }
      .onDisappear {
        probe.didDisappear = true
      }
  }
}

@Suite
struct WritableUsageTests {
  @MainActor
  @Test func usageFixturesCompile() {
    let person = Person(name: "Compile Fixture")
    let book = Book(title: "Compile Fixture")
    let tag = Tag(name: "Swift")
    let document = NoteDocument(title: "Draft")
    _ = WritablePeopleView()
    _ = KeyPathWritablePeopleView()
    _ = AutosavePeopleView()
    _ = AutosaveKeyPathPeopleView()
    _ = ThrowsAutosavePeopleView()
    _ = TransactionPeopleView()
    _ = TransactionKeyPathPeopleView()
    _ = WritablePersonView(person: person)
    _ = AutosaveWritablePersonView(person: person)
    _ = ThrowsAutosaveWritablePersonView(person: person)
    _ = TransactionWritablePersonView(person: person)
    _ = OptionalWritablePersonView(person: person)
    _ = BindableWritablePersonView(person: person)
    _ = WritableBookRelationshipView(book: book, tag: tag, document: document)
    _ = AutosaveWritableBookRelationshipView(book: book, tag: tag)
    _ = BindableWritableBookRelationshipView(book: book, tag: tag)
    _ = BindableThrowsWritableBookRelationshipView(book: book, tag: tag)
    _ = BindableTransactionWritableBookRelationshipView(book: book, tag: tag)
  }

  #if canImport(AppKit) || canImport(UIKit)
    @MainActor
    @Test func writableProjectionUsesHostedModelContext() async throws {
      let container = try makeContainer()
      let probe = WritableContextProbe()
      let view = WritableContextProbeView(probe: probe)
        .modelContainer(container)
      #if canImport(AppKit)
        let hosting = NSHostingView(rootView: AnyView(view))
        let window = NSWindow(
          contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
          styleMask: .borderless,
          backing: .buffered,
          defer: false
        )
        // Swift owns this window; close must not release it a second time.
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFrontRegardless()
        defer {
          window.contentView = nil
          window.close()
        }
      #elseif canImport(UIKit)
        let hosting = UIHostingController(rootView: AnyView(view))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        window.rootViewController = hosting
        window.makeKeyAndVisible()
        defer {
          window.isHidden = true
          window.rootViewController = nil
        }
      #endif

      var names = [String]()
      let deadline = Date().addingTimeInterval(2)
      repeat {
        try await Task.sleep(for: .milliseconds(10))
        names = try fetchPeople(in: container.mainContext).map(\.name)
      } while !names.contains("Hosted Person") && Date() < deadline

      #expect(probe.didAppear)
      #expect(names.contains("Hosted Person"))
      // Detach Query observers while their ModelContainer is still alive.
      hosting.rootView = AnyView(EmptyView())
      let disappearanceDeadline = Date().addingTimeInterval(2)
      repeat {
        try await Task.sleep(for: .milliseconds(10))
      } while !probe.didDisappear && Date() < disappearanceDeadline
      #expect(probe.didDisappear)
      #expect(try fetchPeople(in: container.mainContext).map(\.name).contains("Hosted Person"))
    }

  #endif

  @MainActor
  private func makeContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Person.self, configurations: configuration)
  }

  @MainActor
  private func fetchPeople(in context: ModelContext) throws -> [Person] {
    var descriptor = FetchDescriptor<Person>(
      sortBy: [SortDescriptor(\Person.name)]
    )
    descriptor.includePendingChanges = true
    return try context.fetch(descriptor)
  }
}
