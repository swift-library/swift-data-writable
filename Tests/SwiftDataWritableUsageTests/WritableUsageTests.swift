import Foundation
import SwiftData
import SwiftDataWritable
import SwiftUI
import Testing

#if canImport(AppKit)
  import AppKit
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

  init(title: String) {
    self.title = title
  }
}

private extension WritableTransaction where Model == Person {
  static var testTransaction: Self {
    Self { _, _, mutation in
      try mutation()
    }
  }
}

private extension WritableTransaction where Model == Book {
  static var testTransaction: Self {
    Self { _, _, mutation in
      try mutation()
    }
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
  @Writable(autosave: true, throws: true, transaction: WritableTransaction<Person>.testTransaction)
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
    transaction: WritableTransaction<Person>.testTransaction
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
  @Writable(autosave: true, throws: true, transaction: WritableTransaction<Person>.testTransaction)
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
        if let writable = try? $book.throwsWritable(
          autosave: true,
          transaction: WritableTransaction<Book>.testTransaction
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

  @MainActor
  @Test func writableProjectionUsesHostedModelContext() throws {
    #if canImport(AppKit)
      let container = try makeContainer()
      let probe = WritableContextProbe()
      let view = WritableContextProbeView(probe: probe)
        .modelContainer(container)
      let hostingView = NSHostingView(rootView: view)
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )
      window.contentView = hostingView
      window.orderFrontRegardless()
      defer {
        window.close()
      }

      var names = [String]()
      let deadline = Date().addingTimeInterval(2)
      repeat {
        _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        names = try fetchPeople(in: container.mainContext).map(\.name)
      } while !names.contains("Hosted Person") && Date() < deadline

      #expect(probe.didAppear)
      #expect(names.contains("Hosted Person"))
    #endif
  }

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
