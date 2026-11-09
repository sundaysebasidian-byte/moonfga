# Conformance report

MoonFGA is checked against the upstream OpenFGA authorization-model test matrix:

- `openfga/openfga` `44054f542f64e9b9589dd26a595081b3d2cfd942` (v1.22.1): `assets/tests/consolidated_1_1_tests.yaml`, `assets/tests/abac_tests.yaml`
- `openfga/language` `ed62a11e759a0faa1354404ead761f956469e149`: `tests/data/transformer` (DSL <-> JSON)

The upstream files are Apache-2.0 test data. They are downloaded by the pinned commit in `scripts/fetch-upstream.sh` into the git-ignored `.upstream/` cache and are not redistributed in this repository.

## How assertions are replayed

Each upstream test starts with a fresh in-memory tuple store. Stage models are parsed from the embedded DSL, stage tuples are appended to the store, and each assertion is executed independently. A stage whose model or tuples cannot be parsed marks its assertions as skipped with the parse error as the category, so unsupported input is never counted as a pass. `expectation: null` is treated as an empty result list, matching the upstream YAML semantics.

## Summary

| API | passed | total | percentage | failed | skipped |
| --- | ---: | ---: | ---: | ---: | ---: |
| Check | 516 | 516 | 100.00% | 0 | 0 |
| ListObjects | 354 | 354 | 100.00% | 0 | 0 |
| ListUsers | 393 | 394 | 99.75% | 0 | 1 |

| File | tests | Check | ListObjects | ListUsers |
| --- | ---: | --- | --- | --- |
| `consolidated_1_1_tests.yaml` | 138 | 364/364 (100.0%) | 272/272 (100.0%) | 296/297 (99.7%) (1 skipped) |
| `abac_tests.yaml` | 33 | 152/152 (100.0%) | 82/82 (100.0%) | 97/97 (100.0%) |

Targets are Check >= 95% and ListObjects/ListUsers >= 90%; the current run is above all three.

## Failure categories

There are no failed assertions in the pinned run. One assertion is skipped:

| Category | Count | Meaning |
| --- | ---: | --- |
| skip/no_expectation | 1 | The assertion has neither a top-level `expectation` nor `errorCode`; the value is nested in the request and is not a result assertion. |

Skipped assertion:

| File | API | Test | Stage | Detail |
| --- | --- | --- | ---: | --- |
| `consolidated_1_1_tests.yaml` | list_users | `simple_computeduserset_indirect_ref` | 0 | assertion has neither expectation nor errorCode |

## Full per-assertion results

Every assertion emitted by the runner is listed below (`pass`, `fail` or `skip`). The table is generated from `moon run cmd/conformance -- --json`.

