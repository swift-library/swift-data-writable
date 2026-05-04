import SwiftDataWritableMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

private let testMacros: [String: MacroSpec] = [
  "Writable": MacroSpec(type: WritableMacro.self)
]

private func assertMacroExpansion(
  _ originalSource: String,
  expandedSource expectedExpandedSource: String,
  diagnostics: [DiagnosticSpec] = [],
  macros: [String: MacroSpec],
  fileID: StaticString = #fileID,
  filePath: StaticString = #filePath,
  line: UInt = #line,
  column: UInt = #column
) {
  SwiftSyntaxMacrosGenericTestSupport.assertMacroExpansion(
    originalSource,
    expandedSource: expectedExpandedSource,
    diagnostics: diagnostics,
    macroSpecs: macros,
    failureHandler: { failure in
      Issue.record(
        Comment(rawValue: failure.message),
        sourceLocation: SourceLocation(
          fileID: failure.location.fileID,
          filePath: failure.location.filePath,
          line: failure.location.line,
          column: failure.location.column
        )
      )
    },
    fileID: fileID,
    filePath: filePath,
    line: line,
    column: column
  )
}

@Suite
struct WritableMacroTests {
  @Test func plainArrayExpansion() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Query(sort: \\Person.name)
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.name)
            private var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$persons`: SwiftDataWritable.WritableModelCollection<[Person]> {
                SwiftDataWritable.WritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: false
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func arraySpellingExpansion() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Query
          var persons: Array<Person>
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query
            var persons: Array<Person>

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            var `$persons`: SwiftDataWritable.WritableModelCollection<[Person]> {
                SwiftDataWritable.WritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: false
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func reorderableExpansion() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(mutableBy: \\Person.priority)
          @Query(sort: \\Person.priority)
          fileprivate var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.priority)
            fileprivate var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            fileprivate var `$persons`: SwiftDataWritable.KeyPathWritableModelCollection<[Person]> {
                SwiftDataWritable.KeyPathWritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: false,
                    mutableBy: \\Person.priority
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func autosaveQueryExpansionGeneratesWritableCollection() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(autosave: true)
          @Query(sort: \\Person.name)
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.name)
            private var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$persons`: SwiftDataWritable.WritableModelCollection<[Person]> {
                SwiftDataWritable.WritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: true
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func transactionQueryExpansionPassesTransaction() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(autosave: true, transaction: performPeopleTransaction)
          @Query(sort: \\Person.name)
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.name)
            private var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$persons`: SwiftDataWritable.WritableModelCollection<[Person]> {
                SwiftDataWritable.WritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: true,
                    transaction: SwiftDataWritable.WritableTransaction<[Person]>(
                        body: { context, value, mutation in
                            try (performPeopleTransaction)(context, value, mutation)
                        }
                    )
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func autosaveReorderableExpansionGeneratesWritableKeyPathCollection() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(autosave: true, mutableBy: \\Person.priority)
          @Query(sort: \\Person.priority)
          fileprivate var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.priority)
            fileprivate var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            fileprivate var `$persons`: SwiftDataWritable.KeyPathWritableModelCollection<[Person]> {
                SwiftDataWritable.KeyPathWritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: true,
                    mutableBy: \\Person.priority
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func throwsQueryExpansionGeneratesThrowsWritableCollection() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(autosave: true, throws: true)
          @Query(sort: \\Person.name)
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.name)
            private var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$persons`: SwiftDataWritable.ThrowsWritableModelCollection<[Person]> {
                SwiftDataWritable.ThrowsWritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: true
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func throwsReorderableExpansionGeneratesThrowsWritableKeyPathCollection() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(autosave: true, throws: true, mutableBy: \\Person.priority)
          @Query(sort: \\Person.priority)
          fileprivate var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.priority)
            fileprivate var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            fileprivate var `$persons`: SwiftDataWritable.KeyPathThrowsWritableModelCollection<[Person]> {
                SwiftDataWritable.KeyPathThrowsWritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: true,
                    mutableBy: \\Person.priority
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func transactionThrowsReorderableExpansionPassesTransaction() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(autosave: true, throws: true, mutableBy: \\Person.priority, transaction: performPeopleTransaction)
          @Query(sort: \\Person.priority)
          fileprivate var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.priority)
            fileprivate var persons: [Person]

            private var __macro_local_23_personsWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            fileprivate var `$persons`: SwiftDataWritable.KeyPathThrowsWritableModelCollection<[Person]> {
                SwiftDataWritable.KeyPathThrowsWritableModelCollection(
                    value: persons,
                    context: __macro_local_23_personsWritableContextfMu_.context,
                    autosave: true,
                    transaction: SwiftDataWritable.WritableTransaction<[Person]>(
                        body: { context, value, mutation in
                            try (performPeopleTransaction)(context, value, mutation)
                        }
                    ),
                    mutableBy: \\Person.priority
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func singleModelExpansion() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable
          private var person: Person
      }
      """,
      expandedSource: """
        struct PersonView {
            private var person: Person

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$person`: SwiftDataWritable.WritableModel<Person> {
                SwiftDataWritable.WritableModel(
                    value: person,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: false
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func autosaveSingleModelExpansionGeneratesWritableModel() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable(autosave: true)
          private var person: Person
      }
      """,
      expandedSource: """
        struct PersonView {
            private var person: Person

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$person`: SwiftDataWritable.WritableModel<Person> {
                SwiftDataWritable.WritableModel(
                    value: person,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: true
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func transactionSingleModelExpansionPassesTransaction() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable(autosave: true, throws: true, transaction: performPersonTransaction)
          private var person: Person
      }
      """,
      expandedSource: """
        struct PersonView {
            private var person: Person

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$person`: SwiftDataWritable.ThrowsWritableModel<Person> {
                SwiftDataWritable.ThrowsWritableModel(
                    value: person,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: true,
                    transaction: SwiftDataWritable.WritableTransaction<Person>(
                        body: { context, value, mutation in
                            try (performPersonTransaction)(context, value, mutation)
                        }
                    )
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func optionalSingleModelExpansion() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable
          var person: Person?
      }
      """,
      expandedSource: """
        struct PersonView {
            var person: Person?

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            var `$person`: SwiftDataWritable.WritableModel<Person>? {
                guard let model = person else {
                    return nil
                }

                return SwiftDataWritable.WritableModel(
                    value: model,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: false
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func autosaveOptionalSingleModelExpansionGeneratesWritableModel() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable(autosave: true)
          var person: Person?
      }
      """,
      expandedSource: """
        struct PersonView {
            var person: Person?

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            var `$person`: SwiftDataWritable.WritableModel<Person>? {
                guard let model = person else {
                    return nil
                }

                return SwiftDataWritable.WritableModel(
                    value: model,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: true
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func transactionOptionalSingleModelExpansionPassesTransaction() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable(autosave: true, transaction: performPersonTransaction)
          var person: Person?
      }
      """,
      expandedSource: """
        struct PersonView {
            var person: Person?

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            var `$person`: SwiftDataWritable.WritableModel<Person>? {
                guard let model = person else {
                    return nil
                }

                return SwiftDataWritable.WritableModel(
                    value: model,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: true,
                    transaction: SwiftDataWritable.WritableTransaction<Person>(
                        body: { context, value, mutation in
                            try (performPersonTransaction)(context, value, mutation)
                        }
                    )
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func throwsSingleModelExpansionGeneratesThrowsWritableModel() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable(throws: true)
          private var person: Person
      }
      """,
      expandedSource: """
        struct PersonView {
            private var person: Person

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            private var `$person`: SwiftDataWritable.ThrowsWritableModel<Person> {
                SwiftDataWritable.ThrowsWritableModel(
                    value: person,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: false
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func throwsOptionalSingleModelExpansionGeneratesThrowsWritableModel() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable(autosave: true, throws: true)
          var person: Person?
      }
      """,
      expandedSource: """
        struct PersonView {
            var person: Person?

            private var __macro_local_22_personWritableContextfMu_ = SwiftDataWritable._WritableModelContextReader()

            var `$person`: SwiftDataWritable.ThrowsWritableModel<Person>? {
                guard let model = person else {
                    return nil
                }

                return SwiftDataWritable.ThrowsWritableModel(
                    value: model,
                    context: __macro_local_22_personWritableContextfMu_.context,
                    autosave: true
                )
            }
        }
        """,
      macros: testMacros
    )
  }

  @Test func bindableCompatExpansionDoesNotGenerateProjection() throws {
    assertMacroExpansion(
      """
      struct PersonView {
          @Writable
          @Bindable
          var person: Person
      }
      """,
      expandedSource: """
        struct PersonView {
            @Bindable
            var person: Person
        }
        """,
      macros: testMacros
    )
  }

  @Test func missingQueryDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            private var persons: [Person]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Writable collections require a @Query-backed array property.",
          line: 3,
          column: 26
        )
      ],
      macros: testMacros
    )
  }

  @Test func nonLiteralAutosaveDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(autosave: shouldSave)
          @Query(sort: \\Person.name)
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.name)
            private var persons: [Person]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Writable(autosave:) requires a literal true or false value.",
          line: 2,
          column: 25
        )
      ],
      macros: testMacros
    )
  }

  @Test func nonLiteralThrowsDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(throws: shouldThrow)
          @Query(sort: \\Person.name)
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query(sort: \\Person.name)
            private var persons: [Person]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Writable(throws:) requires a literal true or false value.",
          line: 2,
          column: 23
        )
      ],
      macros: testMacros
    )
  }

  @Test func missingExplicitTypeDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Query
          private var persons
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query
            private var persons
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "@Writable requires an explicit collection type annotation, for example: private var persons: [Person].",
          line: 4,
          column: 17
        )
      ],
      macros: testMacros
    )
  }

  @Test func mutableBySingleModelDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable(mutableBy: \\Person.priority)
          private var person: Person
      }
      """,
      expandedSource: """
        struct PeopleView {
            private var person: Person
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Writable(mutableBy:) can only be used with @Query-backed collection properties.",
          line: 2,
          column: 5
        )
      ],
      macros: testMacros
    )
  }

  @Test func relationshipDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Relationship
          var tags: [Tag]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Relationship
            var tags: [Tag]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "@Writable is not for @Relationship fields. Project relationships from a writable owner model or use domain methods instead.",
          line: 2,
          column: 5
        )
      ],
      macros: testMacros
    )
  }

  @Test func attributeDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Attribute(.unique)
          var tags: [Tag]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Attribute(.unique)
            var tags: [Tag]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "@Writable is not for @Attribute fields. Use it with query collections or model properties instead.",
          line: 2,
          column: 5
        )
      ],
      macros: testMacros
    )
  }

  @Test func transientDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Transient
          var tags: [Tag]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Transient
            var tags: [Tag]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "@Writable is not for @Transient fields. Use it with query collections or model properties instead.",
          line: 2,
          column: 5
        )
      ],
      macros: testMacros
    )
  }

  @Test func invalidCollectionDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Query
          private var persons: Set<Person>
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Query
            private var persons: Set<Person>
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Writable supports [Model] or Array<Model> query results.",
          line: 4,
          column: 26
        )
      ],
      macros: testMacros
    )
  }

  @Test func bindableQueryDiagnostic() throws {
    assertMacroExpansion(
      """
      struct PeopleView {
          @Writable
          @Bindable
          @Query
          private var persons: [Person]
      }
      """,
      expandedSource: """
        struct PeopleView {
            @Bindable
            @Query
            private var persons: [Person]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Writable @Bindable cannot be combined with @Query.",
          line: 2,
          column: 5
        )
      ],
      macros: testMacros
    )
  }
}
