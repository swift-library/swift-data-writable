// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SwiftData

enum TransactionTestError: Error, Equatable {
  case failed
}

@Model
final class Person {
  var name: String
  var priority: Int

  init(name: String, priority: Int = 0) {
    self.name = name
    self.priority = priority
  }
}

@Model
final class Book {
  var title: String
  @Relationship
  var tags: [Tag]

  init(title: String, tags: [Tag] = []) {
    self.title = title
    self.tags = tags
  }
}

@Model
final class Tag {
  var name: String
  @Relationship
  var documents: [NoteDocument]

  init(name: String, documents: [NoteDocument] = []) {
    self.name = name
    self.documents = documents
  }
}

@Model
final class NoteDocument {
  var title: String
  var folder: NoteFolder?

  init(title: String, folder: NoteFolder? = nil) {
    self.title = title
    self.folder = folder
  }
}

@Model
final class NoteFolder {
  var name: String

  init(name: String) {
    self.name = name
  }
}

@MainActor
func makeContainer() throws -> ModelContainer {
  let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
  return try ModelContainer(for: Person.self, configurations: configuration)
}

@MainActor
func makeContext() throws -> ModelContext {
  try ModelContext(makeContainer())
}

@MainActor
func makeFailingSaveContext() throws -> ModelContext {
  let root = URL(fileURLWithPath: NSTemporaryDirectory())
    .appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  let storeURL = root.appending(path: "store.sqlite")
  let container = try ModelContainer(
    for: Person.self,
    configurations: ModelConfiguration(url: storeURL)
  )
  let context = ModelContext(container)
  context.insert(Person(name: "Seed"))
  try context.save()
  try FileManager.default.removeItem(at: root)
  return context
}

@MainActor
func makeRelationshipContainer() throws -> ModelContainer {
  let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
  return try ModelContainer(
    for: Book.self,
    Tag.self,
    NoteDocument.self,
    NoteFolder.self,
    configurations: configuration
  )
}

@MainActor
func makeRelationshipContext() throws -> ModelContext {
  try ModelContext(makeRelationshipContainer())
}

@MainActor
func fetchPeople(in context: ModelContext) throws -> [Person] {
  var descriptor = FetchDescriptor<Person>(
    sortBy: [SortDescriptor(\Person.name)]
  )
  descriptor.includePendingChanges = true
  return try context.fetch(descriptor)
}

@MainActor
func fetchPeopleByPriority(in context: ModelContext) throws -> [Person] {
  var descriptor = FetchDescriptor<Person>(
    sortBy: [SortDescriptor(\Person.priority)]
  )
  descriptor.includePendingChanges = true
  return try context.fetch(descriptor)
}

@MainActor
func fetchBooks(in context: ModelContext) throws -> [Book] {
  var descriptor = FetchDescriptor<Book>(
    sortBy: [SortDescriptor(\Book.title)]
  )
  descriptor.includePendingChanges = true
  return try context.fetch(descriptor)
}

@MainActor
func fetchTags(in context: ModelContext) throws -> [Tag] {
  var descriptor = FetchDescriptor<Tag>(
    sortBy: [SortDescriptor(\Tag.name)]
  )
  descriptor.includePendingChanges = true
  return try context.fetch(descriptor)
}

@MainActor
func fetchFolders(in context: ModelContext) throws -> [NoteFolder] {
  var descriptor = FetchDescriptor<NoteFolder>(
    sortBy: [SortDescriptor(\NoteFolder.name)]
  )
  descriptor.includePendingChanges = true
  return try context.fetch(descriptor)
}