| # | File | API | Test | Stage | Result | Category |
| ---: | --- | --- | --- | ---: | --- | --- |
| 1 | `consolidated_1_1_tests.yaml` | check | `this` | 0 | pass | — |
| 2 | `consolidated_1_1_tests.yaml` | check | `this` | 0 | pass | — |
| 3 | `consolidated_1_1_tests.yaml` | check | `this` | 0 | pass | — |
| 4 | `consolidated_1_1_tests.yaml` | list_objects | `this` | 0 | pass | — |
| 5 | `consolidated_1_1_tests.yaml` | list_objects | `this` | 0 | pass | — |
| 6 | `consolidated_1_1_tests.yaml` | list_users | `this` | 0 | pass | — |
| 7 | `consolidated_1_1_tests.yaml` | list_users | `this` | 0 | pass | — |
| 8 | `consolidated_1_1_tests.yaml` | check | `computed_userset` | 0 | pass | — |
| 9 | `consolidated_1_1_tests.yaml` | check | `computed_userset` | 0 | pass | — |
| 10 | `consolidated_1_1_tests.yaml` | check | `computed_userset` | 0 | pass | — |
| 11 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset` | 0 | pass | — |
| 12 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset` | 0 | pass | — |
| 13 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset` | 0 | pass | — |
| 14 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset` | 0 | pass | — |
| 15 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset` | 0 | pass | — |
| 16 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset` | 0 | pass | — |
| 17 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset` | 0 | pass | — |
| 18 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset` | 0 | pass | — |
| 19 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset` | 0 | pass | — |
| 20 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset` | 0 | pass | — |
| 21 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset` | 0 | pass | — |
| 22 | `consolidated_1_1_tests.yaml` | check | `this_and_union` | 0 | pass | — |
| 23 | `consolidated_1_1_tests.yaml` | check | `this_and_union` | 0 | pass | — |
| 24 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_union` | 0 | pass | — |
| 25 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_union` | 0 | pass | — |
| 26 | `consolidated_1_1_tests.yaml` | list_users | `this_and_union` | 0 | pass | — |
| 27 | `consolidated_1_1_tests.yaml` | list_users | `this_and_union` | 0 | pass | — |
| 28 | `consolidated_1_1_tests.yaml` | check | `this_and_intersection` | 0 | pass | — |
| 29 | `consolidated_1_1_tests.yaml` | check | `this_and_intersection` | 0 | pass | — |
| 30 | `consolidated_1_1_tests.yaml` | check | `this_and_intersection` | 0 | pass | — |
| 31 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_intersection` | 0 | pass | — |
| 32 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_intersection` | 0 | pass | — |
| 33 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_intersection` | 0 | pass | — |
| 34 | `consolidated_1_1_tests.yaml` | list_users | `this_and_intersection` | 0 | pass | — |
| 35 | `consolidated_1_1_tests.yaml` | check | `this_and_exclusion_base` | 0 | pass | — |
| 36 | `consolidated_1_1_tests.yaml` | check | `this_and_exclusion_base` | 0 | pass | — |
| 37 | `consolidated_1_1_tests.yaml` | check | `this_and_exclusion_base` | 0 | pass | — |
| 38 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_exclusion_base` | 0 | pass | — |
| 39 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_exclusion_base` | 0 | pass | — |
| 40 | `consolidated_1_1_tests.yaml` | list_objects | `this_and_exclusion_base` | 0 | pass | — |
| 41 | `consolidated_1_1_tests.yaml` | list_users | `this_and_exclusion_base` | 0 | pass | — |
| 42 | `consolidated_1_1_tests.yaml` | list_users | `this_and_exclusion_base` | 0 | pass | — |
| 43 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_computed_userset` | 0 | pass | — |
| 44 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_computed_userset` | 0 | pass | — |
| 45 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset_and_computed_userset` | 0 | pass | — |
| 46 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_union` | 0 | pass | — |
| 47 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_union` | 0 | pass | — |
| 48 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_union` | 0 | pass | — |
| 49 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_union` | 0 | pass | — |
| 50 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset_and_union` | 0 | pass | — |
| 51 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset_and_union` | 0 | pass | — |
| 52 | `consolidated_1_1_tests.yaml` | check | `simple_computeduserset_indirect_ref` | 0 | pass | — |
| 53 | `consolidated_1_1_tests.yaml` | check | `simple_computeduserset_indirect_ref` | 0 | pass | — |
| 54 | `consolidated_1_1_tests.yaml` | list_objects | `simple_computeduserset_indirect_ref` | 0 | pass | — |
| 55 | `consolidated_1_1_tests.yaml` | list_users | `simple_computeduserset_indirect_ref` | 0 | pass | — |
| 56 | `consolidated_1_1_tests.yaml` | list_users | `simple_computeduserset_indirect_ref` | 0 | pass | — |
| 57 | `consolidated_1_1_tests.yaml` | list_users | `simple_computeduserset_indirect_ref` | 0 | skip | no_expectation |
| 58 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_intersection` | 0 | pass | — |
| 59 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_intersection` | 0 | pass | — |
| 60 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_intersection` | 0 | pass | — |
| 61 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_intersection` | 0 | pass | — |
| 62 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_intersection` | 0 | pass | — |
| 63 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_intersection` | 0 | pass | — |
| 64 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset_and_intersection` | 0 | pass | — |
| 65 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_exclusion` | 0 | pass | — |
| 66 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_exclusion` | 0 | pass | — |
| 67 | `consolidated_1_1_tests.yaml` | check | `computed_userset_and_exclusion` | 0 | pass | — |
| 68 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_exclusion` | 0 | pass | — |
| 69 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_exclusion` | 0 | pass | — |
| 70 | `consolidated_1_1_tests.yaml` | list_objects | `computed_userset_and_exclusion` | 0 | pass | — |
| 71 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset_and_exclusion` | 0 | pass | — |
| 72 | `consolidated_1_1_tests.yaml` | list_users | `computed_userset_and_exclusion` | 0 | pass | — |
| 73 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_computed_userset` | 0 | pass | — |
| 74 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_computed_userset` | 0 | pass | — |
| 75 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_computed_userset` | 0 | pass | — |
| 76 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_computed_userset` | 0 | pass | — |
| 77 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_tuple_to_userset` | 0 | pass | — |
| 78 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_tuple_to_userset` | 0 | pass | — |
| 79 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_tuple_to_userset` | 0 | pass | — |
| 80 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_tuple_to_userset` | 0 | pass | — |
| 81 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_tuple_to_userset` | 0 | pass | — |
| 82 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_union` | 0 | pass | — |
| 83 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_union` | 0 | pass | — |
| 84 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_union` | 0 | pass | — |
| 85 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_union` | 0 | pass | — |
| 86 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_union` | 0 | pass | — |
| 87 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_union` | 0 | pass | — |
| 88 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_union` | 0 | pass | — |
| 89 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_union` | 0 | pass | — |
| 90 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_union` | 0 | pass | — |
| 91 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_union` | 0 | pass | — |
| 92 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 93 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 94 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 95 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 96 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 97 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 98 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 99 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 100 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 101 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 102 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_intersection` | 0 | pass | — |
| 103 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 104 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 105 | `consolidated_1_1_tests.yaml` | check | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 106 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 107 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 108 | `consolidated_1_1_tests.yaml` | list_objects | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 109 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 110 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 111 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 112 | `consolidated_1_1_tests.yaml` | list_users | `tuple_to_userset_and_exclusion` | 0 | pass | — |
| 113 | `consolidated_1_1_tests.yaml` | check | `union_and_tuple_to_userset` | 0 | pass | — |
| 114 | `consolidated_1_1_tests.yaml` | check | `union_and_tuple_to_userset` | 0 | pass | — |
| 115 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_tuple_to_userset` | 0 | pass | — |
| 116 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_tuple_to_userset` | 0 | pass | — |
| 117 | `consolidated_1_1_tests.yaml` | list_users | `union_and_tuple_to_userset` | 0 | pass | — |
| 118 | `consolidated_1_1_tests.yaml` | list_users | `union_and_tuple_to_userset` | 0 | pass | — |
| 119 | `consolidated_1_1_tests.yaml` | check | `union_and_union` | 0 | pass | — |
| 120 | `consolidated_1_1_tests.yaml` | check | `union_and_union` | 0 | pass | — |
| 121 | `consolidated_1_1_tests.yaml` | check | `union_and_union` | 0 | pass | — |
| 122 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_union` | 0 | pass | — |
| 123 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_union` | 0 | pass | — |
| 124 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_union` | 0 | pass | — |
| 125 | `consolidated_1_1_tests.yaml` | list_users | `union_and_union` | 0 | pass | — |
| 126 | `consolidated_1_1_tests.yaml` | list_users | `union_and_union` | 0 | pass | — |
| 127 | `consolidated_1_1_tests.yaml` | list_users | `union_and_union` | 0 | pass | — |
| 128 | `consolidated_1_1_tests.yaml` | check | `union_and_intersection` | 0 | pass | — |
| 129 | `consolidated_1_1_tests.yaml` | check | `union_and_intersection` | 0 | pass | — |
| 130 | `consolidated_1_1_tests.yaml` | check | `union_and_intersection` | 0 | pass | — |
| 131 | `consolidated_1_1_tests.yaml` | check | `union_and_intersection` | 0 | pass | — |
| 132 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_intersection` | 0 | pass | — |
| 133 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_intersection` | 0 | pass | — |
| 134 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_intersection` | 0 | pass | — |
| 135 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_intersection` | 0 | pass | — |
| 136 | `consolidated_1_1_tests.yaml` | list_users | `union_and_intersection` | 0 | pass | — |
| 137 | `consolidated_1_1_tests.yaml` | list_users | `union_and_intersection` | 0 | pass | — |
| 138 | `consolidated_1_1_tests.yaml` | list_users | `union_and_intersection` | 0 | pass | — |
| 139 | `consolidated_1_1_tests.yaml` | list_users | `union_and_intersection` | 0 | pass | — |
| 140 | `consolidated_1_1_tests.yaml` | check | `union_and_exclusion` | 0 | pass | — |
| 141 | `consolidated_1_1_tests.yaml` | check | `union_and_exclusion` | 0 | pass | — |
| 142 | `consolidated_1_1_tests.yaml` | check | `union_and_exclusion` | 0 | pass | — |
| 143 | `consolidated_1_1_tests.yaml` | check | `union_and_exclusion` | 0 | pass | — |
| 144 | `consolidated_1_1_tests.yaml` | check | `union_and_exclusion` | 0 | pass | — |
| 145 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_exclusion` | 0 | pass | — |
| 146 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_exclusion` | 0 | pass | — |
| 147 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_exclusion` | 0 | pass | — |
| 148 | `consolidated_1_1_tests.yaml` | list_objects | `union_and_exclusion` | 0 | pass | — |
| 149 | `consolidated_1_1_tests.yaml` | list_users | `union_and_exclusion` | 0 | pass | — |
| 150 | `consolidated_1_1_tests.yaml` | list_users | `union_and_exclusion` | 0 | pass | — |
| 151 | `consolidated_1_1_tests.yaml` | list_users | `union_and_exclusion` | 0 | pass | — |
| 152 | `consolidated_1_1_tests.yaml` | list_users | `union_and_exclusion` | 0 | pass | — |
| 153 | `consolidated_1_1_tests.yaml` | check | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 154 | `consolidated_1_1_tests.yaml` | check | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 155 | `consolidated_1_1_tests.yaml` | check | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 156 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 157 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 158 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 159 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 160 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 161 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_tuple_to_userset` | 0 | pass | — |
| 162 | `consolidated_1_1_tests.yaml` | check | `intersection_and_union` | 0 | pass | — |
| 163 | `consolidated_1_1_tests.yaml` | check | `intersection_and_union` | 0 | pass | — |
| 164 | `consolidated_1_1_tests.yaml` | check | `intersection_and_union` | 0 | pass | — |
| 165 | `consolidated_1_1_tests.yaml` | check | `intersection_and_union` | 0 | pass | — |
| 166 | `consolidated_1_1_tests.yaml` | check | `intersection_and_union` | 0 | pass | — |
| 167 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_union` | 0 | pass | — |
| 168 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_union` | 0 | pass | — |
| 169 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_union` | 0 | pass | — |
| 170 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_union` | 0 | pass | — |
| 171 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_union` | 0 | pass | — |
| 172 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_union` | 0 | pass | — |
| 173 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_union` | 0 | pass | — |
| 174 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_union` | 0 | pass | — |
| 175 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_union` | 0 | pass | — |
| 176 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_union` | 0 | pass | — |
| 177 | `consolidated_1_1_tests.yaml` | check | `intersection_and_intersection` | 0 | pass | — |
| 178 | `consolidated_1_1_tests.yaml` | check | `intersection_and_intersection` | 0 | pass | — |
| 179 | `consolidated_1_1_tests.yaml` | check | `intersection_and_intersection` | 0 | pass | — |
| 180 | `consolidated_1_1_tests.yaml` | check | `intersection_and_intersection` | 0 | pass | — |
| 181 | `consolidated_1_1_tests.yaml` | check | `intersection_and_intersection` | 0 | pass | — |
| 182 | `consolidated_1_1_tests.yaml` | check | `intersection_and_intersection` | 0 | pass | — |
| 183 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_intersection` | 0 | pass | — |
| 184 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_intersection` | 0 | pass | — |
| 185 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_intersection` | 0 | pass | — |
| 186 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_intersection` | 0 | pass | — |
| 187 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_intersection` | 0 | pass | — |
| 188 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_intersection` | 0 | pass | — |
| 189 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_intersection` | 0 | pass | — |
| 190 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_intersection` | 0 | pass | — |
| 191 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_intersection` | 0 | pass | — |
| 192 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_intersection` | 0 | pass | — |
| 193 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_intersection` | 0 | pass | — |
| 194 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_intersection` | 0 | pass | — |
| 195 | `consolidated_1_1_tests.yaml` | check | `intersection_and_exclusion` | 0 | pass | — |
| 196 | `consolidated_1_1_tests.yaml` | check | `intersection_and_exclusion` | 0 | pass | — |
| 197 | `consolidated_1_1_tests.yaml` | check | `intersection_and_exclusion` | 0 | pass | — |
| 198 | `consolidated_1_1_tests.yaml` | check | `intersection_and_exclusion` | 0 | pass | — |
| 199 | `consolidated_1_1_tests.yaml` | check | `intersection_and_exclusion` | 0 | pass | — |
| 200 | `consolidated_1_1_tests.yaml` | check | `intersection_and_exclusion` | 0 | pass | — |
| 201 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_exclusion` | 0 | pass | — |
| 202 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_exclusion` | 0 | pass | — |
| 203 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_exclusion` | 0 | pass | — |
| 204 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_exclusion` | 0 | pass | — |
| 205 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_exclusion` | 0 | pass | — |
| 206 | `consolidated_1_1_tests.yaml` | list_objects | `intersection_and_exclusion` | 0 | pass | — |
| 207 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_exclusion` | 0 | pass | — |
| 208 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_exclusion` | 0 | pass | — |
| 209 | `consolidated_1_1_tests.yaml` | list_users | `intersection_and_exclusion` | 0 | pass | — |
| 210 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_computed_userset` | 0 | pass | — |
| 211 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_computed_userset` | 0 | pass | — |
| 212 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_computed_userset` | 0 | pass | — |
| 213 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_computed_userset` | 0 | pass | — |
| 214 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_computed_userset` | 0 | pass | — |
| 215 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_computed_userset` | 0 | pass | — |
| 216 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_computed_userset` | 0 | pass | — |
| 217 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_computed_userset` | 0 | pass | — |
| 218 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 219 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 220 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 221 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 222 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 223 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 224 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 225 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 226 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 227 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_tuple_to_userset_in_base` | 0 | pass | — |
| 228 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 229 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 230 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 231 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 232 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 233 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 234 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 235 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_tuple_to_userset_in_subtract` | 0 | pass | — |
| 236 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_base` | 0 | pass | — |
| 237 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_base` | 0 | pass | — |
| 238 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_base` | 0 | pass | — |
| 239 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_base` | 0 | pass | — |
| 240 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_base` | 0 | pass | — |
| 241 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_base` | 0 | pass | — |
| 242 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_base` | 0 | pass | — |
| 243 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_base` | 0 | pass | — |
| 244 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_base` | 0 | pass | — |
| 245 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_base` | 0 | pass | — |
| 246 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_union_in_base` | 0 | pass | — |
| 247 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_union_in_base` | 0 | pass | — |
| 248 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_union_in_base` | 0 | pass | — |
| 249 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_union_in_base` | 0 | pass | — |
| 250 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 251 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 252 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 253 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 254 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 255 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 256 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 257 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 258 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_union_in_subtract` | 0 | pass | — |
| 259 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 260 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 261 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 262 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 263 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 264 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 265 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 266 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 267 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 268 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 269 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 270 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 271 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 272 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 273 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_base` | 0 | pass | — |
| 274 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 275 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 276 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 277 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 278 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 279 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 280 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 281 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 282 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 283 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 284 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_intersection_in_subtract` | 0 | pass | — |
| 285 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 286 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 287 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 288 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 289 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 290 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 291 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 292 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 293 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_base` | 0 | pass | — |
| 294 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 295 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 296 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 297 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 298 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 299 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 300 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 301 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_base_with_wildcard` | 0 | pass | — |
| 302 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 303 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 304 | `consolidated_1_1_tests.yaml` | check | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 305 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 306 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 307 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 308 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 309 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 310 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_and_exclusion_in_subtract` | 0 | pass | — |
| 311 | `consolidated_1_1_tests.yaml` | check | `userset_as_user` | 0 | pass | — |
| 312 | `consolidated_1_1_tests.yaml` | check | `userset_as_user` | 0 | pass | — |
| 313 | `consolidated_1_1_tests.yaml` | list_objects | `userset_as_user` | 0 | pass | — |
| 314 | `consolidated_1_1_tests.yaml` | list_objects | `userset_as_user` | 0 | pass | — |
| 315 | `consolidated_1_1_tests.yaml` | list_users | `userset_as_user` | 0 | pass | — |
| 316 | `consolidated_1_1_tests.yaml` | list_users | `userset_as_user` | 0 | pass | — |
| 317 | `consolidated_1_1_tests.yaml` | check | `wildcard_direct` | 0 | pass | — |
| 318 | `consolidated_1_1_tests.yaml` | check | `wildcard_direct` | 0 | pass | — |
| 319 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_direct` | 0 | pass | — |
| 320 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_direct` | 0 | pass | — |
| 321 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_direct` | 0 | pass | — |
| 322 | `consolidated_1_1_tests.yaml` | check | `prior_type_restrictions_ignored` | 0 | pass | — |
| 323 | `consolidated_1_1_tests.yaml` | list_objects | `prior_type_restrictions_ignored` | 0 | pass | — |
| 324 | `consolidated_1_1_tests.yaml` | list_users | `prior_type_restrictions_ignored` | 0 | pass | — |
| 325 | `consolidated_1_1_tests.yaml` | check | `prior_type_restrictions_ignored` | 1 | pass | — |
| 326 | `consolidated_1_1_tests.yaml` | list_objects | `prior_type_restrictions_ignored` | 1 | pass | — |
| 327 | `consolidated_1_1_tests.yaml` | list_users | `prior_type_restrictions_ignored` | 1 | pass | — |
| 328 | `consolidated_1_1_tests.yaml` | check | `prior_type_restrictions_ignored_with_wildcard` | 0 | pass | — |
| 329 | `consolidated_1_1_tests.yaml` | list_objects | `prior_type_restrictions_ignored_with_wildcard` | 0 | pass | — |
| 330 | `consolidated_1_1_tests.yaml` | list_users | `prior_type_restrictions_ignored_with_wildcard` | 0 | pass | — |
| 331 | `consolidated_1_1_tests.yaml` | check | `prior_type_restrictions_ignored_with_wildcard` | 1 | pass | — |
| 332 | `consolidated_1_1_tests.yaml` | list_objects | `prior_type_restrictions_ignored_with_wildcard` | 1 | pass | — |
| 333 | `consolidated_1_1_tests.yaml` | list_users | `prior_type_restrictions_ignored_with_wildcard` | 1 | pass | — |
| 334 | `consolidated_1_1_tests.yaml` | check | `wildcard_computed_userset` | 0 | pass | — |
| 335 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_computed_userset` | 0 | pass | — |
| 336 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_computed_userset` | 0 | pass | — |
| 337 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_computed_userset` | 0 | pass | — |
| 338 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_computed_userset` | 0 | pass | — |
| 339 | `consolidated_1_1_tests.yaml` | check | `check_with_invalid_tuple_in_store` | 0 | pass | — |
| 340 | `consolidated_1_1_tests.yaml` | list_objects | `check_with_invalid_tuple_in_store` | 0 | pass | — |
| 341 | `consolidated_1_1_tests.yaml` | list_users | `check_with_invalid_tuple_in_store` | 0 | pass | — |
| 342 | `consolidated_1_1_tests.yaml` | check | `check_with_invalid_tuple_in_store` | 1 | pass | — |
| 343 | `consolidated_1_1_tests.yaml` | list_objects | `check_with_invalid_tuple_in_store` | 1 | pass | — |
| 344 | `consolidated_1_1_tests.yaml` | list_users | `check_with_invalid_tuple_in_store` | 1 | pass | — |
| 345 | `consolidated_1_1_tests.yaml` | check | `this_with_contextual_tuples` | 0 | pass | — |
| 346 | `consolidated_1_1_tests.yaml` | list_objects | `this_with_contextual_tuples` | 0 | pass | — |
| 347 | `consolidated_1_1_tests.yaml` | list_users | `this_with_contextual_tuples` | 0 | pass | — |
| 348 | `consolidated_1_1_tests.yaml` | check | `wildcard_and_userset_restriction` | 0 | pass | — |
| 349 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_and_userset_restriction` | 0 | pass | — |
| 350 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_and_userset_restriction` | 0 | pass | — |
| 351 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_and_userset_restriction` | 0 | pass | — |
| 352 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_and_userset_restriction` | 0 | pass | — |
| 353 | `consolidated_1_1_tests.yaml` | check | `wildcard_obeys_the_types_in_stages` | 0 | pass | — |
| 354 | `consolidated_1_1_tests.yaml` | check | `wildcard_obeys_the_types_in_stages` | 0 | pass | — |
| 355 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_obeys_the_types_in_stages` | 0 | pass | — |
| 356 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_obeys_the_types_in_stages` | 0 | pass | — |
| 357 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_obeys_the_types_in_stages` | 0 | pass | — |
| 358 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_obeys_the_types_in_stages` | 0 | pass | — |
| 359 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_obeys_the_types_in_stages` | 0 | pass | — |
| 360 | `consolidated_1_1_tests.yaml` | check | `wildcard_obeys_the_types_in_stages` | 1 | pass | — |
| 361 | `consolidated_1_1_tests.yaml` | check | `wildcard_obeys_the_types_in_stages` | 1 | pass | — |
| 362 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_obeys_the_types_in_stages` | 1 | pass | — |
| 363 | `consolidated_1_1_tests.yaml` | list_objects | `wildcard_obeys_the_types_in_stages` | 1 | pass | — |
| 364 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_obeys_the_types_in_stages` | 1 | pass | — |
| 365 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_obeys_the_types_in_stages` | 1 | pass | — |
| 366 | `consolidated_1_1_tests.yaml` | list_users | `wildcard_obeys_the_types_in_stages` | 1 | pass | — |
| 367 | `consolidated_1_1_tests.yaml` | check | `validation_relation_not_in_model` | 0 | pass | — |
| 368 | `consolidated_1_1_tests.yaml` | list_objects | `validation_relation_not_in_model` | 0 | pass | — |
| 369 | `consolidated_1_1_tests.yaml` | list_users | `validation_relation_not_in_model` | 0 | pass | — |
| 370 | `consolidated_1_1_tests.yaml` | list_objects | `validation_type_not_in_model` | 0 | pass | — |
| 371 | `consolidated_1_1_tests.yaml` | list_users | `validation_type_not_in_model` | 0 | pass | — |
| 372 | `consolidated_1_1_tests.yaml` | check | `validation_user_type_not_in_model` | 0 | pass | — |
| 373 | `consolidated_1_1_tests.yaml` | list_objects | `validation_user_type_not_in_model` | 0 | pass | — |
| 374 | `consolidated_1_1_tests.yaml` | list_users | `validation_user_type_not_in_model` | 0 | pass | — |
| 375 | `consolidated_1_1_tests.yaml` | check | `validation_userset_type_not_in_model` | 0 | pass | — |
| 376 | `consolidated_1_1_tests.yaml` | list_objects | `validation_userset_type_not_in_model` | 0 | pass | — |
| 377 | `consolidated_1_1_tests.yaml` | list_users | `validation_userset_type_not_in_model` | 0 | pass | — |
| 378 | `consolidated_1_1_tests.yaml` | check | `validation_userset_relation_not_in_model` | 0 | pass | — |
| 379 | `consolidated_1_1_tests.yaml` | list_objects | `validation_userset_relation_not_in_model` | 0 | pass | — |
| 380 | `consolidated_1_1_tests.yaml` | list_users | `validation_userset_relation_not_in_model` | 0 | pass | — |
| 381 | `consolidated_1_1_tests.yaml` | check | `validation_user_invalid` | 0 | pass | — |
| 382 | `consolidated_1_1_tests.yaml` | list_objects | `validation_user_invalid` | 0 | pass | — |
| 383 | `consolidated_1_1_tests.yaml` | check | `validation_invalid_object_type_in_contextual_tuple` | 0 | pass | — |
| 384 | `consolidated_1_1_tests.yaml` | list_objects | `validation_invalid_object_type_in_contextual_tuple` | 0 | pass | — |
| 385 | `consolidated_1_1_tests.yaml` | list_users | `validation_invalid_object_type_in_contextual_tuple` | 0 | pass | — |
| 386 | `consolidated_1_1_tests.yaml` | check | `validation_invalid_relation_in_contextual_tuple` | 0 | pass | — |
| 387 | `consolidated_1_1_tests.yaml` | list_objects | `validation_invalid_relation_in_contextual_tuple` | 0 | pass | — |
| 388 | `consolidated_1_1_tests.yaml` | list_users | `validation_invalid_relation_in_contextual_tuple` | 0 | pass | — |
| 389 | `consolidated_1_1_tests.yaml` | check | `validation_invalid_user_in_contextual_tuple` | 0 | pass | — |
| 390 | `consolidated_1_1_tests.yaml` | list_objects | `validation_invalid_user_in_contextual_tuple` | 0 | pass | — |
| 391 | `consolidated_1_1_tests.yaml` | list_users | `validation_invalid_user_in_contextual_tuple` | 0 | pass | — |
| 392 | `consolidated_1_1_tests.yaml` | check | `validation_invalid_userset_in_contextual_tuple` | 0 | pass | — |
| 393 | `consolidated_1_1_tests.yaml` | list_objects | `validation_invalid_userset_in_contextual_tuple` | 0 | pass | — |
| 394 | `consolidated_1_1_tests.yaml` | list_users | `validation_invalid_userset_in_contextual_tuple` | 0 | pass | — |
| 395 | `consolidated_1_1_tests.yaml` | check | `validation_invalid_wildcard_in_contextual_tuple` | 0 | pass | — |
| 396 | `consolidated_1_1_tests.yaml` | list_objects | `validation_invalid_wildcard_in_contextual_tuple` | 0 | pass | — |
| 397 | `consolidated_1_1_tests.yaml` | list_users | `validation_invalid_wildcard_in_contextual_tuple` | 0 | pass | — |
| 398 | `consolidated_1_1_tests.yaml` | check | `val_contextual_tuples_and_wildcard_in_ttu_evaluation` | 0 | pass | — |
| 399 | `consolidated_1_1_tests.yaml` | list_objects | `val_contextual_tuples_and_wildcard_in_ttu_evaluation` | 0 | pass | — |
| 400 | `consolidated_1_1_tests.yaml` | list_users | `val_contextual_tuples_and_wildcard_in_ttu_evaluation` | 0 | pass | — |
| 401 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_considers_input_contextual_tuples` | 0 | pass | — |
| 402 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_considers_input_contextual_tuples` | 0 | pass | — |
| 403 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_considers_input_contextual_tuples` | 0 | pass | — |
| 404 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_considers_input_contextual_tuples` | 1 | pass | — |
| 405 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_considers_input_contextual_tuples` | 1 | pass | — |
| 406 | `consolidated_1_1_tests.yaml` | list_objects | `ignores_irrelevant_contextual_tuples_because_different_user` | 0 | pass | — |
| 407 | `consolidated_1_1_tests.yaml` | list_users | `ignores_irrelevant_contextual_tuples_because_different_user` | 0 | pass | — |
| 408 | `consolidated_1_1_tests.yaml` | list_objects | `ignores_irrelevant_contextual_tuples_because_different_user` | 1 | pass | — |
| 409 | `consolidated_1_1_tests.yaml` | list_objects | `ignores_irrelevant_contextual_tuples_because_different_type` | 0 | pass | — |
| 410 | `consolidated_1_1_tests.yaml` | list_users | `ignores_irrelevant_contextual_tuples_because_different_type` | 0 | pass | — |
| 411 | `consolidated_1_1_tests.yaml` | list_objects | `ignores_irrelevant_contextual_tuples_because_different_type` | 1 | pass | — |
| 412 | `consolidated_1_1_tests.yaml` | list_users | `ignores_irrelevant_contextual_tuples_because_different_type` | 1 | pass | — |
| 413 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_ignores_irrelevant_tuples_because_different_user` | 0 | pass | — |
| 414 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_ignores_irrelevant_tuples_because_different_user` | 0 | pass | — |
| 415 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_ignores_irrelevant_tuples_because_different_user` | 0 | pass | — |
| 416 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_ignores_irrelevant_tuples_because_different_user` | 1 | pass | — |
| 417 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_ignores_irrelevant_tuples_because_different_user` | 1 | pass | — |
| 418 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_ignores_duplicate_contextual_tuples` | 0 | pass | — |
| 419 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_ignores_duplicate_contextual_tuples` | 0 | pass | — |
| 420 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_ignores_duplicate_contextual_tuples` | 1 | pass | — |
| 421 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_ignores_duplicate_contextual_tuples` | 1 | pass | — |
| 422 | `consolidated_1_1_tests.yaml` | list_objects | `error_if_contextual_tuples_do_not_follow_type_restrictions` | 0 | pass | — |
| 423 | `consolidated_1_1_tests.yaml` | list_users | `error_if_contextual_tuples_do_not_follow_type_restrictions` | 0 | pass | — |
| 424 | `consolidated_1_1_tests.yaml` | list_objects | `error_if_contextual_tuples_do_not_follow_type_restrictions` | 1 | pass | — |
| 425 | `consolidated_1_1_tests.yaml` | list_users | `error_if_contextual_tuples_do_not_follow_type_restrictions` | 1 | pass | — |
| 426 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_error_if_unknown_type_in_request` | 0 | pass | — |
| 427 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_error_if_unknown_type_in_request` | 1 | pass | — |
| 428 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_error_if_unknown_relation_in_request` | 0 | pass | — |
| 429 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_error_if_unknown_relation_in_request` | 1 | pass | — |
| 430 | `consolidated_1_1_tests.yaml` | check | `relations_not_defined_in_some_child_type_falsy` | 0 | pass | — |
| 431 | `consolidated_1_1_tests.yaml` | list_objects | `relations_not_defined_in_some_child_type_falsy` | 0 | pass | — |
| 432 | `consolidated_1_1_tests.yaml` | list_users | `relations_not_defined_in_some_child_type_falsy` | 0 | pass | — |
| 433 | `consolidated_1_1_tests.yaml` | check | `ttu_some_parent_type_removed` | 0 | pass | — |
| 434 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_some_parent_type_removed` | 0 | pass | — |
| 435 | `consolidated_1_1_tests.yaml` | list_users | `ttu_some_parent_type_removed` | 0 | pass | — |
| 436 | `consolidated_1_1_tests.yaml` | check | `ttu_some_parent_type_removed` | 1 | pass | — |
| 437 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_some_parent_type_removed` | 1 | pass | — |
| 438 | `consolidated_1_1_tests.yaml` | list_users | `ttu_some_parent_type_removed` | 1 | pass | — |
| 439 | `consolidated_1_1_tests.yaml` | check | `relations_not_defined_in_some_child_type_truthy` | 0 | pass | — |
| 440 | `consolidated_1_1_tests.yaml` | list_objects | `relations_not_defined_in_some_child_type_truthy` | 0 | pass | — |
| 441 | `consolidated_1_1_tests.yaml` | list_users | `relations_not_defined_in_some_child_type_truthy` | 0 | pass | — |
| 442 | `consolidated_1_1_tests.yaml` | check | `same_relation_name_different_type` | 0 | pass | — |
| 443 | `consolidated_1_1_tests.yaml` | check | `same_relation_name_different_type` | 0 | pass | — |
| 444 | `consolidated_1_1_tests.yaml` | list_objects | `same_relation_name_different_type` | 0 | pass | — |
| 445 | `consolidated_1_1_tests.yaml` | list_users | `same_relation_name_different_type` | 0 | pass | — |
| 446 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref` | 0 | pass | — |
| 447 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref` | 0 | pass | — |
| 448 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref` | 0 | pass | — |
| 449 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref` | 0 | pass | — |
| 450 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref` | 0 | pass | — |
| 451 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref` | 0 | pass | — |
| 452 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref` | 0 | pass | — |
| 453 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref` | 0 | pass | — |
| 454 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref` | 0 | pass | — |
| 455 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 456 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 457 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 458 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 459 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 460 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 461 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 462 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 463 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_extra_indirection` | 0 | pass | — |
| 464 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation` | 0 | pass | — |
| 465 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation` | 0 | pass | — |
| 466 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation` | 0 | pass | — |
| 467 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation` | 0 | pass | — |
| 468 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation` | 0 | pass | — |
| 469 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation` | 0 | pass | — |
| 470 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation` | 0 | pass | — |
| 471 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation` | 0 | pass | — |
| 472 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation` | 0 | pass | — |
| 473 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation` | 0 | pass | — |
| 474 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation` | 0 | pass | — |
| 475 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation` | 0 | pass | — |
| 476 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation` | 0 | pass | — |
| 477 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation` | 0 | pass | — |
| 478 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation` | 0 | pass | — |
| 479 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_loop` | 0 | pass | — |
| 480 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_loop` | 0 | pass | — |
| 481 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_loop` | 0 | pass | — |
| 482 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_loop` | 0 | pass | — |
| 483 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_loop` | 0 | pass | — |
| 484 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_loop` | 0 | pass | — |
| 485 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation_loop` | 0 | pass | — |
| 486 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation_loop` | 0 | pass | — |
| 487 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation_loop` | 0 | pass | — |
| 488 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_loop` | 0 | pass | — |
| 489 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_loop` | 0 | pass | — |
| 490 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_loop` | 0 | pass | — |
| 491 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_loop` | 0 | pass | — |
| 492 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_loop` | 0 | pass | — |
| 493 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_loop` | 0 | pass | — |
| 494 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 495 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 496 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 497 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 498 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 499 | `consolidated_1_1_tests.yaml` | check | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 500 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 501 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 502 | `consolidated_1_1_tests.yaml` | list_objects | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 503 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 504 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 505 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 506 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 507 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 508 | `consolidated_1_1_tests.yaml` | list_users | `three_prong_relation_possible_exclusion` | 0 | pass | — |
| 509 | `consolidated_1_1_tests.yaml` | check | `computed_user_multi_route` | 0 | pass | — |
| 510 | `consolidated_1_1_tests.yaml` | check | `computed_user_multi_route` | 0 | pass | — |
| 511 | `consolidated_1_1_tests.yaml` | check | `computed_user_multi_route` | 0 | pass | — |
| 512 | `consolidated_1_1_tests.yaml` | check | `computed_user_multi_route` | 0 | pass | — |
| 513 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_multi_route` | 0 | pass | — |
| 514 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_multi_route` | 0 | pass | — |
| 515 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_multi_route` | 0 | pass | — |
| 516 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_multi_route` | 0 | pass | — |
| 517 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_multi_route` | 0 | pass | — |
| 518 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 519 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 520 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 521 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 522 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 523 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 524 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 525 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 526 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 527 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_same_rel_name` | 0 | pass | — |
| 528 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 529 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 530 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 531 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 532 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 533 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 534 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 535 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 536 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_wildcard` | 0 | pass | — |
| 537 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 538 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 539 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 540 | `consolidated_1_1_tests.yaml` | check | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 541 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 542 | `consolidated_1_1_tests.yaml` | list_objects | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 543 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 544 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 545 | `consolidated_1_1_tests.yaml` | list_users | `computed_user_indirect_ref_extra_indirection_wildcard` | 0 | pass | — |
| 546 | `consolidated_1_1_tests.yaml` | check | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 547 | `consolidated_1_1_tests.yaml` | check | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 548 | `consolidated_1_1_tests.yaml` | check | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 549 | `consolidated_1_1_tests.yaml` | check | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 550 | `consolidated_1_1_tests.yaml` | list_objects | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 551 | `consolidated_1_1_tests.yaml` | list_objects | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 552 | `consolidated_1_1_tests.yaml` | list_users | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 553 | `consolidated_1_1_tests.yaml` | list_users | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 554 | `consolidated_1_1_tests.yaml` | list_users | `two_level_computed_user_indirect_ref` | 0 | pass | — |
| 555 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_tupleset_types` | 0 | pass | — |
| 556 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_tupleset_types` | 0 | pass | — |
| 557 | `consolidated_1_1_tests.yaml` | check | `ttu_and_computed_ttu` | 0 | pass | — |
| 558 | `consolidated_1_1_tests.yaml` | check | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 559 | `consolidated_1_1_tests.yaml` | check | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 560 | `consolidated_1_1_tests.yaml` | check | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 561 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 562 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 563 | `consolidated_1_1_tests.yaml` | list_users | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 564 | `consolidated_1_1_tests.yaml` | list_users | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 565 | `consolidated_1_1_tests.yaml` | list_users | `ttu_and_computed_ttu_with_union` | 0 | pass | — |
| 566 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 567 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 568 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 569 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 570 | `consolidated_1_1_tests.yaml` | list_objects | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 571 | `consolidated_1_1_tests.yaml` | list_objects | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 572 | `consolidated_1_1_tests.yaml` | list_users | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 573 | `consolidated_1_1_tests.yaml` | list_users | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 574 | `consolidated_1_1_tests.yaml` | list_users | `simple_userset_child_wildcard_only` | 0 | pass | — |
| 575 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard` | 0 | pass | — |
| 576 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard` | 0 | pass | — |
| 577 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard` | 0 | pass | — |
| 578 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard` | 0 | pass | — |
| 579 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard` | 0 | pass | — |
| 580 | `consolidated_1_1_tests.yaml` | check | `simple_userset_child_wildcard` | 0 | pass | — |
| 581 | `consolidated_1_1_tests.yaml` | list_objects | `simple_userset_child_wildcard` | 0 | pass | — |
| 582 | `consolidated_1_1_tests.yaml` | list_objects | `simple_userset_child_wildcard` | 0 | pass | — |
| 583 | `consolidated_1_1_tests.yaml` | list_objects | `simple_userset_child_wildcard` | 0 | pass | — |
| 584 | `consolidated_1_1_tests.yaml` | list_users | `simple_userset_child_wildcard` | 0 | pass | — |
| 585 | `consolidated_1_1_tests.yaml` | list_users | `simple_userset_child_wildcard` | 0 | pass | — |
| 586 | `consolidated_1_1_tests.yaml` | list_users | `simple_userset_child_wildcard` | 0 | pass | — |
| 587 | `consolidated_1_1_tests.yaml` | list_users | `simple_userset_child_wildcard` | 0 | pass | — |
| 588 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 589 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 590 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 591 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 592 | `consolidated_1_1_tests.yaml` | list_objects | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 593 | `consolidated_1_1_tests.yaml` | list_objects | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 594 | `consolidated_1_1_tests.yaml` | list_users | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 595 | `consolidated_1_1_tests.yaml` | list_users | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 596 | `consolidated_1_1_tests.yaml` | list_users | `simple_ttu_child_wildcard_only` | 0 | pass | — |
| 597 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard` | 0 | pass | — |
| 598 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard` | 0 | pass | — |
| 599 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard` | 0 | pass | — |
| 600 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard` | 0 | pass | — |
| 601 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard` | 0 | pass | — |
| 602 | `consolidated_1_1_tests.yaml` | check | `simple_ttu_child_wildcard` | 0 | pass | — |
| 603 | `consolidated_1_1_tests.yaml` | list_objects | `simple_ttu_child_wildcard` | 0 | pass | — |
| 604 | `consolidated_1_1_tests.yaml` | list_objects | `simple_ttu_child_wildcard` | 0 | pass | — |
| 605 | `consolidated_1_1_tests.yaml` | list_objects | `simple_ttu_child_wildcard` | 0 | pass | — |
| 606 | `consolidated_1_1_tests.yaml` | list_users | `simple_ttu_child_wildcard` | 0 | pass | — |
| 607 | `consolidated_1_1_tests.yaml` | list_users | `simple_ttu_child_wildcard` | 0 | pass | — |
| 608 | `consolidated_1_1_tests.yaml` | list_users | `simple_ttu_child_wildcard` | 0 | pass | — |
| 609 | `consolidated_1_1_tests.yaml` | list_users | `simple_ttu_child_wildcard` | 0 | pass | — |
| 610 | `consolidated_1_1_tests.yaml` | check | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 611 | `consolidated_1_1_tests.yaml` | check | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 612 | `consolidated_1_1_tests.yaml` | check | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 613 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 614 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 615 | `consolidated_1_1_tests.yaml` | list_users | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 616 | `consolidated_1_1_tests.yaml` | list_users | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 617 | `consolidated_1_1_tests.yaml` | list_users | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 618 | `consolidated_1_1_tests.yaml` | list_users | `ttu_and_computed_ttu_wildcard` | 0 | pass | — |
| 619 | `consolidated_1_1_tests.yaml` | check | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 620 | `consolidated_1_1_tests.yaml` | check | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 621 | `consolidated_1_1_tests.yaml` | check | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 622 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 623 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 624 | `consolidated_1_1_tests.yaml` | list_users | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 625 | `consolidated_1_1_tests.yaml` | list_users | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 626 | `consolidated_1_1_tests.yaml` | list_users | `ttu_ttu_and_computed_ttu` | 0 | pass | — |
| 627 | `consolidated_1_1_tests.yaml` | check | `contextual_tuple_ref_relation_disjoint` | 0 | pass | — |
| 628 | `consolidated_1_1_tests.yaml` | check | `contextual_tuple_ref_relation_disjoint` | 0 | pass | — |
| 629 | `consolidated_1_1_tests.yaml` | list_objects | `contextual_tuple_ref_relation_disjoint` | 0 | pass | — |
| 630 | `consolidated_1_1_tests.yaml` | list_objects | `contextual_tuple_ref_relation_disjoint` | 0 | pass | — |
| 631 | `consolidated_1_1_tests.yaml` | list_users | `contextual_tuple_ref_relation_disjoint` | 0 | pass | — |
| 632 | `consolidated_1_1_tests.yaml` | list_users | `contextual_tuple_ref_relation_disjoint` | 0 | pass | — |
| 633 | `consolidated_1_1_tests.yaml` | check | `reverse_expand_relation_not_match` | 0 | pass | — |
| 634 | `consolidated_1_1_tests.yaml` | list_objects | `reverse_expand_relation_not_match` | 0 | pass | — |
| 635 | `consolidated_1_1_tests.yaml` | list_users | `reverse_expand_relation_not_match` | 0 | pass | — |
| 636 | `consolidated_1_1_tests.yaml` | list_users | `reverse_expand_relation_not_match` | 0 | pass | — |
| 637 | `consolidated_1_1_tests.yaml` | list_users | `reverse_expand_relation_not_match` | 0 | pass | — |
| 638 | `consolidated_1_1_tests.yaml` | check | `exclusion_for_some_relations` | 0 | pass | — |
| 639 | `consolidated_1_1_tests.yaml` | check | `exclusion_for_some_relations` | 0 | pass | — |
| 640 | `consolidated_1_1_tests.yaml` | check | `exclusion_for_some_relations` | 0 | pass | — |
| 641 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_for_some_relations` | 0 | pass | — |
| 642 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_for_some_relations` | 0 | pass | — |
| 643 | `consolidated_1_1_tests.yaml` | list_objects | `exclusion_for_some_relations` | 0 | pass | — |
| 644 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_for_some_relations` | 0 | pass | — |
| 645 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_for_some_relations` | 0 | pass | — |
| 646 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_for_some_relations` | 0 | pass | — |
| 647 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_for_some_relations` | 0 | pass | — |
| 648 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_for_some_relations` | 0 | pass | — |
| 649 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_for_some_relations` | 0 | pass | — |
| 650 | `consolidated_1_1_tests.yaml` | check | `evaluate_userset_in_computed_relation_of_ttu` | 0 | pass | — |
| 651 | `consolidated_1_1_tests.yaml` | list_objects | `evaluate_userset_in_computed_relation_of_ttu` | 0 | pass | — |
| 652 | `consolidated_1_1_tests.yaml` | list_users | `evaluate_userset_in_computed_relation_of_ttu` | 0 | pass | — |
| 653 | `consolidated_1_1_tests.yaml` | list_users | `evaluate_userset_in_computed_relation_of_ttu` | 0 | pass | — |
| 654 | `consolidated_1_1_tests.yaml` | list_users | `evaluate_userset_in_computed_relation_of_ttu` | 0 | pass | — |
| 655 | `consolidated_1_1_tests.yaml` | check | `nested_ttu_involving_intersection` | 0 | pass | — |
| 656 | `consolidated_1_1_tests.yaml` | check | `nested_ttu_involving_intersection` | 0 | pass | — |
| 657 | `consolidated_1_1_tests.yaml` | list_objects | `nested_ttu_involving_intersection` | 0 | pass | — |
| 658 | `consolidated_1_1_tests.yaml` | list_objects | `nested_ttu_involving_intersection` | 0 | pass | — |
| 659 | `consolidated_1_1_tests.yaml` | list_users | `nested_ttu_involving_intersection` | 0 | pass | — |
| 660 | `consolidated_1_1_tests.yaml` | list_users | `nested_ttu_involving_intersection` | 0 | pass | — |
| 661 | `consolidated_1_1_tests.yaml` | list_users | `nested_ttu_involving_intersection` | 0 | pass | — |
| 662 | `consolidated_1_1_tests.yaml` | list_users | `nested_ttu_involving_intersection` | 0 | pass | — |
| 663 | `consolidated_1_1_tests.yaml` | check | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 664 | `consolidated_1_1_tests.yaml` | check | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 665 | `consolidated_1_1_tests.yaml` | check | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 666 | `consolidated_1_1_tests.yaml` | check | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 667 | `consolidated_1_1_tests.yaml` | list_objects | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 668 | `consolidated_1_1_tests.yaml` | list_objects | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 669 | `consolidated_1_1_tests.yaml` | list_objects | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 670 | `consolidated_1_1_tests.yaml` | list_objects | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 671 | `consolidated_1_1_tests.yaml` | list_users | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 672 | `consolidated_1_1_tests.yaml` | list_users | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 673 | `consolidated_1_1_tests.yaml` | list_users | `nested_ttu_involving_exclusion` | 0 | pass | — |
| 674 | `consolidated_1_1_tests.yaml` | check | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 675 | `consolidated_1_1_tests.yaml` | check | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 676 | `consolidated_1_1_tests.yaml` | check | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 677 | `consolidated_1_1_tests.yaml` | check | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 678 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 679 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 680 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 681 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 682 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 683 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 684 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 685 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 686 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_intersection_in_computed_relation_of_ttu` | 0 | pass | — |
| 687 | `consolidated_1_1_tests.yaml` | check | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 688 | `consolidated_1_1_tests.yaml` | check | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 689 | `consolidated_1_1_tests.yaml` | check | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 690 | `consolidated_1_1_tests.yaml` | check | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 691 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 692 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 693 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 694 | `consolidated_1_1_tests.yaml` | list_objects | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 695 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 696 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 697 | `consolidated_1_1_tests.yaml` | list_users | `userset_with_exclusion_in_computed_relation_of_ttu` | 0 | pass | — |
| 698 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 699 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 700 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 701 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 702 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 703 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 704 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 705 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 706 | `consolidated_1_1_tests.yaml` | list_users | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 707 | `consolidated_1_1_tests.yaml` | list_users | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 708 | `consolidated_1_1_tests.yaml` | list_users | `relation_with_wildcard_involving_intersection` | 0 | pass | — |
| 709 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 710 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 711 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 712 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 713 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 714 | `consolidated_1_1_tests.yaml` | check | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 715 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 716 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 717 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 718 | `consolidated_1_1_tests.yaml` | list_objects | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 719 | `consolidated_1_1_tests.yaml` | list_users | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 720 | `consolidated_1_1_tests.yaml` | list_users | `relation_with_wildcard_involving_exclusion` | 0 | pass | — |
| 721 | `consolidated_1_1_tests.yaml` | check | `exclusion_under_wildcard_in_intersection` | 0 | pass | — |
| 722 | `consolidated_1_1_tests.yaml` | check | `exclusion_under_wildcard_in_intersection` | 0 | pass | — |
| 723 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_under_wildcard_in_intersection` | 0 | pass | — |
| 724 | `consolidated_1_1_tests.yaml` | check | `exclusion_under_wildcard_in_intersection_only_wildcard` | 0 | pass | — |
| 725 | `consolidated_1_1_tests.yaml` | check | `exclusion_under_wildcard_in_intersection_only_wildcard` | 0 | pass | — |
| 726 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_under_wildcard_in_intersection_only_wildcard` | 0 | pass | — |
| 727 | `consolidated_1_1_tests.yaml` | check | `exclusion_under_wildcard_in_three_operand_intersection` | 0 | pass | — |
| 728 | `consolidated_1_1_tests.yaml` | check | `exclusion_under_wildcard_in_three_operand_intersection` | 0 | pass | — |
| 729 | `consolidated_1_1_tests.yaml` | list_users | `exclusion_under_wildcard_in_three_operand_intersection` | 0 | pass | — |
| 730 | `consolidated_1_1_tests.yaml` | list_users | `relation_with_userset_involving_exclusion` | 0 | pass | — |
| 731 | `consolidated_1_1_tests.yaml` | list_users | `relation_with_userset_involving_exclusion` | 0 | pass | — |
| 732 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_does_not_return_duplicates` | 0 | pass | — |
| 733 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_does_not_return_duplicates` | 0 | pass | — |
| 734 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_does_not_return_duplicates` | 1 | pass | — |
| 735 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_does_not_return_duplicates` | 1 | pass | — |
| 736 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 0 | pass | — |
| 737 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 0 | pass | — |
| 738 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_expands_wildcard_tuple` | 0 | pass | — |
| 739 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 1 | pass | — |
| 740 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_expands_wildcard_tuple` | 1 | pass | — |
| 741 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 742 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 743 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 744 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 745 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 746 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 747 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 748 | `consolidated_1_1_tests.yaml` | check | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 749 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 750 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 751 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 752 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 753 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 754 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 755 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 756 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 757 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 758 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 759 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 760 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_expands_wildcard_tuple` | 2 | pass | — |
| 761 | `consolidated_1_1_tests.yaml` | check | `resolution_too_complex_throws_error` | 0 | pass | — |
| 762 | `consolidated_1_1_tests.yaml` | list_users | `resolution_too_complex_throws_error` | 0 | pass | — |
| 763 | `consolidated_1_1_tests.yaml` | check | `race_condition_same_user_same_object_diff_relation` | 0 | pass | — |
| 764 | `consolidated_1_1_tests.yaml` | check | `race_condition_same_user_same_object_diff_relation` | 0 | pass | — |
| 765 | `consolidated_1_1_tests.yaml` | list_objects | `race_condition_same_user_same_object_diff_relation` | 0 | pass | — |
| 766 | `consolidated_1_1_tests.yaml` | list_users | `race_condition_same_user_same_object_diff_relation` | 0 | pass | — |
| 767 | `consolidated_1_1_tests.yaml` | list_users | `race_condition_same_user_same_object_diff_relation` | 0 | pass | — |
| 768 | `consolidated_1_1_tests.yaml` | list_objects | `follows_correct_graph_edges` | 0 | pass | — |
| 769 | `consolidated_1_1_tests.yaml` | list_users | `follows_correct_graph_edges` | 0 | pass | — |
| 770 | `consolidated_1_1_tests.yaml` | list_users | `follows_correct_graph_edges` | 0 | pass | — |
| 771 | `consolidated_1_1_tests.yaml` | check | `list_objects_with_subcheck_encounters_cycle` | 0 | pass | — |
| 772 | `consolidated_1_1_tests.yaml` | list_objects | `list_objects_with_subcheck_encounters_cycle` | 0 | pass | — |
| 773 | `consolidated_1_1_tests.yaml` | list_users | `list_objects_with_subcheck_encounters_cycle` | 0 | pass | — |
| 774 | `consolidated_1_1_tests.yaml` | list_objects | `direct_relationships_with_intersection` | 0 | pass | — |
| 775 | `consolidated_1_1_tests.yaml` | list_users | `direct_relationships_with_intersection` | 0 | pass | — |
| 776 | `consolidated_1_1_tests.yaml` | list_users | `nested_usersets_are_recursively_expanded` | 0 | pass | — |
| 777 | `consolidated_1_1_tests.yaml` | check | `cycle_or_cycle_return_false` | 0 | pass | — |
| 778 | `consolidated_1_1_tests.yaml` | list_objects | `cycle_or_cycle_return_false` | 0 | pass | — |
| 779 | `consolidated_1_1_tests.yaml` | check | `immediate_cycle_through_computed_userset` | 0 | pass | — |
| 780 | `consolidated_1_1_tests.yaml` | list_objects | `immediate_cycle_through_computed_userset` | 0 | pass | — |
| 781 | `consolidated_1_1_tests.yaml` | check | `immediate_cycle_through_computed_userset` | 0 | pass | — |
| 782 | `consolidated_1_1_tests.yaml` | list_objects | `immediate_cycle_through_computed_userset` | 0 | pass | — |
| 783 | `consolidated_1_1_tests.yaml` | check | `true_butnot_cycle_return_false` | 0 | pass | — |
| 784 | `consolidated_1_1_tests.yaml` | list_objects | `true_butnot_cycle_return_false` | 0 | pass | — |
| 785 | `consolidated_1_1_tests.yaml` | check | `cycle_and_cycle_return_false` | 0 | pass | — |
| 786 | `consolidated_1_1_tests.yaml` | list_objects | `cycle_and_cycle_return_false` | 0 | pass | — |
| 787 | `consolidated_1_1_tests.yaml` | check | `cycle_and_true_return_false` | 0 | pass | — |
| 788 | `consolidated_1_1_tests.yaml` | list_objects | `cycle_and_true_return_false` | 0 | pass | — |
| 789 | `consolidated_1_1_tests.yaml` | check | `immediate_cycle_return_false` | 0 | pass | — |
| 790 | `consolidated_1_1_tests.yaml` | list_objects | `immediate_cycle_return_false` | 0 | pass | — |
| 791 | `consolidated_1_1_tests.yaml` | check | `cycle_butnot_false_return_false` | 0 | pass | — |
| 792 | `consolidated_1_1_tests.yaml` | list_objects | `cycle_butnot_false_return_false` | 0 | pass | — |
| 793 | `consolidated_1_1_tests.yaml` | check | `false_butnot_cycle_return_false` | 0 | pass | — |
| 794 | `consolidated_1_1_tests.yaml` | list_objects | `false_butnot_cycle_return_false` | 0 | pass | — |
| 795 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 796 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 797 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 798 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 799 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 800 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 801 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 802 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 803 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 804 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 805 | `consolidated_1_1_tests.yaml` | check | `ttu_mix_with_userset` | 0 | pass | — |
| 806 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_mix_with_userset` | 0 | pass | — |
| 807 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_mix_with_userset` | 0 | pass | — |
| 808 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_mix_with_userset` | 0 | pass | — |
| 809 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_mix_with_userset` | 0 | pass | — |
| 810 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_mix_with_userset` | 0 | pass | — |
| 811 | `consolidated_1_1_tests.yaml` | list_users | `ttu_mix_with_userset` | 0 | pass | — |
| 812 | `consolidated_1_1_tests.yaml` | list_users | `ttu_mix_with_userset` | 0 | pass | — |
| 813 | `consolidated_1_1_tests.yaml` | list_users | `ttu_mix_with_userset` | 0 | pass | — |
| 814 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 815 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 816 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 817 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 818 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 819 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 820 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 821 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 822 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 823 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 824 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 825 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 826 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 827 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 828 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 829 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 830 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 831 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 832 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 833 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 0 | pass | — |
| 834 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 0 | pass | — |
| 835 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 0 | pass | — |
| 836 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 0 | pass | — |
| 837 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 0 | pass | — |
| 838 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 0 | pass | — |
| 839 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 0 | pass | — |
| 840 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 0 | pass | — |
| 841 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 0 | pass | — |
| 842 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 0 | pass | — |
| 843 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 844 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 845 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 846 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 847 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 848 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 849 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 850 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 851 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 852 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 853 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 854 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 855 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 856 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 857 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 858 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 859 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 860 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 861 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 862 | `consolidated_1_1_tests.yaml` | check | `ttu_multiple_parents` | 1 | pass | — |
| 863 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 1 | pass | — |
| 864 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 1 | pass | — |
| 865 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 1 | pass | — |
| 866 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_multiple_parents` | 1 | pass | — |
| 867 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 1 | pass | — |
| 868 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 1 | pass | — |
| 869 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 1 | pass | — |
| 870 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 1 | pass | — |
| 871 | `consolidated_1_1_tests.yaml` | list_users | `ttu_multiple_parents` | 1 | pass | — |
| 872 | `consolidated_1_1_tests.yaml` | check | `userset_orphan_parent` | 0 | pass | — |
| 873 | `consolidated_1_1_tests.yaml` | check | `userset_orphan_parent` | 0 | pass | — |
| 874 | `consolidated_1_1_tests.yaml` | list_objects | `userset_orphan_parent` | 0 | pass | — |
| 875 | `consolidated_1_1_tests.yaml` | list_objects | `userset_orphan_parent` | 0 | pass | — |
| 876 | `consolidated_1_1_tests.yaml` | list_users | `userset_orphan_parent` | 0 | pass | — |
| 877 | `consolidated_1_1_tests.yaml` | check | `userset_orphan_parent` | 1 | pass | — |
| 878 | `consolidated_1_1_tests.yaml` | check | `userset_orphan_parent` | 1 | pass | — |
| 879 | `consolidated_1_1_tests.yaml` | list_objects | `userset_orphan_parent` | 1 | pass | — |
| 880 | `consolidated_1_1_tests.yaml` | list_objects | `userset_orphan_parent` | 1 | pass | — |
| 881 | `consolidated_1_1_tests.yaml` | list_users | `userset_orphan_parent` | 1 | pass | — |
| 882 | `consolidated_1_1_tests.yaml` | check | `ttu_remove_public_wildcard` | 0 | pass | — |
| 883 | `consolidated_1_1_tests.yaml` | check | `ttu_remove_public_wildcard` | 0 | pass | — |
| 884 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_remove_public_wildcard` | 0 | pass | — |
| 885 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_remove_public_wildcard` | 0 | pass | — |
| 886 | `consolidated_1_1_tests.yaml` | list_users | `ttu_remove_public_wildcard` | 0 | pass | — |
| 887 | `consolidated_1_1_tests.yaml` | check | `ttu_remove_public_wildcard` | 1 | pass | — |
| 888 | `consolidated_1_1_tests.yaml` | check | `ttu_remove_public_wildcard` | 1 | pass | — |
| 889 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_remove_public_wildcard` | 1 | pass | — |
| 890 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_remove_public_wildcard` | 1 | pass | — |
| 891 | `consolidated_1_1_tests.yaml` | list_users | `ttu_remove_public_wildcard` | 1 | pass | — |
| 892 | `consolidated_1_1_tests.yaml` | check | `ttu_orphan_public_wildcard_parent` | 1 | pass | — |
| 893 | `consolidated_1_1_tests.yaml` | check | `ttu_orphan_public_wildcard_parent` | 1 | pass | — |
| 894 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_orphan_public_wildcard_parent` | 1 | pass | — |
| 895 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_orphan_public_wildcard_parent` | 1 | pass | — |
| 896 | `consolidated_1_1_tests.yaml` | list_users | `ttu_orphan_public_wildcard_parent` | 1 | pass | — |
| 897 | `consolidated_1_1_tests.yaml` | check | `ttu_to_userset` | 0 | pass | — |
| 898 | `consolidated_1_1_tests.yaml` | check | `ttu_to_userset` | 0 | pass | — |
| 899 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_to_userset` | 0 | pass | — |
| 900 | `consolidated_1_1_tests.yaml` | list_users | `ttu_to_userset` | 0 | pass | — |
| 901 | `consolidated_1_1_tests.yaml` | check | `ttu_to_ttu` | 0 | pass | — |
| 902 | `consolidated_1_1_tests.yaml` | check | `ttu_to_ttu` | 0 | pass | — |
| 903 | `consolidated_1_1_tests.yaml` | list_objects | `ttu_to_ttu` | 0 | pass | — |
| 904 | `consolidated_1_1_tests.yaml` | list_users | `ttu_to_ttu` | 0 | pass | — |
| 905 | `consolidated_1_1_tests.yaml` | check | `userset_to_ttu` | 0 | pass | — |
| 906 | `consolidated_1_1_tests.yaml` | check | `userset_to_ttu` | 0 | pass | — |
| 907 | `consolidated_1_1_tests.yaml` | check | `userset_to_ttu` | 0 | pass | — |
| 908 | `consolidated_1_1_tests.yaml` | list_objects | `userset_to_ttu` | 0 | pass | — |
| 909 | `consolidated_1_1_tests.yaml` | list_objects | `userset_to_ttu` | 0 | pass | — |
| 910 | `consolidated_1_1_tests.yaml` | list_users | `userset_to_ttu` | 0 | pass | — |
| 911 | `consolidated_1_1_tests.yaml` | list_users | `userset_to_ttu` | 0 | pass | — |
| 912 | `consolidated_1_1_tests.yaml` | check | `userset_to_userset` | 0 | pass | — |
| 913 | `consolidated_1_1_tests.yaml` | check | `userset_to_userset` | 0 | pass | — |
| 914 | `consolidated_1_1_tests.yaml` | check | `userset_to_userset` | 0 | pass | — |
| 915 | `consolidated_1_1_tests.yaml` | list_objects | `userset_to_userset` | 0 | pass | — |
| 916 | `consolidated_1_1_tests.yaml` | list_users | `userset_to_userset` | 0 | pass | — |
| 917 | `consolidated_1_1_tests.yaml` | check | `ttu_discard_invalid` | 0 | pass | — |
| 918 | `consolidated_1_1_tests.yaml` | check | `ttu_discard_invalid` | 1 | pass | — |
| 919 | `consolidated_1_1_tests.yaml` | check | `userset_discard_invalid` | 0 | pass | — |
| 920 | `consolidated_1_1_tests.yaml` | check | `userset_discard_invalid` | 1 | pass | — |
| 921 | `consolidated_1_1_tests.yaml` | check | `userset_discard_invalid_wildcard` | 0 | pass | — |
| 922 | `consolidated_1_1_tests.yaml` | check | `userset_discard_invalid_wildcard` | 0 | pass | — |
| 923 | `consolidated_1_1_tests.yaml` | check | `userset_discard_invalid_wildcard` | 1 | pass | — |
| 924 | `consolidated_1_1_tests.yaml` | check | `userset_discard_invalid_wildcard` | 1 | pass | — |
| 925 | `consolidated_1_1_tests.yaml` | check | `recursive_ttu_union_algebraic_operations` | 0 | pass | — |
| 926 | `consolidated_1_1_tests.yaml` | check | `recursive_ttu_union_algebraic_operations_with_wildcard` | 0 | pass | — |
| 927 | `consolidated_1_1_tests.yaml` | check | `recursive_ttu_union_two_algebraic_operations` | 0 | pass | — |
| 928 | `consolidated_1_1_tests.yaml` | check | `recursive_ttu_union_terminal_type` | 0 | pass | — |
| 929 | `consolidated_1_1_tests.yaml` | check | `recursive_ttu_union_parenthesis_intersection` | 0 | pass | — |
| 930 | `consolidated_1_1_tests.yaml` | check | `combined_public_wildcard_userset` | 0 | pass | — |
| 931 | `consolidated_1_1_tests.yaml` | check | `weight_2_more_than_one_userset_assignable` | 0 | pass | — |
| 932 | `consolidated_1_1_tests.yaml` | check | `weight_infinite_more_than_one_userset_assignable` | 0 | pass | — |
| 933 | `consolidated_1_1_tests.yaml` | check | `weight_2_two_userset_assignable_diff_types` | 0 | pass | — |
| 934 | `abac_tests.yaml` | check | `direct_relation_with_condition` | 0 | pass | — |
| 935 | `abac_tests.yaml` | check | `direct_relation_with_condition` | 0 | pass | — |
| 936 | `abac_tests.yaml` | check | `direct_relation_with_condition` | 0 | pass | — |
| 937 | `abac_tests.yaml` | list_objects | `direct_relation_with_condition` | 0 | pass | — |
| 938 | `abac_tests.yaml` | list_objects | `direct_relation_with_condition` | 0 | pass | — |
| 939 | `abac_tests.yaml` | list_objects | `direct_relation_with_condition` | 0 | pass | — |
| 940 | `abac_tests.yaml` | list_users | `direct_relation_with_condition` | 0 | pass | — |
| 941 | `abac_tests.yaml` | list_users | `direct_relation_with_condition` | 0 | pass | — |
| 942 | `abac_tests.yaml` | list_users | `direct_relation_with_condition` | 0 | pass | — |
| 943 | `abac_tests.yaml` | check | `indirect_relation_with_condition` | 0 | pass | — |
| 944 | `abac_tests.yaml` | check | `indirect_relation_with_condition` | 0 | pass | — |
| 945 | `abac_tests.yaml` | check | `indirect_relation_with_condition` | 0 | pass | — |
| 946 | `abac_tests.yaml` | list_objects | `indirect_relation_with_condition` | 0 | pass | — |
| 947 | `abac_tests.yaml` | list_objects | `indirect_relation_with_condition` | 0 | pass | — |
| 948 | `abac_tests.yaml` | list_objects | `indirect_relation_with_condition` | 0 | pass | — |
| 949 | `abac_tests.yaml` | list_users | `indirect_relation_with_condition` | 0 | pass | — |
| 950 | `abac_tests.yaml` | list_users | `indirect_relation_with_condition` | 0 | pass | — |
| 951 | `abac_tests.yaml` | list_users | `indirect_relation_with_condition` | 0 | pass | — |
| 952 | `abac_tests.yaml` | list_users | `indirect_relation_with_condition` | 0 | pass | — |
| 953 | `abac_tests.yaml` | list_users | `indirect_relation_with_condition` | 0 | pass | — |
| 954 | `abac_tests.yaml` | check | `userset_child_with_condition` | 0 | pass | — |
| 955 | `abac_tests.yaml` | check | `userset_child_with_condition` | 0 | pass | — |
| 956 | `abac_tests.yaml` | check | `userset_child_with_condition` | 0 | pass | — |
| 957 | `abac_tests.yaml` | list_objects | `userset_child_with_condition` | 0 | pass | — |
| 958 | `abac_tests.yaml` | list_objects | `userset_child_with_condition` | 0 | pass | — |
| 959 | `abac_tests.yaml` | list_objects | `userset_child_with_condition` | 0 | pass | — |
| 960 | `abac_tests.yaml` | list_users | `userset_child_with_condition` | 0 | pass | — |
| 961 | `abac_tests.yaml` | list_users | `userset_child_with_condition` | 0 | pass | — |
| 962 | `abac_tests.yaml` | list_users | `userset_child_with_condition` | 0 | pass | — |
| 963 | `abac_tests.yaml` | list_users | `userset_child_with_condition` | 0 | pass | — |
| 964 | `abac_tests.yaml` | list_users | `userset_child_with_condition` | 0 | pass | — |
| 965 | `abac_tests.yaml` | check | `userset_parent_with_condition` | 0 | pass | — |
| 966 | `abac_tests.yaml` | check | `userset_parent_with_condition` | 0 | pass | — |
| 967 | `abac_tests.yaml` | check | `userset_parent_with_condition` | 0 | pass | — |
| 968 | `abac_tests.yaml` | list_objects | `userset_parent_with_condition` | 0 | pass | — |
| 969 | `abac_tests.yaml` | list_objects | `userset_parent_with_condition` | 0 | pass | — |
| 970 | `abac_tests.yaml` | list_objects | `userset_parent_with_condition` | 0 | pass | — |
| 971 | `abac_tests.yaml` | list_users | `userset_parent_with_condition` | 0 | pass | — |
| 972 | `abac_tests.yaml` | list_users | `userset_parent_with_condition` | 0 | pass | — |
| 973 | `abac_tests.yaml` | list_users | `userset_parent_with_condition` | 0 | pass | — |
| 974 | `abac_tests.yaml` | list_users | `userset_parent_with_condition` | 0 | pass | — |
| 975 | `abac_tests.yaml` | list_users | `userset_parent_with_condition` | 0 | pass | — |
| 976 | `abac_tests.yaml` | check | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 977 | `abac_tests.yaml` | check | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 978 | `abac_tests.yaml` | check | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 979 | `abac_tests.yaml` | list_objects | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 980 | `abac_tests.yaml` | list_objects | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 981 | `abac_tests.yaml` | list_objects | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 982 | `abac_tests.yaml` | list_users | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 983 | `abac_tests.yaml` | list_users | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 984 | `abac_tests.yaml` | list_users | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 985 | `abac_tests.yaml` | list_users | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 986 | `abac_tests.yaml` | list_users | `nested_indirect_relation_with_condition` | 0 | pass | — |
| 987 | `abac_tests.yaml` | check | `computed_userset_with_condition` | 0 | pass | — |
| 988 | `abac_tests.yaml` | check | `computed_userset_with_condition` | 0 | pass | — |
| 989 | `abac_tests.yaml` | check | `computed_userset_with_condition` | 0 | pass | — |
| 990 | `abac_tests.yaml` | list_objects | `computed_userset_with_condition` | 0 | pass | — |
| 991 | `abac_tests.yaml` | list_objects | `computed_userset_with_condition` | 0 | pass | — |
| 992 | `abac_tests.yaml` | list_objects | `computed_userset_with_condition` | 0 | pass | — |
| 993 | `abac_tests.yaml` | list_users | `computed_userset_with_condition` | 0 | pass | — |
| 994 | `abac_tests.yaml` | list_users | `computed_userset_with_condition` | 0 | pass | — |
| 995 | `abac_tests.yaml` | list_users | `computed_userset_with_condition` | 0 | pass | — |
| 996 | `abac_tests.yaml` | check | `tuple_to_userset_with_condition` | 0 | pass | — |
| 997 | `abac_tests.yaml` | check | `tuple_to_userset_with_condition` | 0 | pass | — |
| 998 | `abac_tests.yaml` | check | `tuple_to_userset_with_condition` | 0 | pass | — |
| 999 | `abac_tests.yaml` | list_objects | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1000 | `abac_tests.yaml` | list_objects | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1001 | `abac_tests.yaml` | list_objects | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1002 | `abac_tests.yaml` | list_users | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1003 | `abac_tests.yaml` | list_users | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1004 | `abac_tests.yaml` | list_users | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1005 | `abac_tests.yaml` | list_users | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1006 | `abac_tests.yaml` | list_users | `tuple_to_userset_with_condition` | 0 | pass | — |
| 1007 | `abac_tests.yaml` | check | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1008 | `abac_tests.yaml` | check | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1009 | `abac_tests.yaml` | list_objects | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1010 | `abac_tests.yaml` | list_objects | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1011 | `abac_tests.yaml` | list_objects | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1012 | `abac_tests.yaml` | list_users | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1013 | `abac_tests.yaml` | list_users | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1014 | `abac_tests.yaml` | list_users | `direct_relations_with_condition_through_intersection` | 0 | pass | — |
| 1015 | `abac_tests.yaml` | check | `simple_userset_with_condition` | 0 | pass | — |
| 1016 | `abac_tests.yaml` | check | `simple_userset_with_condition` | 0 | pass | — |
| 1017 | `abac_tests.yaml` | check | `simple_userset_with_condition` | 0 | pass | — |
| 1018 | `abac_tests.yaml` | check | `simple_userset_with_condition` | 0 | pass | — |
| 1019 | `abac_tests.yaml` | check | `simple_userset_with_condition` | 0 | pass | — |
| 1020 | `abac_tests.yaml` | list_objects | `simple_userset_with_condition` | 0 | pass | — |
| 1021 | `abac_tests.yaml` | list_objects | `simple_userset_with_condition` | 0 | pass | — |
| 1022 | `abac_tests.yaml` | list_objects | `simple_userset_with_condition` | 0 | pass | — |
| 1023 | `abac_tests.yaml` | list_objects | `simple_userset_with_condition` | 0 | pass | — |
| 1024 | `abac_tests.yaml` | list_objects | `simple_userset_with_condition` | 0 | pass | — |
| 1025 | `abac_tests.yaml` | list_users | `simple_userset_with_condition` | 0 | pass | — |
| 1026 | `abac_tests.yaml` | list_users | `simple_userset_with_condition` | 0 | pass | — |
| 1027 | `abac_tests.yaml` | list_users | `simple_userset_with_condition` | 0 | pass | — |
| 1028 | `abac_tests.yaml` | list_users | `simple_userset_with_condition` | 0 | pass | — |
| 1029 | `abac_tests.yaml` | list_users | `simple_userset_with_condition` | 0 | pass | — |
| 1030 | `abac_tests.yaml` | check | `simple_userset_with_condition_in_child` | 0 | pass | — |
| 1031 | `abac_tests.yaml` | check | `simple_userset_with_condition_in_child` | 0 | pass | — |
| 1032 | `abac_tests.yaml` | check | `simple_userset_with_condition_in_child` | 0 | pass | — |
| 1033 | `abac_tests.yaml` | list_users | `simple_userset_with_condition_in_child` | 0 | pass | — |
| 1034 | `abac_tests.yaml` | list_users | `simple_userset_with_condition_in_child` | 0 | pass | — |
| 1035 | `abac_tests.yaml` | list_users | `simple_userset_with_condition_in_child` | 0 | pass | — |
| 1036 | `abac_tests.yaml` | check | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1037 | `abac_tests.yaml` | check | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1038 | `abac_tests.yaml` | check | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1039 | `abac_tests.yaml` | check | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1040 | `abac_tests.yaml` | check | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1041 | `abac_tests.yaml` | check | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1042 | `abac_tests.yaml` | list_users | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1043 | `abac_tests.yaml` | list_users | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1044 | `abac_tests.yaml` | list_users | `simple_userset_with_and_without_condition_in_child` | 0 | pass | — |
| 1045 | `abac_tests.yaml` | check | `simple_ttu_with_condition` | 0 | pass | — |
| 1046 | `abac_tests.yaml` | check | `simple_ttu_with_condition` | 0 | pass | — |
| 1047 | `abac_tests.yaml` | check | `simple_ttu_with_condition` | 0 | pass | — |
| 1048 | `abac_tests.yaml` | list_users | `simple_ttu_with_condition` | 0 | pass | — |
| 1049 | `abac_tests.yaml` | list_users | `simple_ttu_with_condition` | 0 | pass | — |
| 1050 | `abac_tests.yaml` | list_users | `simple_ttu_with_condition` | 0 | pass | — |
| 1051 | `abac_tests.yaml` | check | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1052 | `abac_tests.yaml` | check | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1053 | `abac_tests.yaml` | check | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1054 | `abac_tests.yaml` | check | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1055 | `abac_tests.yaml` | list_objects | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1056 | `abac_tests.yaml` | list_objects | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1057 | `abac_tests.yaml` | list_objects | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1058 | `abac_tests.yaml` | list_objects | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1059 | `abac_tests.yaml` | list_users | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1060 | `abac_tests.yaml` | list_users | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1061 | `abac_tests.yaml` | list_users | `simple_ttu_with_and_without_condition` | 0 | pass | — |
| 1062 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1063 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1064 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1065 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1066 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1067 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1068 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1069 | `abac_tests.yaml` | check | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1070 | `abac_tests.yaml` | list_objects | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1071 | `abac_tests.yaml` | list_objects | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1072 | `abac_tests.yaml` | list_objects | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1073 | `abac_tests.yaml` | list_objects | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1074 | `abac_tests.yaml` | list_users | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1075 | `abac_tests.yaml` | list_users | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1076 | `abac_tests.yaml` | list_users | `simple_ttu_with_multiple_conditions` | 0 | pass | — |
| 1077 | `abac_tests.yaml` | check | `simple_ttu_with_condition_in_child` | 0 | pass | — |
| 1078 | `abac_tests.yaml` | check | `simple_ttu_with_condition_in_child` | 0 | pass | — |
| 1079 | `abac_tests.yaml` | check | `simple_ttu_with_condition_in_child` | 0 | pass | — |
| 1080 | `abac_tests.yaml` | list_users | `simple_ttu_with_condition_in_child` | 0 | pass | — |
| 1081 | `abac_tests.yaml` | list_users | `simple_ttu_with_condition_in_child` | 0 | pass | — |
| 1082 | `abac_tests.yaml` | list_users | `simple_ttu_with_condition_in_child` | 0 | pass | — |
| 1083 | `abac_tests.yaml` | check | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1084 | `abac_tests.yaml` | check | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1085 | `abac_tests.yaml` | check | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1086 | `abac_tests.yaml` | check | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1087 | `abac_tests.yaml` | check | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1088 | `abac_tests.yaml` | check | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1089 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1090 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1091 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1092 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1093 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1094 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1095 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1096 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1097 | `abac_tests.yaml` | list_users | `relation_through_ttu_with_condition` | 0 | pass | — |
| 1098 | `abac_tests.yaml` | check | `direct_relations_with_condition` | 0 | pass | — |
| 1099 | `abac_tests.yaml` | check | `direct_relations_with_condition` | 0 | pass | — |
| 1100 | `abac_tests.yaml` | check | `direct_relations_with_condition` | 0 | pass | — |
| 1101 | `abac_tests.yaml` | check | `direct_relations_with_condition` | 0 | pass | — |
| 1102 | `abac_tests.yaml` | check | `direct_relations_with_condition` | 0 | pass | — |
| 1103 | `abac_tests.yaml` | list_objects | `direct_relations_with_condition` | 0 | pass | — |
| 1104 | `abac_tests.yaml` | list_objects | `direct_relations_with_condition` | 0 | pass | — |
| 1105 | `abac_tests.yaml` | list_objects | `direct_relations_with_condition` | 0 | pass | — |
| 1106 | `abac_tests.yaml` | list_users | `direct_relations_with_condition` | 0 | pass | — |
| 1107 | `abac_tests.yaml` | list_users | `direct_relations_with_condition` | 0 | pass | — |
| 1108 | `abac_tests.yaml` | list_users | `direct_relations_with_condition` | 0 | pass | — |
| 1109 | `abac_tests.yaml` | list_users | `direct_relations_with_condition` | 0 | pass | — |
| 1110 | `abac_tests.yaml` | list_users | `direct_relations_with_condition` | 0 | pass | — |
| 1111 | `abac_tests.yaml` | list_users | `direct_relations_with_condition` | 0 | pass | — |
| 1112 | `abac_tests.yaml` | check | `prior_conditions_ignored` | 0 | pass | — |
| 1113 | `abac_tests.yaml` | list_objects | `prior_conditions_ignored` | 0 | pass | — |
| 1114 | `abac_tests.yaml` | list_users | `prior_conditions_ignored` | 0 | pass | — |
| 1115 | `abac_tests.yaml` | list_users | `prior_conditions_ignored` | 0 | pass | — |
| 1116 | `abac_tests.yaml` | check | `prior_conditions_ignored` | 1 | pass | — |
| 1117 | `abac_tests.yaml` | check | `prior_conditions_ignored` | 1 | pass | — |
| 1118 | `abac_tests.yaml` | list_objects | `prior_conditions_ignored` | 1 | pass | — |
| 1119 | `abac_tests.yaml` | list_objects | `prior_conditions_ignored` | 1 | pass | — |
| 1120 | `abac_tests.yaml` | list_users | `prior_conditions_ignored` | 1 | pass | — |
| 1121 | `abac_tests.yaml` | list_users | `prior_conditions_ignored` | 1 | pass | — |
| 1122 | `abac_tests.yaml` | check | `prior_conditions_ignored` | 2 | pass | — |
| 1123 | `abac_tests.yaml` | check | `prior_conditions_ignored` | 2 | pass | — |
| 1124 | `abac_tests.yaml` | list_objects | `prior_conditions_ignored` | 2 | pass | — |
| 1125 | `abac_tests.yaml` | list_objects | `prior_conditions_ignored` | 2 | pass | — |
| 1126 | `abac_tests.yaml` | list_users | `prior_conditions_ignored` | 2 | pass | — |
| 1127 | `abac_tests.yaml` | list_users | `prior_conditions_ignored` | 2 | pass | — |
| 1128 | `abac_tests.yaml` | check | `handles_floats` | 0 | pass | — |
| 1129 | `abac_tests.yaml` | check | `handles_floats` | 0 | pass | — |
| 1130 | `abac_tests.yaml` | check | `handles_floats` | 0 | pass | — |
| 1131 | `abac_tests.yaml` | check | `handles_floats` | 0 | pass | — |
| 1132 | `abac_tests.yaml` | check | `handles_floats` | 0 | pass | — |
| 1133 | `abac_tests.yaml` | check | `handles_floats` | 0 | pass | — |
| 1134 | `abac_tests.yaml` | list_objects | `handles_floats` | 0 | pass | — |
| 1135 | `abac_tests.yaml` | list_objects | `handles_floats` | 0 | pass | — |
| 1136 | `abac_tests.yaml` | list_objects | `handles_floats` | 0 | pass | — |
| 1137 | `abac_tests.yaml` | list_objects | `handles_floats` | 0 | pass | — |
| 1138 | `abac_tests.yaml` | list_objects | `handles_floats` | 0 | pass | — |
| 1139 | `abac_tests.yaml` | list_objects | `handles_floats` | 0 | pass | — |
| 1140 | `abac_tests.yaml` | list_users | `handles_floats` | 0 | pass | — |
| 1141 | `abac_tests.yaml` | list_users | `handles_floats` | 0 | pass | — |
| 1142 | `abac_tests.yaml` | list_users | `handles_floats` | 0 | pass | — |
| 1143 | `abac_tests.yaml` | list_users | `handles_floats` | 0 | pass | — |
| 1144 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1145 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1146 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1147 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1148 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1149 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1150 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1151 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1152 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1153 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1154 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1155 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1156 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1157 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1158 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1159 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1160 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1161 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1162 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1163 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1164 | `abac_tests.yaml` | list_users | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1165 | `abac_tests.yaml` | list_users | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1166 | `abac_tests.yaml` | list_users | `ttu_mix_with_userset_member_condition` | 0 | pass | — |
| 1167 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1168 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1169 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1170 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1171 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1172 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1173 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1174 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1175 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1176 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1177 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1178 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1179 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1180 | `abac_tests.yaml` | check | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1181 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1182 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1183 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1184 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1185 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1186 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1187 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1188 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1189 | `abac_tests.yaml` | list_objects | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1190 | `abac_tests.yaml` | list_users | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1191 | `abac_tests.yaml` | list_users | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1192 | `abac_tests.yaml` | list_users | `ttu_mix_with_userset_member_condition_mixed_parents` | 0 | pass | — |
| 1193 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1194 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1195 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1196 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1197 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1198 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1199 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1200 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1201 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1202 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1203 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1204 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1205 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1206 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1207 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1208 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1209 | `abac_tests.yaml` | check | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1210 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1211 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1212 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1213 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1214 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1215 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1216 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1217 | `abac_tests.yaml` | list_objects | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1218 | `abac_tests.yaml` | list_users | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1219 | `abac_tests.yaml` | list_users | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1220 | `abac_tests.yaml` | list_users | `ttu_mixed_parents_public_wildcard` | 0 | pass | — |
| 1221 | `abac_tests.yaml` | check | `wildcard_with_condition` | 0 | pass | — |
| 1222 | `abac_tests.yaml` | check | `wildcard_with_condition` | 1 | pass | — |
| 1223 | `abac_tests.yaml` | check | `wildcard_with_condition` | 1 | pass | — |
| 1224 | `abac_tests.yaml` | check | `wildcard_with_condition` | 1 | pass | — |
| 1225 | `abac_tests.yaml` | check | `condition_bound_to_correct_type_restriction_facet` | 0 | pass | — |
| 1226 | `abac_tests.yaml` | check | `condition_bound_to_correct_type_restriction_facet` | 0 | pass | — |
| 1227 | `abac_tests.yaml` | check | `condition_bound_to_correct_type_restriction_facet` | 0 | pass | — |
| 1228 | `abac_tests.yaml` | check | `condition_bound_to_correct_type_restriction_facet` | 0 | pass | — |
| 1229 | `abac_tests.yaml` | list_objects | `condition_bound_to_correct_type_restriction_facet` | 0 | pass | — |
| 1230 | `abac_tests.yaml` | list_objects | `condition_bound_to_correct_type_restriction_facet` | 0 | pass | — |
| 1231 | `abac_tests.yaml` | list_users | `condition_bound_to_correct_type_restriction_facet` | 0 | pass | — |
| 1232 | `abac_tests.yaml` | check | `condition_bound_to_correct_type_restriction_facet` | 1 | pass | — |
| 1233 | `abac_tests.yaml` | check | `condition_bound_to_correct_type_restriction_facet` | 1 | pass | — |
| 1234 | `abac_tests.yaml` | list_objects | `condition_bound_to_correct_type_restriction_facet` | 1 | pass | — |
| 1235 | `abac_tests.yaml` | list_users | `condition_bound_to_correct_type_restriction_facet` | 1 | pass | — |
| 1236 | `abac_tests.yaml` | check | `inline_expression_exclusion_subtract_missing_param` | 0 | pass | — |
| 1237 | `abac_tests.yaml` | check | `inline_expression_exclusion_subtract_missing_param` | 0 | pass | — |
| 1238 | `abac_tests.yaml` | check | `inline_expression_exclusion_subtract_missing_param` | 0 | pass | — |
| 1239 | `abac_tests.yaml` | check | `inline_expression_basic` | 0 | pass | — |
| 1240 | `abac_tests.yaml` | check | `inline_expression_basic` | 0 | pass | — |
| 1241 | `abac_tests.yaml` | check | `inline_expression_basic` | 0 | pass | — |
| 1242 | `abac_tests.yaml` | list_objects | `inline_expression_basic` | 0 | pass | — |
| 1243 | `abac_tests.yaml` | list_objects | `inline_expression_basic` | 0 | pass | — |
| 1244 | `abac_tests.yaml` | list_users | `inline_expression_basic` | 0 | pass | — |
| 1245 | `abac_tests.yaml` | list_users | `inline_expression_basic` | 0 | pass | — |
| 1246 | `abac_tests.yaml` | check | `inline_expression_inferred_string_param` | 0 | pass | — |
| 1247 | `abac_tests.yaml` | check | `inline_expression_inferred_string_param` | 0 | pass | — |
| 1248 | `abac_tests.yaml` | check | `inline_expression_alongside_named_condition` | 0 | pass | — |
| 1249 | `abac_tests.yaml` | check | `inline_expression_alongside_named_condition` | 0 | pass | — |
| 1250 | `abac_tests.yaml` | check | `inline_expression_alongside_named_condition` | 0 | pass | — |
| 1251 | `abac_tests.yaml` | check | `inline_expression_int_param` | 0 | pass | — |
| 1252 | `abac_tests.yaml` | check | `inline_expression_int_param` | 0 | pass | — |
| 1253 | `abac_tests.yaml` | check | `inline_expression_timestamp_param` | 0 | pass | — |
| 1254 | `abac_tests.yaml` | check | `inline_expression_timestamp_param` | 0 | pass | — |
| 1255 | `abac_tests.yaml` | check | `inline_expression_ipaddress_param` | 0 | pass | — |
| 1256 | `abac_tests.yaml` | check | `inline_expression_ipaddress_param` | 0 | pass | — |
| 1257 | `abac_tests.yaml` | check | `inline_expression_userset_subject` | 0 | pass | — |
| 1258 | `abac_tests.yaml` | check | `inline_expression_userset_subject` | 0 | pass | — |
| 1259 | `abac_tests.yaml` | list_objects | `inline_expression_userset_subject` | 0 | pass | — |
| 1260 | `abac_tests.yaml` | list_objects | `inline_expression_userset_subject` | 0 | pass | — |
| 1261 | `abac_tests.yaml` | check | `inline_expression_ttu` | 0 | pass | — |
| 1262 | `abac_tests.yaml` | check | `inline_expression_ttu` | 0 | pass | — |
| 1263 | `abac_tests.yaml` | list_users | `inline_expression_ttu` | 0 | pass | — |
| 1264 | `abac_tests.yaml` | list_users | `inline_expression_ttu` | 0 | pass | — |

