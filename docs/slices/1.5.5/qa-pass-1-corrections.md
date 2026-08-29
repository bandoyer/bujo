# Core notation and hierarchy: QA pass 1 corrections

Status: **CORRECTION SPECIFICATION, 2026-08-28.** Continue under the stable
`core-notation-hierarchy` task name.

Finding count: **1 of at most 2 routable findings**

Finding baseline: QA commit `2d7e1348b1`. The approved contract at
`docs/slices/1.5.5-core-notation-and-hierarchy-fidelity.md` remains binding.
This companion makes its malformed-graph, concurrency, documentation-owner,
and headless-Chrome gates exact. The approved contract wins any conflict
except for the bounded `ARCHITECTURE.md` ownership and timing correction
stated below; that correction changes no product or schema decision.

QA verification pass 1 is a finding, not a terminal candidate. Its complete
automated battery is green, but it reproduced one non-terminating supported
request, one leaked database timeout under a supported race, one missing
operator-owned architecture amendment, and material omissions from the
required browser acceptance flows.

## Specifier classification

The product decisions remain settled. Priority and inspiration are independent
and may coexist, `Add below…` ships in this slice, movement remains append-only,
and parent/child state never cascades.

The findings classify as follows:

1. **Delivered code and test defect:** a same-user two-row successor cycle
   makes `Entry#completable?` loop instead of treating the chain as malformed.
   The approved contract already says malformed endpoints block and refuse.
2. **Delivered code and test defect:** a supported child reopen racing master
   completion can leak `ActiveRecord::StatementTimeout`. The approved contract
   already requires supported races to serialize to an explainable outcome.
3. **Specification ownership defect, not a data-model change:** the approved
   contract assigned a root `ARCHITECTURE.md` edit to a pack whose role
   contracts cannot author that path. Repository history keeps that authority
   with the operator. The exact amendment remains mandatory before integration.
4. **Delivered acceptance-evidence defect:** the three new system tests cover
   only a fraction of ruled flows 1–13 and the required profile/state matrix.
   Green model/controller tests do not waive the explicit Chrome lane.

No new product choice is needed to close any finding.

## Acceptance criteria

The correction is complete only when all of these results hold together:

1. Every hierarchy or movement traversal used by completion or child capture
   terminates for acyclic graphs of arbitrary depth and for malformed cycles.
2. A repeated Entry identity in one traversal is malformed. It blocks or
   refuses the command without a write, disclosure, arbitrary depth cap, or
   request hang.
3. Supported completion, child lifecycle, and child-capture races finish with
   one of the exact serial outcomes below. No database lock exception reaches
   the caller.
4. The headless-Chrome suite traceably exercises every ruled flow 1–13 through
   real controls where they exist and through a browser-session crafted probe
   only where the contract deliberately renders no control.
5. Every rendered core state passes the exact four-profile phone matrix, and a
   representative deep state proves the remaining shipped hands and
   system-follow behavior.
6. The correction records the exact pending `ARCHITECTURE.md` line for the
   operator. No swarm role edits root planning or architecture authority.
7. All original security, residency, UUIDv7, append-only history, parser,
   signifier, no-cascade, and dormant-sync requirements remain unchanged.

## Malformed graph termination

Every graph walk introduced or exercised by this slice is total over malformed
persisted data. This includes:

- the kept descendant walk used by `completable?`, `completion_blocked?`, and
  `complete!`;
- the successor-endpoint walk for a moved task descendant; and
- the kept ancestor-visibility walk used to admit `Add below…`.

A traversal may visit an Entry once. Encountering that same Entry id again in
the same walk is a cycle and therefore a malformed relation. The command does
not infer that the repeated row is satisfied, skip it, or wait for recursion or
a request timeout. Deep acyclic trees and chains remain unbounded; an arbitrary
maximum depth or chain length is not an acceptable cycle guard.

For an otherwise current open master whose descendant graph or task movement
chain is cyclic:

```text
master.completable?          => false
master.completion_blocked?   => true
master.complete!             => raises Entry::LifecycleError
crafted Complete POST        => established refusal alert and safe return
```

For an otherwise current open parent whose kept ancestor path is cyclic:

