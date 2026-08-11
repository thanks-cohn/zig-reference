module.exports = {
  "schemaVersion": "1.0.0",
  "contractVersion": "1.0.0",
  "module": {
    "id": "59",
    "canonicalName": "bounded-address-space-exec-image",
    "displayName": "Bounded Address Space Exec Image",
    "directory": "projects/59-bounded-address-space-exec-image",
    "publicEntrypoint": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
    "detailsContract": "projects/59-bounded-address-space-exec-image/details.json",
    "humanContract": "projects/59-bounded-address-space-exec-image/DETAILS.md",
    "portContract": "projects/59-bounded-address-space-exec-image/port.js"
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
      "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
    ],
    "publicEntrypoints": [
      "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
    ],
    "internalUnitTests": [
      "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
    ],
    "externalSmokeTests": [
      "projects/59-bounded-address-space-exec-image/tests/smoke_test.zig"
    ],
    "examples": [],
    "fixtures": [],
    "benchmarks": [],
    "fuzzTargets": [],
    "buildDefinitions": [
      "build.zig"
    ],
    "contracts": [
      "projects/59-bounded-address-space-exec-image/README.md",
      "projects/59-bounded-address-space-exec-image/MASTERY.md",
      "projects/59-bounded-address-space-exec-image/DETAILS.md",
      "projects/59-bounded-address-space-exec-image/details.json",
      "projects/59-bounded-address-space-exec-image/port.js"
    ]
  },
  "publicContract": {
    "publicSymbols": [
      "page_size",
      "Permissions",
      "Mapping",
      "Error",
      "AddressSpace",
      "ExecPlan"
    ],
    "publicTypes": [
      {
        "name": "Permissions",
        "kind": "public declaration"
      },
      {
        "name": "Mapping",
        "kind": "public declaration"
      },
      {
        "name": "Error",
        "kind": "public declaration"
      }
    ],
    "publicFunctions": [
      {
        "name": "AddressSpace",
        "signature": "AddressSpace(comptime capacity: usize) type"
      },
      {
        "name": "ExecPlan",
        "signature": "ExecPlan(comptime segment_capacity: usize, comptime interp_capacity: usize) type"
      }
    ],
    "publicMethods": [
      {
        "name": "map",
        "signature": "map(self: *Self, start: usize, length: usize, permissions: Permissions) Error!void"
      },
      {
        "name": "protect",
        "signature": "protect(self: *Self, start: usize, length: usize, permissions: Permissions) Error!void"
      },
      {
        "name": "unmap",
        "signature": "unmap(self: *Self, start: usize, length: usize) Error!void"
      },
      {
        "name": "contains",
        "signature": "contains(self: *const Self, address: usize, access: Permissions) bool"
      },
      {
        "name": "prepare",
        "signature": "prepare(main_bytes: []const u8, interp_bytes: ?[]const u8) Error!ExecPlan"
      }
    ],
    "publicConstants": [],
    "publicErrors": [],
    "invariantsToPreserve": [
      "Preserve the documented bounded-address-space-exec-image public behavior, boundaries, and failure semantics."
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
        "canonicalName": "bounded-elf64-load-plan",
        "portContract": "projects/54-bounded-elf64-load-plan/port.js",
        "importName": "bounded-elf64-load-plan",
        "symbolsUsed": [],
        "mustPortFirst": true,
        "reason": "The module imports this direct repository dependency in build.zig.",
        "guaranteesInherited": []
      }
    ],
    "standardLibrary": [
      "std.math.add",
      "std.mem.copyForwards",
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
    "used": [],
    "versionSensitive": [
      "@This",
      "@as",
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
            "path": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
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
            "path": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
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
        "name": "@memcpy",
        "files": [
          {
            "path": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
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
            "path": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
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
        "path": "std.math.add",
        "symbols": [
          "std.math.add"
        ],
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ],
        "purpose": "implementation support",
        "versionSensitivity": "medium",
        "knownChanges": [],
        "migrationNotes": []
      },
      {
        "path": "std.mem.copyForwards",
        "symbols": [
          "std.mem.copyForwards"
        ],
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
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
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
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
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
          "projects/59-bounded-address-space-exec-image/tests/smoke_test.zig"
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
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
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
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
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
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
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
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
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
      "std.math.add"
    ],
    "metadataApis": []
  },
  "buildSystemUsage": {
    "unitTestStep": "test-bounded-address-space-exec-image",
    "smokeTestStep": "smoke-bounded-address-space-exec-image",
    "namedModuleImport": "bounded-address-space-exec-image",
    "sourcePath": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
    "directModuleDependencies": [
      "bounded-elf64-load-plan"
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
      "test-bounded-address-space-exec-image",
      "smoke-bounded-address-space-exec-image"
    ],
    "systemCommands": [],
    "likelyPortingRisks": [
      "Named module identity and dependency imports must remain singular and ordered."
    ]
  },
  "targetAndPlatformUsage": {
    "hosted": "supported",
    "freestanding": "supported",
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
      "@as"
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
    "publicErrors": [],
    "failureGuarantees": [],
    "panicBehavior": "",
    "notes": []
  },
  "testingUsage": {
    "unitTests": [
      "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
    ],
    "smokeTests": [
      "projects/59-bounded-address-space-exec-image/tests/smoke_test.zig"
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
        "page_size",
        "Permissions",
        "Mapping",
        "Error",
        "AddressSpace",
        "ExecPlan"
      ],
      "affectedFiles": [
        "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
      ],
      "questionsToAnswer": [
        "Do public errors, ownership, layout, and failure atomicity still match the contracts?"
      ],
      "requiredTests": [
        "zig build test-bounded-address-space-exec-image",
        "zig build smoke-bounded-address-space-exec-image"
      ]
    }
  ],
  "semanticPortingRisks": [
    {
      "risk": "Preserve the documented bounded-address-space-exec-image public behavior, boundaries, and failure semantics.",
      "consequence": "A syntactically successful port could violate the module contract.",
      "affectedEndpoints": [
        "page_size",
        "Permissions",
        "Mapping",
        "Error",
        "AddressSpace",
        "ExecPlan"
      ],
      "detectionTests": [
        "zig build test-bounded-address-space-exec-image",
        "zig build smoke-bounded-address-space-exec-image"
      ],
      "mitigation": "Compare DETAILS.md and details.json, then run boundary and failure-path tests."
    }
  ],
  "migrationOrder": {
    "portAfter": [
      "bounded-elf64-load-plan"
    ],
    "portBefore": [],
    "independentOf": [],
    "recommendedSequence": [
      "bounded-elf64-load-plan",
      "bounded-address-space-exec-image"
    ],
    "cycleRisks": []
  },
  "validationPlan": {
    "baselineCommands": [
      "zig version",
      "zig build check-module-contracts",
      "zig build check-port-contracts",
      "zig build test-bounded-address-space-exec-image",
      "zig build smoke-bounded-address-space-exec-image"
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
      "projects/59-bounded-address-space-exec-image/port.js",
      "projects/59-bounded-address-space-exec-image/details.json",
      "projects/59-bounded-address-space-exec-image/DETAILS.md",
      "projects/54-bounded-elf64-load-plan/port.js"
    ],
    "filesUsuallyNotRequired": [],
    "firstCommands": [
      "zig version",
      "zig build test-bounded-address-space-exec-image"
    ],
    "recommendedPortOrder": [
      "bounded-elf64-load-plan",
      "bounded-address-space-exec-image"
    ],
    "searchTerms": [
      "@This",
      "@as",
      "@memcpy",
      "@sizeOf",
      "std.math.add",
      "std.mem.copyForwards",
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
      "@memcpy",
      "@sizeOf",
      "std.math.add",
      "std.mem.copyForwards",
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
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "builtin": "@as",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "builtin": "@memcpy",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "builtin": "@sizeOf",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      }
    ],
    "standardLibraryToFiles": [
      {
        "api": "std.math.add",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "api": "std.mem.copyForwards",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "api": "std.mem.writeInt",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "api": "std.testing.expect",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig",
          "projects/59-bounded-address-space-exec-image/tests/smoke_test.zig"
        ]
      },
      {
        "api": "std.testing.expectEqual",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "api": "std.testing.expectEqualDeep",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "api": "std.testing.expectEqualStrings",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      },
      {
        "api": "std.testing.expectError",
        "files": [
          "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
        ]
      }
    ],
    "symbolsToFiles": [
      {
        "symbol": "page_size",
        "file": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
      },
      {
        "symbol": "Permissions",
        "file": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
      },
      {
        "symbol": "Mapping",
        "file": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
      },
      {
        "symbol": "Error",
        "file": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
      },
      {
        "symbol": "AddressSpace",
        "file": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
      },
      {
        "symbol": "ExecPlan",
        "file": "projects/59-bounded-address-space-exec-image/src/bounded_address_space_exec_image.zig"
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
