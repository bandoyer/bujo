---
name: testing
description: This project's test lanes, idioms, and quality bars. Use BEFORE writing or modifying any test. Triggers - new test, unit test, system test, fixtures, mocking, coverage, mutation, mutant, crap4rb, flaky test, test ordering, "how do I test".
---

# Testing in bujo

Minitest as Rails ships it. Two lanes, never mixed:

| Lane | Command | Contents |
|---|---|---|
| fast | `bin/rails test` | models, lib, controllers — no browser, runs on every handoff |
| slow | `bin/rails test:system` | headless-Chrome acceptance flows (`test/system/`) |

Herdr swarm roles run in a CLI environment without Codex Desktop's in-app
Browser backend. They must not attempt that backend or report its absence as
a QA limitation. The slow lane above is the project's authoritative browser
acceptance surface. QA supplements it, when needed, with headless screenshots,
DOM/geometry/accessibility checks, and direct request or domain probes.

## Idioms

- **Fixtures over factories**; real objects against the real test
  database. Doubles only at true external edges (network, clock);
  Mocha if unavoidable — nothing in the app currently needs a double.
- Plain assertions; `assert_uuid_v7` (test_helper) for minted ids.
- Never depend on insertion order without an explicit order — the
  scopes' `id` tiebreaker exists because `created_at` ties are real.
  Tests must not scan machine-global state (tmp dirs, the clock);
  pass dates explicitly (`today:` args, fixed `Date.new(...)`).
- Parser tests are table-driven from the spec's ruled rows; model
  tests mirror `docs/slices/1.2-entries-and-collections.md`'s ruled
  scenarios.

## Quality bars (all must pass before merge)

```sh
bin/rails test
bin/rubocop                     # omakase + rubocop-minitest
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/   # every method <= 6
jscpd --min-tokens 50 --reporters console app/ lib/
bin/rails test:system
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'         # 0 alive
```

## Mutation testing rules (hard-won)

- Scope stays `Bujo::RapidLog*` — ActiveRecord models are hostile
  mutation subjects; do not widen `.mutant.yml`.
- Every fast-lane test class declares `cover "Bujo::RapidLog*"` —
  except tests that read source from disk rather than exercising the
  loaded constant (e.g. the boundary test), which declare none.
- **Test classes live OUTSIDE the `Bujo::RapidLog` namespace** or
  mutant mutates the tests themselves.
- `lib/bujo/` must stay Ruby-3.3-parseable (mutant's parser lags the
  runtime); a mutation run that cannot read a subject is a blocking
  finding.
- COVERAGE runs are single-process (`parallelize` respects the env
  var) so the lcov report is whole — regenerate before any
  coverage-derived metric (crap4rb reads it).