```text
parent.child_capture_admitted?(as_of:) => false
Entry.capture_child!(...)              => raises Entry::LifecycleError
crafted Add-below POST                 => established refusal and safe return
```

Every refusal preserves byte-for-byte snapshots of the named row, reachable
rows, movement rows, timestamps, and dormant sync fields. Missing, tombstoned,
or foreign rows stay nondisclosing under the original response boundaries.

### Required malformed-graph probes

Use real Entry rows and the real test database. Raw writes may create shapes
that supported APIs correctly prevent, but the probe must run inside test
isolation and leave no durable corruption.

At minimum cover:

1. a task successor pointing to itself;
2. a two-task successor cycle `A -> B -> A` beneath a master;
3. a longer successor cycle reached only after a valid migrated prefix;
4. a two-row parent/child cycle reached by completion traversal; and
5. a two-row ancestor cycle offered as an Add-below route subject.

For each shape, assert the exact domain result above and unchanged row
snapshots. A focused test may hold a one-second outer timeout solely as a hang
detector; `Timeout::Error` is a failing test result, never the application's
refusal mechanism. The ordinary acyclic deep-tree and moved-endpoint examples
must still pass, proving the correction did not replace unbounded traversal
with a depth limit.

## Serializable command races

Concurrency is judged by observable command results, not by claiming a new raw
SQL graph constraint. Tests use separate database connections, deterministic
barriers around the disputed interleaving, bounded thread joins, and real Entry
commands. Sleeps, mocks of Entry graph behavior, and accepting a lock exception
as serialization evidence are forbidden.

Each competing operation returns success or the established
`Entry::LifecycleError` refusal. None may surface
`ActiveRecord::StatementTimeout`, `ActiveRecord::LockWaitTimeout`,
`SQLite3::BusyException`, a deadlock, a hung thread, or a partially applied
write.

### Resolve an open child while completing its master

Initial state: master `open`, child `open`, with no other blockers. Race
`master.complete!` against `child.complete!` or `child.strike!`.

Only these serial outcomes are allowed:

| Linearized order | Master | Child | Command results |
|---|---|---|---|
| master check first | `open` | settled | master refuses; child succeeds |
| child settles first | `done` | settled | both succeed |

The master never becomes done while the child remains open.

### Reopen a settled child while completing its master

Initial state: master `open`, child `done` or `struck`, with no other blockers.
Race `master.complete!` against `child.reopen!`.

Only these serial outcomes are allowed:

| Linearized order | Master | Child | Command results |
|---|---|---|---|
| master completes first | `done` | `open` | both succeed |
| child reopens first | `open` | `open` | reopen succeeds; master refuses |

The first outcome preserves the approved no-cascade rule: later child work does
not reopen a master automatically. Reopen is a supported child command and may
not be discarded merely because completion held another row lock.

### Add the first child while completing a leaf master

Initial state: current writable master `open`, with no children. Race
`master.complete!` against one valid `Entry.capture_child!` command.

Only these serial outcomes are allowed:

| Linearized order | Master | New child | Command results |
|---|---|---|---|
| completion first | `done` | none | completion succeeds; capture refuses |
| capture first | `open` | one open UUIDv7 child | capture succeeds; completion refuses |

`done` master plus a newly committed open child is not a serial outcome for
these overlapping commands. A successful child keeps the exact derived
owner, parent, residency, Collection, parser context, and capture order from
the approved contract. Neither outcome creates a successor or changes an
unrelated Entry.

Run each race enough times to exercise both deliberately forced orders rather
than relying on scheduler luck. Record which allowed outcome occurred. A test
that permits any final state as long as threads exit does not satisfy this
contract.

## `ARCHITECTURE.md` ownership correction

The approved product requirement is unchanged: inspiration is a separate
future snapshot field beside priority. The current root sketch still says:

```text
time_of_day · priority · tags · collection_id? (page_kind=collection only)
```

Before operator integration it must say:

```text
time_of_day · priority · inspiration · tags · collection_id? (page_kind=collection only)
```

However, root `ARCHITECTURE.md` is operator-owned in this repository. Every
installed `six-cg` artifact contract excludes that root path, while repository
history shows architecture decisions landing through the operator/planning
boundary. The original expected-file list was therefore not executable by any
pack role.

