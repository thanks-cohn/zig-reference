module.exports = {
  "schemaVersion": "1.0.0",
  "contractVersion": "1.0.0",
  "module": {
    "id": "54",
    "canonicalName": "bounded-elf64-load-plan",
    "displayName": "Bounded Elf64 Load Plan",
    "directory": "projects/54-bounded-elf64-load-plan",
    "publicEntrypoint": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
    "detailsContract": "projects/54-bounded-elf64-load-plan/details.json",
    "humanContract": "projects/54-bounded-elf64-load-plan/DETAILS.md",
    "portContract": "projects/54-bounded-elf64-load-plan/port.js"
  },
  "baseline": {
    "zigVersion": "0.14.0",
    "minimumSupportedVersion": "0.14.0",
    "maximumTestedVersion": "",
    "baselineCompilerValidated": false,
    "baselineUnitTestsPassed": false,
    "baselineSmokeTestsPassed": false,
    "lastValidatedCommit": "",
    "validationEvidence": [
      "Zig compiler was unavailable in the authoring environment; claims remain unverified."
    ]
  },
  "sourceInventory": {
    "implementationFiles": [
      "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
    ],
    "publicEntrypoints": [
      "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
    ],
    "internalUnitTests": [
      "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
    ],
    "externalSmokeTests": [
      "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
    ],
    "examples": [],
    "fixtures": [],
    "benchmarks": [],
    "fuzzTargets": [],
    "buildDefinitions": [
      "build.zig"
    ],
    "contracts": [
      "projects/54-bounded-elf64-load-plan/README.md",
      "projects/54-bounded-elf64-load-plan/MASTERY.md",
      "projects/54-bounded-elf64-load-plan/DETAILS.md",
      "projects/54-bounded-elf64-load-plan/details.json",
      "projects/54-bounded-elf64-load-plan/port.js"
    ]
  },
  "publicContract": {
    "publicSymbols": [
      "Error",
      "LoadPlan",
      "Permissions",
      "SegmentPlan",
      "max_program_headers",
      "plan",
      "riscv_machine",
      "DynamicLoadPlan",
      "planDynamic"
    ],
    "publicTypes": [
      {
        "name": "Error",
        "kind": "public declaration"
      },
      {
        "name": "LoadPlan",
        "kind": "public declaration"
      },
      {
        "name": "Permissions",
        "kind": "public declaration"
      },
      {
        "name": "SegmentPlan",
        "kind": "public declaration"
      },
      {
        "name": "DynamicLoadPlan",
        "kind": "public declaration"
      }
    ],
    "publicFunctions": [
      {
        "name": "LoadPlan",
        "signature": "LoadPlan(comptime capacity: usize) type"
      },
      {
        "name": "plan",
        "signature": "plan(comptime capacity: usize, bytes: []const u8) Error!LoadPlan(capacity)"
      },
      {
        "name": "DynamicLoadPlan",
        "signature": "DynamicLoadPlan(comptime capacity: usize, comptime interpreter_capacity: usize) type"
      },
      {
        "name": "planDynamic",
        "signature": "planDynamic(comptime capacity: usize, comptime interpreter_capacity: usize, bytes: []const u8) Error!DynamicLoadPlan(capacity, interpreter_capacity)"
      }
    ],
    "publicMethods": [
      {
        "name": "interpreterPath",
        "signature": "interpreterPath(self: *const DynamicLoadPlan) ?[]const u8"
      }
    ],
    "publicConstants": [
      {
        "name": "max_program_headers",
        "type": "usize",
        "value": "64",
        "summary": "Maximum parsed program-header rows."
      },
      {
        "name": "riscv_machine",
        "type": "u16",
        "value": "243",
        "summary": "ELF RISC-V machine identity."
      }
    ],
    "publicErrors": [
      "UnsupportedEndian",
      "UnsupportedMachine",
      "UnsupportedObjectType",
      "UnsupportedFeature",
      "NoLoadableSegment",
      "SegmentFileOutOfBounds",
      "EntryOutOfRange",
      "WriteWithoutRead",
      "UnsupportedPermissions",
      "UnsupportedAlignment",
      "OverlappingLoadSegments",
      "EntryNotExecutable",
      "PlanCapacityExceeded",
      "InterpreterPathMissingTerminator",
      "InterpreterPathContainsNul",
      "InterpreterPathTooLong"
    ],
    "invariantsToPreserve": [
      "Preserve the documented bounded-elf64-load-plan public behavior, boundaries, and failure semantics."
    ],
    "ownershipRulesToPreserve": [],
    "lifetimeRulesToPreserve": [],
    "cleanupRulesToPreserve": [],
    "invalidationRulesToPreserve": [],
    "failureAtomicityToPreserve": [],
    "binaryLayoutsToPreserve": [],
    "compatibilityPromisesToPreserve": [],
    "intentionallyUnstableDetails": []
  },
  "dependencies": {
    "repository": [
      {
        "canonicalName": "bounded-byte-reader",
        "portContract": "projects/04-bounded-byte-reader/port.js",
        "importName": "bounded-byte-reader",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      },
      {
        "canonicalName": "checked-integer-cast",
        "portContract": "projects/10-checked-integer-cast/port.js",
        "importName": "checked-integer-cast",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      },
      {
        "canonicalName": "fixed-capacity-vector",
        "portContract": "projects/00-fixed-capacity-vector/port.js",
        "importName": "fixed-capacity-vector",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      },
      {
        "canonicalName": "checked-half-open-range",
        "portContract": "projects/17-checked-half-open-range/port.js",
        "importName": "checked-half-open-range",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      },
      {
        "canonicalName": "distinct-memory-address-types",
        "portContract": "projects/18-distinct-memory-address-types/port.js",
        "importName": "distinct-memory-address-types",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      },
      {
        "canonicalName": "elf64-file-header-parser",
        "portContract": "projects/37-elf64-file-header-parser/port.js",
        "importName": "elf64-file-header-parser",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      },
      {
        "canonicalName": "elf64-program-header-parser",
        "portContract": "projects/38-elf64-program-header-parser/port.js",
        "importName": "elf64-program-header-parser",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      }
    ],
    "standardLibrary": [
      "std.math.maxInt",
      "std.mem.indexOfScalar",
      "std.mem.writeInt",
      "std.testing.expect",
      "std.testing.expectEqual",
      "std.testing.expectEqualDeep",
      "std.testing.expectEqualStrings",
      "std.testing.expectError"
    ],
    "external": []
  },
  "zigLanguageFeatures": {
    "used": [
      "error unions"
    ],
    "versionSensitive": [
      "@This",
      "@as",
      "@intCast",
      "@memcpy",
      "@sizeOf"
    ],
    "notes": []
  },
  "compilerBuiltins": {
    "used": [
      {
        "name": "@This",
        "files": [
          {
            "path": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
            "lines": [],
            "symbols": []
          }
        ],
        "baselineBehavior": "Zig 0.14.0 @This behavior as exercised by this module",
        "portingRisk": "medium",
        "likelyChangeCategory": "syntax_or_type_semantics",
        "notes": []
      },
      {
        "name": "@as",
        "files": [
          {
            "path": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
            "lines": [],
            "symbols": []
          },
          {
            "path": "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig",
            "lines": [],
            "symbols": []
          }
        ],
        "baselineBehavior": "Zig 0.14.0 @as behavior as exercised by this module",
        "portingRisk": "medium",
        "likelyChangeCategory": "syntax_or_type_semantics",
        "notes": []
      },
      {
        "name": "@intCast",
        "files": [
          {
            "path": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
            "lines": [],
            "symbols": []
          }
        ],
        "baselineBehavior": "Zig 0.14.0 @intCast behavior as exercised by this module",
        "portingRisk": "medium",
        "likelyChangeCategory": "syntax_or_type_semantics",
        "notes": []
      },
      {
        "name": "@memcpy",
        "files": [
          {
            "path": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
            "lines": [],
            "symbols": []
          }
        ],
        "baselineBehavior": "Zig 0.14.0 @memcpy behavior as exercised by this module",
        "portingRisk": "medium",
        "likelyChangeCategory": "syntax_or_type_semantics",
        "notes": []
      },
      {
        "name": "@sizeOf",
        "files": [
          {
            "path": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
            "lines": [],
            "symbols": []
          },
          {
            "path": "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig",
            "lines": [],
            "symbols": []
          }
        ],
        "baselineBehavior": "Zig 0.14.0 @sizeOf behavior as exercised by this module",
        "portingRisk": "medium",
        "likelyChangeCategory": "syntax_or_type_semantics",
        "notes": []
      }
    ],
    "notUsed": []
  },
  "standardLibraryUsage": {
    "imports": [
      {
        "path": "std.math.maxInt",
        "symbols": [
          "std.math.maxInt"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ],
        "purpose": "implementation support",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.mem.indexOfScalar",
        "symbols": [
          "std.mem.indexOfScalar"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ],
        "purpose": "implementation support",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.mem.writeInt",
        "symbols": [
          "std.mem.writeInt"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ],
        "purpose": "implementation support",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.testing.expect",
        "symbols": [
          "std.testing.expect"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
          "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
        ],
        "purpose": "test assertions and test allocation",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.testing.expectEqual",
        "symbols": [
          "std.testing.expectEqual"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
          "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
        ],
        "purpose": "test assertions and test allocation",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.testing.expectEqualDeep",
        "symbols": [
          "std.testing.expectEqualDeep"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ],
        "purpose": "test assertions and test allocation",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.testing.expectEqualStrings",
        "symbols": [
          "std.testing.expectEqualStrings"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ],
        "purpose": "test assertions and test allocation",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.testing.expectError",
        "symbols": [
          "std.testing.expectError"
        ],
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ],
        "purpose": "test assertions and test allocation",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      }
    ],
    "testingApis": [
      "std.testing.expect",
      "std.testing.expectEqual",
      "std.testing.expectEqualDeep",
      "std.testing.expectEqualStrings",
      "std.testing.expectError"
    ],
    "allocatorApis": [],
    "ioApis": [],
    "endianApis": [
      "std.mem.writeInt"
    ],
    "mathApis": [
      "std.math.maxInt"
    ],
    "metadataApis": []
  },
  "buildSystemUsage": {
    "unitTestStep": "test-bounded-elf64-load-plan",
    "smokeTestStep": "smoke-bounded-elf64-load-plan",
    "namedModuleImport": "bounded-elf64-load-plan",
    "sourcePath": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
    "directModuleDependencies": [
      "bounded-byte-reader",
      "checked-integer-cast",
      "fixed-capacity-vector",
      "checked-half-open-range",
      "distinct-memory-address-types",
      "elf64-file-header-parser",
      "elf64-program-header-parser"
    ],
    "buildApisUsed": [
      "std.Build.createModule",
      "std.Build.addTest",
      "std.Build.addRunArtifact",
      "std.Build.Module.addImport",
      "std.Build.step"
    ],
    "rootModuleConfiguration": [
      "root_module"
    ],
    "targetConfiguration": [
      "standardTargetOptions"
    ],
    "optimizeConfiguration": [
      "standardOptimizeOption"
    ],
    "runArtifacts": [
      "test-bounded-elf64-load-plan",
      "smoke-bounded-elf64-load-plan"
    ],
    "systemCommands": [],
    "likelyPortingRisks": [
      "Named module identity and dependency imports must remain singular and ordered."
    ]
  },
  "targetAndPlatformUsage": {
    "hosted": "",
    "freestanding": "",
    "targets": [],
    "endianSensitive": true,
    "notes": []
  },
  "allocatorUsage": {
    "allocatorSensitive": false,
    "apis": [],
    "ownershipTransitions": [],
    "notes": []
  },
  "pointerAndMemoryUsage": {
    "pointerSensitive": true,
    "builtins": [
      "@memcpy"
    ],
    "borrowedMemoryRules": [],
    "notes": []
  },
  "integerAndCastUsage": {
    "builtins": [
      "@as",
      "@intCast"
    ],
    "overflowSemantics": [],
    "notes": []
  },
  "reflectionAndComptimeUsage": {
    "reflectionSensitive": false,
    "builtins": [],
    "comptimeParameters": [],
    "notes": []
  },
  "errorHandlingUsage": {
    "publicErrors": [
      "UnsupportedEndian",
      "UnsupportedMachine",
      "UnsupportedObjectType",
      "UnsupportedFeature",
      "NoLoadableSegment",
      "SegmentFileOutOfBounds",
      "EntryOutOfRange",
      "WriteWithoutRead",
      "UnsupportedPermissions",
      "UnsupportedAlignment",
      "OverlappingLoadSegments",
      "EntryNotExecutable",
      "PlanCapacityExceeded",
      "InterpreterPathMissingTerminator",
      "InterpreterPathContainsNul",
      "InterpreterPathTooLong"
    ],
    "failureGuarantees": [],
    "panicBehavior": "",
    "notes": []
  },
  "testingUsage": {
    "unitTests": [
      "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
    ],
    "smokeTests": [
      "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
    ],
    "testingApis": [
      "std.testing.expect",
      "std.testing.expectEqual",
      "std.testing.expectEqualDeep",
      "std.testing.expectEqualStrings",
      "std.testing.expectError"
    ],
    "semanticCoverage": []
  },
  "knownVersionChanges": [],
  "possibleMechanicalTransforms": [],
  "manualReviewRequired": [
    {
      "topic": "semantic and build compatibility",
      "reason": "Unknown future Zig releases can change inference, standard-library contracts, or build graph identity.",
      "affectedSymbols": [
        "Error",
        "LoadPlan",
        "Permissions",
        "SegmentPlan",
        "max_program_headers",
        "plan",
        "riscv_machine",
        "DynamicLoadPlan",
        "planDynamic"
      ],
      "affectedFiles": [
        "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      ],
      "questionsToAnswer": [
        "Do public errors, ownership, layout, and failure atomicity still match the contracts?"
      ],
      "requiredTests": [
        "zig build test-bounded-elf64-load-plan",
        "zig build smoke-bounded-elf64-load-plan"
      ]
    }
  ],
  "semanticPortingRisks": [
    {
      "risk": "Preserve the documented bounded-elf64-load-plan public behavior, boundaries, and failure semantics.",
      "consequence": "A syntactically successful port could violate the module contract.",
      "affectedEndpoints": [
        "Error",
        "LoadPlan",
        "Permissions",
        "SegmentPlan",
        "max_program_headers",
        "plan",
        "riscv_machine",
        "DynamicLoadPlan",
        "planDynamic"
      ],
      "detectionTests": [
        "zig build test-bounded-elf64-load-plan",
        "zig build smoke-bounded-elf64-load-plan"
      ],
      "mitigation": "Compare DETAILS.md and details.json, then run boundary and failure-path tests."
    }
  ],
  "migrationOrder": {
    "portAfter": [
      "bounded-byte-reader",
      "checked-integer-cast",
      "fixed-capacity-vector",
      "checked-half-open-range",
      "distinct-memory-address-types",
      "elf64-file-header-parser",
      "elf64-program-header-parser"
    ],
    "portBefore": [],
    "independentOf": [],
    "recommendedSequence": [
      "bounded-byte-reader",
      "checked-integer-cast",
      "fixed-capacity-vector",
      "checked-half-open-range",
      "distinct-memory-address-types",
      "elf64-file-header-parser",
      "elf64-program-header-parser",
      "bounded-elf64-load-plan"
    ],
    "cycleRisks": []
  },
  "validationPlan": {
    "baselineCommands": [
      "zig version",
      "zig build check-module-contracts",
      "zig build check-port-contracts",
      "zig build test-bounded-elf64-load-plan",
      "zig build smoke-bounded-elf64-load-plan"
    ],
    "targetVersionCommands": [],
    "semanticTests": [],
    "layoutChecks": [],
    "compileErrorExpectations": [],
    "manualReviewSteps": [
      "Review compiler diagnostics against verified release notes.",
      "Compare public behavior, ownership, and failure semantics with the contracts."
    ],
    "successCriteria": [
      "All contract, unit, and smoke checks pass without semantic drift."
    ],
    "failureCriteria": [
      "Any unsupported-version claim, changed public behavior, or failing validation command."
    ]
  },
  "testedTargets": [],
  "untestedTargets": [
    {
      "zigVersion": ">0.14.0",
      "status": "not_tested",
      "expectedDifficulty": "unknown",
      "knownBlockers": [],
      "notes": [
        "Inspect verified release notes and compiler diagnostics before creating migration rules."
      ]
    }
  ],
  "agentInstructions": {
    "readFirst": [
      "projects/54-bounded-elf64-load-plan/port.js",
      "projects/54-bounded-elf64-load-plan/details.json",
      "projects/54-bounded-elf64-load-plan/DETAILS.md",
      "projects/04-bounded-byte-reader/port.js",
      "projects/10-checked-integer-cast/port.js",
      "projects/00-fixed-capacity-vector/port.js",
      "projects/17-checked-half-open-range/port.js",
      "projects/18-distinct-memory-address-types/port.js",
      "projects/37-elf64-file-header-parser/port.js",
      "projects/38-elf64-program-header-parser/port.js"
    ],
    "filesUsuallyNotRequired": [],
    "firstCommands": [
      "zig version",
      "zig build test-bounded-elf64-load-plan"
    ],
    "recommendedPortOrder": [
      "bounded-byte-reader",
      "checked-integer-cast",
      "fixed-capacity-vector",
      "checked-half-open-range",
      "distinct-memory-address-types",
      "elf64-file-header-parser",
      "elf64-program-header-parser",
      "bounded-elf64-load-plan"
    ],
    "searchTerms": [
      "@This",
      "@as",
      "@intCast",
      "@memcpy",
      "@sizeOf",
      "std.math.maxInt",
      "std.mem.indexOfScalar",
      "std.mem.writeInt",
      "std.testing.expect",
      "std.testing.expectEqual",
      "std.testing.expectEqualDeep",
      "std.testing.expectEqualStrings",
      "std.testing.expectError"
    ],
    "likelyCompilerFailureAreas": [
      "@This",
      "@as",
      "@intCast",
      "@memcpy",
      "@sizeOf",
      "std.math.maxInt",
      "std.mem.indexOfScalar",
      "std.mem.writeInt",
      "std.testing.expect",
      "std.testing.expectEqual",
      "std.testing.expectEqualDeep",
      "std.testing.expectEqualStrings",
      "std.testing.expectError"
    ],
    "doNotAssume": [
      "Compilation proves semantic or binary-layout compatibility.",
      "A newer std.Build API preserves module identity.",
      "Unknown future releases have a mechanical replacement path."
    ],
    "stopConditions": [
      "Stop before recording support when the exact target compiler and semantic tests have not run."
    ],
    "completionChecklist": [
      "Port dependencies first.",
      "Run contract checks, unit tests, and smoke tests.",
      "Record evidence without deleting baseline history."
    ]
  },
  "sourceMap": {
    "builtinsToFiles": [
      {
        "builtin": "@This",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "builtin": "@as",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
          "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
        ]
      },
      {
        "builtin": "@intCast",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "builtin": "@memcpy",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "builtin": "@sizeOf",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
          "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
        ]
      }
    ],
    "standardLibraryToFiles": [
      {
        "api": "std.math.maxInt",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "api": "std.mem.indexOfScalar",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "api": "std.mem.writeInt",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "api": "std.testing.expect",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
          "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
        ]
      },
      {
        "api": "std.testing.expectEqual",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig",
          "projects/54-bounded-elf64-load-plan/tests/smoke_test.zig"
        ]
      },
      {
        "api": "std.testing.expectEqualDeep",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "api": "std.testing.expectEqualStrings",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      },
      {
        "api": "std.testing.expectError",
        "files": [
          "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
        ]
      }
    ],
    "symbolsToFiles": [
      {
        "symbol": "Error",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "LoadPlan",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "Permissions",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "SegmentPlan",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "max_program_headers",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "plan",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "riscv_machine",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "DynamicLoadPlan",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      },
      {
        "symbol": "planDynamic",
        "file": "projects/54-bounded-elf64-load-plan/src/bounded_elf64_load_plan.zig"
      }
    ]
  },
  "history": {
    "baselineEstablished": "Zig 0.14.0",
    "migrations": [],
    "notes": [
      "No later Zig target has been tested."
    ]
  }
};
