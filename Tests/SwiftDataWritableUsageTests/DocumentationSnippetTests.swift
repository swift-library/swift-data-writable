// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SwiftData
import SwiftDataWritable
import SwiftUI
import Testing

@Model
final class Document {
  var title: String
  var revision: Int

  init(title: String, revision: Int = 0) {
    self.title = title
    self.revision = revision
  }
}

// Documentation code blocks that mention `Document.writeback` or
// `DocumentWriteback` must appear verbatim between these markers.
// snippet-begin
struct DocumentWriteback {
  func callAsFunction(
    _ context: ModelContext,
    _ document: Document,
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
    document.revision += 1
    try context.save()
  }

  func callAsFunction(
    _ context: ModelContext,
    _ documents: [Document],
    _ mutation: () throws -> Void
  ) throws {
    try mutation()
    for document in documents {
      document.revision += 1
    }
    try context.save()
  }
}

extension Document {
  static var writeback: DocumentWriteback { DocumentWriteback() }
}

private struct DocumentEditor: View {
  @Writable(
    autosave: true,
    throws: true,
    transaction: Document.writeback
  )
  private var document: Document

  @Writable(autosave: true, throws: true, transaction: Document.writeback)
  @Query(sort: \Document.title)
  private var documents: [Document]

  init(document: Document) {
    self.document = document
  }

  var body: some View {
    Button("Rename") {
      try? $document.write { document, _ in
        document.title = "Renamed"
      }
    }
  }
}
// snippet-end

@Suite
struct DocumentationSnippetTests {
  @MainActor
  @Test func transactionValueSnippetCompiles() {
    _ = DocumentEditor(document: Document(title: "Draft"))
  }

  @MainActor
  @Test func transactionValueRunsTheMutationAndSaves() throws {
    let container = try ModelContainer(
      for: Document.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let document = Document(title: "Draft")
    container.mainContext.insert(document)

    try Document.writeback(container.mainContext, document) {
      document.title = "Final"
    }

    #expect(document.title == "Final")
    #expect(document.revision == 1)
    #expect(!container.mainContext.hasChanges)
  }

  @Test func documentationShowsTheCompiledSnippet() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    let sourceLines = normalizedLines(try String(contentsOf: testFile, encoding: .utf8))
    let begin = try #require(sourceLines.firstIndex(of: "// snippet-begin"))
    let end = try #require(sourceLines.firstIndex(of: "// snippet-end"))
    let snippet = Array(sourceLines[(begin + 1)..<end])

    for path in [
      "Sources/SwiftDataWritable/SwiftDataWritable.docc/SwiftDataWritable.md",
      "Docs/Reference/WritableCombinations.md",
      "Docs/Architecture/SwiftDataWritable.md",
    ] {
      let markdown = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
      let blocks = swiftCodeBlocks(in: markdown).filter {
        $0.contains("Document.writeback") || $0.contains("DocumentWriteback")
      }
      #expect(!blocks.isEmpty, "\(path) no longer shows the transaction value")
      for block in blocks {
        #expect(
          contains(snippet, normalizedLines(block)),
          "\(path) shows code that the snippet tests do not compile:\n\(block)"
        )
      }
    }
  }

  private func normalizedLines(_ text: String) -> [String] {
    text.split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  private func swiftCodeBlocks(in markdown: String) -> [String] {
    var blocks: [String] = []
    var current: [Substring]?
    for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
      if current == nil, line.hasPrefix("```swift") {
        current = []
      } else if let lines = current, line.hasPrefix("```") {
        blocks.append(lines.joined(separator: "\n"))
        current = nil
      } else {
        current?.append(line)
      }
    }
    return blocks
  }

  private func contains(_ lines: [String], _ block: [String]) -> Bool {
    guard !block.isEmpty, block.count <= lines.count else {
      return false
    }
    return (0...(lines.count - block.count)).contains { start in
      Array(lines[start..<(start + block.count)]) == block
    }
  }
}