This companion corrects ownership and timing only:

- no swarm role edits `ARCHITECTURE.md`, `PLAN.md`, or `HANDOFF.md`;
- QA records the exact pending line above in its terminal receipt and does not
  fail the isolated implementation solely because the root sketch is pending;
- the operator applies and verifies the one-line sketch amendment after
  terminal review and before any approved integration commit; and
- active sync remains out of scope. The database field, propagation, and
  dormant `hlc`/`server_seq` behavior must already pass in the candidate.

Terminal QA remains terminal only for implementation. It cannot authorize or
perform this operator-owned documentation update, root integration, push, or
deployment.

## Headless-Chrome closure matrix

The authoritative slow lane must exercise the complete reader contract, not
only source assertions or direct model calls. Existing system coverage may be
extended and shared helpers may keep it readable, but the terminal commit body
must map each numbered flow below to one or more concrete system test names.
An unmentioned flow is missing evidence.

### Ruled flows 1–13

1. Capture an inspiration-only Note on Daily through the real form; assert
   `!`, Note glyph, exact words, NULL state, and settled focus.
2. Capture and Edit a combined-signifier Task through real controls; assert
   canonical `*!` ink and independent add/clear behavior without structural
   changes.
3. In Morning Reflection, Mark and Clear priority on an inspired task; assert
   inspiration, every other field, and list order survive both real gestures.
4. Move inspired entries through every existing allowed path and immediate
   Undo where offered. Cover ordinary Migrate, same-month Calendar Schedule,
   later-month Future Schedule, Move to Collection, all outgoing Monthly
   Migration destinations, both due-Future destinations, Strike resolutions,
   and each corresponding immediate Undo. Every created successor preserves
   inspiration and priority independently; predecessor ink/history remains.
5. With an open direct task child, show one tree, omit Complete, show the exact
   helper, and prove a stale/crafted Complete refuses unchanged.
6. Repeat with an open task grandchild below a Note. The task blocks and the
   Note itself does not.
7. Complete or strike all visible task endpoints through real controls; on the
   next render Complete replaces the helper and changes only the master.
8. Move a task child to another page. Its open live successor blocks the
   master; completing or striking that successor admits master completion
   without reparenting or copying.
9. Complete a ready master, then reopen a child through its real source page.
   The master remains done and no automatic cascade occurs.
10. On writable Daily, Monthly Calendar, Monthly Tasks, and Collection source
    pages, use Add below to create Task, Event, and Note children. The complete
    4-by-3 page/kind matrix preserves exact parent residency; at least one new
    Task creates another nested child to prove repeatable depth and focus.
11. Prove Add below absent on future Daily, both future Monthly pages, Future,
    Morning, Evening, and Monthly Migration, and on done, struck, moved,
    Event, Note, hidden-descendant, and unavailable-Collection subjects.
    Crafted submissions for those subjects refuse unchanged.
12. Exercise inspiration-only, combined, blocked, ready, Add-below open,
    invalid/refused, stale, deep-wrap, and unavailable-Collection rendered
    states through the phone/profile matrix below.
13. Probe forbidden ownership, placement, parent, history, state, deletion,
    timestamp, `hlc`, and `server_seq` claims plus missing, tombstoned, foreign,
    malformed, and stale subjects. Responses remain nondisclosing and no row
    changes. The malformed cycle probes from this companion are included in
    this traceability row even though their primary assertions are fast-lane.

For a control that is rendered, the system test must click/type/submit that
real control. Direct model or controller invocation is supplemental only. For
a crafted command whose control must not exist, a test may submit the request
through the signed-in browser session without injecting a production control;
it must then assert the actual response/redirect and durable database result.
That exception cannot replace a real gesture where the UI offers one.

Missing, foreign, and tombstoned Entry commands intentionally return the
landed bare nondisclosing 404 and therefore have no themed page geometry. Run
their browser-session probes under the profile cookies and assert byte/status
equivalence, but do not invent a themed error screen to satisfy the visual
matrix. An unavailable Collection keeps its established themed Collection 404
and remains subject to rendered phone checks.

### Exact profile coverage

Every rendered state named in flow 12 runs under all four profiles:

