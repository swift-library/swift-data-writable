// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import SwiftData
import SwiftDataWritable
import Testing

@ModelActor
private actor WritableWorker {
  func rename() throws -> String {
    let person = Person(name: "Draft")
    modelContext.insert(person)
    let writable = ThrowsWritableModel(
      value: person,
      context: modelContext,
      autosave: true
    )
    try writable.write { person, _ in
      person.name = "Saved"
    }
    #expect(!modelContext.hasChanges)
    let verification = ModelContext(modelContainer)
    return try #require(verification.fetch(FetchDescriptor<Person>()).first).name
  }
}

@Suite
struct WritableContextIsolationTests {
  @Test func projectionsRunOnTheirOwningModelActor() async throws {
    let name = try await Task.detached {
      let container = try ModelContainer(
        for: Person.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      return try await WritableWorker(modelContainer: container).rename()
    }.value
    #expect(name == "Saved")
  }
}