## DSL <-> JSON transformer

`moon run cmd/language` replays every fixture in `.upstream/language/data/transformer` and compares both directions: DSL -> AuthorizationModel JSON (structural equality) and JSON -> internal model (model equality with the DSL parse). The pinned run passes 29/29 cases.

## Reproduce

```bash
scripts/fetch-upstream.sh     # once, pinned commits into .upstream/ (git-ignored)
./scripts/conformance.sh      # runs both matrices, writes conformance-results/, enforces 95/90
moon run cmd/language         # 29/29 transformer fixtures
```


## 同版本差分与定向回归

官方二进制固定为 [OpenFGA v1.22.1](https://github.com/openfga/openfga/releases/tag/v1.22.1)，
与矩阵使用相同 commit `44054f542f64e9b9589dd26a595081b3d2cfd942`。
macOS arm64 / Linux amd64 release 压缩包 SHA-256 固定在脚本中，解包前校验。
本次在 macOS arm64 执行；未取得 Linux/Windows 或 GitHub Actions 实机证据。

```bash
export PATH="$HOME/.moon/bin:$PATH"
./scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/seed314159
./scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/seed271828
moon build --target js --release playground
node scripts/test-explain.mjs
```

Python 标准库启动 memory datastore 的官方服务，绑定随机 loopback 端口；
结束（含异常）时终止自己启动的进程。每个用例使用独立 store。
建模或写入失败立即报错，不再把失败的初始化当作有效查询比较。

每个 seed 的 1000 组随机用例按五类各 200 组生成：
原有关系图；CEL 布尔值/除零错误及 union/intersection/存储与 contextual 分支；
Unicode code point 长度（含补充平面、组合字符、空串）；
timestamp 字符串（数值时区、负 epoch、纳秒）；深链、深浅混合及合法多对象循环。
另执行 95 组定向回归：原有 2 组 contextual 条件、
`examples/regressions/oracle.json` 中的 64 组、`examples/regressions/check-depth.json` 中的 29 组。
两轮会重复执行这 95 组固定回归，不把它们称为 190 类不同场景。

| API | seed 314159 一致/比较 | seed 271828 一致/比较 | 不一致 |
| --- | ---: | ---: | ---: |
| Check | 1095/1095 | 1095/1095 | 0 |
| ListObjects | 1095/1095 | 1095/1095 | 0 |
| ListUsers | 1095/1095 | 1095/1095 | 0 |

合计 6570 次比较，0 不一致。原始模型、元组、双方结果与 HTTP 错误分别位于每个输出目录的
cases.json、actual.json、expected.json、http-errors.json。提交的摘要为
[evidence/oracle-summary.json](evidence/oracle-summary.json)、
[evidence/oracle-seed271828-summary.json](evidence/oracle-seed271828-summary.json)，
[evidence/oracle-mismatches.json](evidence/oracle-mismatches.json) 为空数组。
64 组固定回归的官方期望另存 [evidence/fixed-regressions-expected.json](evidence/fixed-regressions-expected.json)。
它们全部嵌入 engine/upstream_regression_test.mbt，在三个后端运行，不依赖 /tmp 或文件系统。

### B1–B5 与 I1 的处理

- **B1**：CEL `&&` / `||` 在左侧错误时继续求值右侧，让 false 吸收 AND 错误、true 吸收
  OR 错误；决定性的左侧布尔值仍短路。两种运算各 3×3 的 true/false/error 组合均有
  CEL 单元测试和三个授权 API 的官方期望回归。
- **B2**：List 查询不在 union/intersection 的决定性结果处隐藏其余相关分支的条件错误；
  Check 保留原短路规则。固定回归覆盖分支顺序与持久化/contextual 混合。
- **B3 / ListObjects**：从请求用户沿反向依赖边传播证明，以工作队列去重，递归 group
  不受逐对象 Check 的栈深限制。直接/union 证明直接输出，仅 intersection/difference
  标记的候选走残余求值。这对应官方
  [ReverseExpand](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/pkg/server/commands/reverseexpand/reverse_expand.go)
  和 [NoFurtherEval / RequiresFurtherEval](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/pkg/server/commands/list_objects.go#L442)
  的分工，不再先枚举所有对象然后逐个 Check。
- **B3 / ListUsers**：按对象/关系展开用户集合，传播显式用户、wildcard、排除标记、错误及循环状态；
  relation 入口在 depth>=25 时报告 E2002，与 Check 的 tuple 深度不同。group:0..26 的数据链
  对 ListObjects 返回全体对象，ListUsers 在 25/26 层报错。固定回归另含深浅混合、循环及
  computed alias 的 0/25/26 边界。Check 的纯 computed alias 迭代折叠，不增加 tuple 深度，
  这是新增官方差分中发现的优化语义；完整 Check dispatch 的预算及终端 join 的差别见下方“TTU Check 的终点深度”。
  参考官方 [ListUsers.expand / rewrite handlers](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/pkg/server/commands/listusers/list_users_rpc.go#L352)。
- **B4**：全局 `size(s)` 与 `s.size()` 都计 Unicode code points；CEL 字符串词法器按字符宽度
  推进，避免补充平面字面量落在 UTF-16 surrogate 中间。
- **B5**：CEL 专用 timestamp→RFC3339 转换保留纳秒及数值时区偏移，去掉多余小数秒尾零。
  黑盒实测官方 `string(timestamp('2026-01-01T08:00:00+08:00'))` 保留 `+08:00`，
  并非强制改写为 UTC；比较/算术仍按 UTC instant 处理。新增精确时间值保留既有毫秒接口，
  条件 JSON 桥也输出 RFC3339。
- **I1 后端**：Explain 在同一次 Check 的成功分支记录 witness，删除二次独立 witness 遍历。
  CLI 与 JS API 共同使用 ExplainResult.to_json：allowed、paths（步骤数组）、complete 和可选
  explain_error。决策成功但 witness 不完整时 complete=false，状态非致命；不再编造路径。
  `scripts/test-explain.mjs` 实测 CLI 退出 0、JS ok=true，二者的 owner witness 与决策一致。

另一套独立编写的 16 组定向脚本也实际重放过，48 次查询比较无差异。但其中原 self-cycle 写入属于官方拒绝的
self-defining tuple，原脚本没有检查写入返回值；它不构成有效的官方循环遍历证明。
本轮固定 oracle 改用合法二节点循环，随机生成器也不生成 self-defining tuple。
原 self-cycle 的本地终止行为仍单独保留为测试。

### TTU Check 的终点深度

官方完整 ResolveCheck 请求从 depth=0 起算，dispatch 加 1，在 depth=25 时先报 E2002；
computed userset 不增加 dispatch 深度。递归 userset 与符合模型形状的 terminal join
可以不创建新的完整请求，不能用所有元组边数共用一个 > 或 >= 判定。
修复把完整请求预算与终端读取分开，并在 TTU dispatch 前跳过不存在 computed relation 的父类型。
语义依据和具体边界表见 [design.md](design.md#完整请求与终端连接的深度)，未复制官方 Go 实现。

29 个新增固定用例覆盖 TTU 24/25/26 层 DAG/cycle、直接 userset 25/26 层、
交替链、TTU→userset、userset→TTU、叶子 TTU join、有限 userset join，以及异构父类型。
它们在 engine/check_depth_test.mbt 对 Check/ListObjects/ListUsers 同时断言，
官方期望保存于 [evidence/depth-expected.json](evidence/depth-expected.json)。

定向差分脚本已收入仓库（64 组历史反例 + 140 组图遍历与深度用例）：

```bash
python3 scripts/oracle_directed.py "$PWD" "$PWD/conformance-results/directed"
```

实际结果：204 cases、612 comparisons、0 mismatches，原 190/191 用例的 Check 均为 E2002。
摘要见 [evidence/directed-summary.json](evidence/directed-summary.json)；
完整 cases/actual/expected/mismatches 写入 conformance-results/directed/（git 忽略）；
新增的 29 个深度用例也可直接用标准 oracle 重现。

### 验证与边界

三后端 `moon check --deny-warn`、`moon test`（当时各 177/177；0.1.1 起四后端各 183/183）、`moon fmt --check` 通过；
`moon info` 后无 .mbti 差异。矩阵保持 Check 516/516、ListObjects 354/354、
ListUsers 393/394（1 条缺期望跳过），language 29/29。native benchmark 2/2，
详见 [performance.md](performance.md)。

Web 端已同步：Playground 直接透传 `ExplainResult` JSON（`complete`、`explain_error`），
`node web/smoke.mjs` 36/36 通过；GitHub [CI](https://github.com/sundaysebasidian-byte/moonfga/actions/runs/41246946728) 与 [Pages](https://github.com/sundaysebasidian-byte/moonfga/actions/runs/41246946750) 已在远端通过（2026-11-01 核验）；线上静态资源与本地构建 SHA-256 一致，下载后的 bundle 36/36 冒烟检查通过。
固定两 seed 的零差异不等于全部 OpenFGA 输入均兼容；CEL 完整标准库等既有不支持项仍有效。

## Modular model fixtures (0.2.1)

Pinned language commit: `ed62a11e759a0faa1354404ead761f956469e149` (Apache-2.0).
`moon run cmd/language` includes all seven transformer-module directories and all nine fga-mod-transformer cases.
Single-file DSL ↔ JSON remains 29/29.

| Fixture | Result | Comparison boundary |
| --- | --- | --- |
| 00-simple-module | pass | Full JSON structural equality, including source_info |
| 01-module-with-errors | diagnostics pass | All 9 official diagnostics, including the 4 errorType entries ignored by the upstream transformer test |
| 02-module-with-extends | pass | Full JSON structural equality, including condition and extension metadata |
| 03-module-with-more-errors | diagnostics pass | All 9 official diagnostics and token ranges |
| 04-module-with-even-more-errors | diagnostics pass | All 4 diagnostics; distinguish no entrypoint from potential loop |
| 05-module-with-relation-errors | diagnostics pass | Both official diagnostics and token ranges |
| 06-complex-module | input unavailable | Pinned directory contains no module files; expected JSON metadata roundtrip passes, excluded from module-input denominator |

Totals: 2/2 full JSON transformations, 4/4 complete diagnostic comparisons (24/24 diagnostics), 1 missing-input fixture reported explicitly.
The nine fga.mod cases pass acceptance/rejection checks. Official YAML intermediate JSON locations remain outside this comparison. Module errors compare complete multisets (including multiplicity), independent of file traversal order: exact messages, zero-based start/end lines and columns, files, syntax type and metadata.errorType. Module names are independently derived from the fixture source because expected_errors.json omits that field. No diagnostic is filtered or exempted. Fixture 06 has no module source files at the pinned upstream commit; this is an upstream input limitation, not a successful module transformation.
Parse recovery resumes at the next top-level declaration; a lexical error stops parsing that file, while other files are still checked. This is a diagnostic recovery boundary for malformed inputs, not an exception to the exact fixture comparisons above.
`python3 scripts/test-modules.py` exercises native and JS validate/transform/store-test commands and rejects parent traversal, file symlink escape and directory symlink escape.

## Initial 0.2.3 CEL increment (superseded by Rework 1 below)

`python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/cel`
replays 52 fixed and 256 generated expressions through official Check/ListObjects/ListUsers:
308 cases, 924 comparisons, zero differences. Fixed expectations are also embedded in
`cel/compat_test.mbt`; malformed-escape tests are local parser tests. The expression corpus
uses request parameters for error values so official constant folding does not turn runtime
errors into model-creation failures. This gate does not test full static rejection equivalence.

`python3 scripts/audit_cel_surface.py` separately records unresolved surface probes, including
model-creation rejection. See [the full comparison](openfga-comparison.md) and
[evidence/cel-surface.json](evidence/cel-surface.json). This audit is not a passing gate:
At that increment, RE2, temporal methods, typed maps, reflection, partial activation and the checker were incomplete; the Rework 1 evidence below supersedes that inventory.
New evidence: [CEL summary](evidence/cel-summary.json),
[CEL mismatches](evidence/cel-mismatches.json),
[seed 314159](evidence/r2-seed314159-summary.json),
[seed 271828](evidence/r2-seed271828-summary.json).

## Rework 1

The new CEL oracle validates models before queries and distinguishes
`M:invalid_authorization_model` from evaluation `E2000` (and model request validation
from query errors). Both normal results and error categories are compared.
`cel/oracle_test.mbt` embeds the first seed's official outcomes, including typed and
nested parameter contexts. `scripts/generate_cel_regressions.py` regenerates that file.

Reproduction and complete results: [rework1-validation.md](evidence/rework1-validation.md).
The former 17 surface probes have been rechecked; a separate audit records
the unconfigured Local host difference; the former regex bound probe now matches. Those are not merged into a zero-
difference claim. Default-cost threshold probes, host-budget propagation, interruption
and a nonbacktracking stress case are also tested. Windows execution remains unverified;
shipped implementation and generated data have no new platform-specific dependency.

The default protobuf registry is also included: wrappers, timestamp/duration,
Empty, JSON well-known values, Struct.FieldsEntry and Any. The corpus includes
864 extreme timestamp predicates generated through public Go time APIs by
`scripts/export_protobuf_times.go`; the pinned OpenFGA binary, not Go alone, is the
acceptance oracle. String hex/octal escapes and bytes escapes cover every value
0..255 independently, including BOM retention and root-qualified names.
The retained browser smoke exercises all three built-in examples, new
protobuf/bytes/Unicode-regex Check/ListObjects/ListUsers and static model rejection.