1. 390px light / Rock Salt;
2. 320px light / Architects Daughter;
3. 390px dark / Architects Daughter; and
4. 320px dark / Rock Salt.

For each state/profile combination assert, rather than infer from a screenshot:

- no horizontal document overflow or clipped `*!`, glyph, text, metadata,
  nesting, helper, action, or child form;
- stable first-line text origin with zero, one, and two signifiers;
- full deep-tree and long-text wrapping above the fixed tab bar;
- every visible control at least 44x44 CSS pixels;
- visible settled keyboard focus and truthful `aria-expanded`, `aria-pressed`,
  and accessible names; and
- the requested theme and hand resolving on representative Entry, form,
  action, helper, metadata, preference, and tab text.

One representative long `*!` tree with an open Add-below step additionally
runs under these profiles so all shipped hands and system-follow are covered:

| Width/theme | Hand |
|---|---|
| 390px, system following light OS | default Permanent Marker |
| 320px, explicit dark | Patrick Hand |
| 390px, explicit light | Gochi Hand |
| 320px, system following dark OS | Public Sans |

The two system-follow rows omit an explicit theme override and emulate the
named OS preference. Together with Rock Salt and Architects Daughter above,
the matrix covers every shipped hand without multiplying every behavioral
state by six. Screenshots may supplement these assertions but never replace
DOM, geometry, focus, accessibility, response, and persisted-row evidence.

## Test-first correction scope

Write the focused malformed-cycle and forced-race tests first and confirm they
reproduce QA's hang and leaked timeout before production correction. Browser
cases that already behave correctly are still required permanent acceptance
evidence; do not change production merely to make such a test red.

Expected implementation scope is limited to:

- `app/models/entry.rb` for terminating graph checks and serial command
  behavior;
- `app/controllers/entries_controller.rb` or the existing authorization
  concern only if the domain correction needs the established refusal mapping;
- existing shared Entry/action markup, Stimulus, and Entry component CSS only
  if a newly permanent browser assertion exposes a contradiction with the
  already approved visible behavior;
- focused model/controller/system tests, including existing Reflection,
  movement, Monthly Migration, and presentation files when they own a ruled
  flow; and
- this companion specification and downstream evidence receipts.

No schema or migration change is expected. Do not edit the approved contract,
mock, `ARCHITECTURE.md`, `PLAN.md`, `HANDOFF.md`, `docs/METHOD.md`, frozen
Tailwind T0 artifacts, old migrations, authentication/email, active sync, PWA,
deployment, production data, dependencies, or unrelated presentation.

Do not add a graph service/policy, background retry job, arbitrary depth cap,
database graph constraint claim, cascade, automatic parent reopen, subtree
movement, new route, new page, new copy, or client-side data model. A focused
private traversal or transaction helper may support the existing Entry domain
boundary; implementation remains the coder's decision.

## Required terminal evidence

The corrected candidate must pass the complete battery again:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
git diff --check
```

Every measured method remains at CRAP <= 6, duplication remains zero, and the
unchanged expanded RapidLog suite remains exactly 1167/1167 killed with zero
alive mutants. There are no skipped or pending acceptance cases.

Also record:

- focused malformed-graph results for every required shape;
- both forced orders and final states for all three race matrices;
- the flow-1-through-13 system-test traceability map;
- all four state profiles, all four additional hand/system profiles, and their
  geometry/accessibility results;
- byte-equivalent missing/foreign/tombstoned responses and unchanged-row
  snapshots; and
- the pending operator-owned `ARCHITECTURE.md` line exactly as ruled above.

Hand-mutation must at least prove the tests reject removing repeated-identity
detection, treating a repeated successor as satisfied, skipping the
post-lock/reload graph check, admitting `done` plus a racing new open child,
swallowing a child reopen after lock timeout, dropping one page/kind from the
Add-below matrix, dropping one movement/Undo path, or omitting one required
profile/hand. RapidLog mutation remains the tool-owned mutation gate.

QA's next review is verification pass 2 for `core-notation-hierarchy`. If it
finds another substantive defect, only one further route-back remains under
the pack bound. A passing broadcast is terminal only for the isolated
implementation candidate; operator review, the exact architecture amendment,
explicit integration approval, push, and deployment remain separate gates.
