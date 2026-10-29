# GTest fixture suite

Single combined CMake fixture used to exercise the neotest GTest adapter.
Builds two test executables:

- `gtest_all` — contains every GTest test type, so a single fixture exercises
  every code path in the adapter's suite classification
  (`Basic`, `Parameterized`, `Typed`, `ParameterizedTyped`).
- `gtest_second` — a second, distinct executable with its own tests, used to
  verify multi-executable discovery and filtering (death tests, suite-level
  `SetUpTestSuite`/`TearDownTestSuite`, and tests in nested directories).

Set `CMAKESEER_GTEST_SOURCE_DIR` to a local googletest checkout to avoid
downloading it during fixture builds.

## `gtest_all` test types covered (≥2 of each)

| Type | Macro | Source | Count |
| :--- | :--- | :--- | :--- |
| Basic | `TEST` | `basic_test.cpp` | 4 tests / 2 suites (incl. 1 disabled) |
| Fixture | `TEST_F` | `fixture_test.cpp` | 4 tests / 2 fixtures (incl. 1 disabled) |
| Value-parameterized | `TEST_P` | `parameterized_test.cpp` | 8 tests / 2 instantiation prefixes (incl. 1 disabled) |
| Typed | `TYPED_TEST` | `typed_test.cpp` | 4 tests / 2 types |
| Type-parameterized | `TYPED_TEST_P` | `parameterized_typed_test.cpp` | 8 tests / 2 prefixes × 2 types |
| Nested directory | `TEST` | `nested/nested_test.cpp` | 2 tests / 1 suite |

## `gtest_second` tests covered

| Type | Macro | Source | Count |
| :--- | :--- | :--- | :--- |
| Basic | `TEST` | `second_test.cpp` | 2 tests / 1 suite |
| Fixture | `TEST_F` | `second_test.cpp` | 4 tests / 1 fixture (death tests) |
| Nested directory | `TEST` | `nested/second_nested_test.cpp` | 2 tests / 1 suite |

Death tests (`EXPECT_DEATH_IF_SUPPORTED`) and suite-level
`SetUpTestSuite`/`TearDownTestSuite` exercise additional adapter paths.

Disabling tests (`DISABLED_*`) exercises
`--gtest_also_run_disabled_tests` and the `NOTRUN`/`SKIPPED` status path.
Failing assertions exercise the failure-reporting path in `results()`.

## gtest JSON list-output shapes exercised

- `TEST` / `TEST_F` → suite `SuiteName` (1 path part → `Basic`)
- `TEST_P` → suite `Prefix/Suite`, test `Test/0` with `value_param` (→ `Parameterized`)
- `TYPED_TEST` → suite `Suite/0` with `type_param` (→ `Typed`)
- `TYPED_TEST_P` → suite `Prefix/Suite/0` with `type_param` (→ `ParameterizedTyped`)
