# 1.5.2c — Command-by-residency authorization

Task name: `collection-commands`

Derived from the operator-approved `docs/slices/1.5.2-custom-collections-and-index.md`.
That document is the authority; this one only chooses the order in which its
fixed behavior lands. Where the two disagree, the accepted spec wins.
`docs/METHOD.md`, `PLAN.md`, and `ARCHITECTURE.md` bind ahead of both, in that
order. Approved ruling 5 — a Collection resident gets Complete, Strike, and
Reopen and nothing else — is fixed and may not be reopened.

Builds on `collection-pages`, which shipped the Collection screen with its
residents rendered as plain lines. This slice gives those residents their
lifecycle, and it is the one place in 1.5.2 that changes a guard every page in
the app already depends on. That is why it is its own slice.

## The problem with the current guard

`EntriesController::ACTION_PAGE_KINDS` admits a command by page alone. Two
things break if `collection` is simply appended to it:

- `migrate` derives its destination from `@entry.page_on.next_month`, and a
  Collection resident's `page_on` is correctly NULL — the action body would
  raise on `nil`;
- the product rule is no longer page-wide. Collection admits three of the five
  commands and refuses two, which a single page allowlist cannot express.

So the page-wide allowlist is **replaced**, not extended.

## In scope

`app/controllers/`, `app/views/`, `app/javascript/`,
`app/assets/stylesheets/`, and `test/`.

The accepted spec's file scope governs and is not widened here: one migration
plus `db/schema.rb`, `app/models/`, `app/controllers/`, `app/views/`,
`app/assets/stylesheets/`, `app/javascript/`, `config/routes.rb`, and `test/`.
`app/helpers/` is not on that list, so a predicate a view needs is exposed from
a controller or concern with `helper_method`, as `FutureLogTargets` already
does.

## Out of scope — arriving later in 1.5.2

- The Move to Collection… command itself — `move-to-collection`. This slice
  ships the policy for the five commands that exist today and must leave it
  **open to a sixth by adding a row, never by branching inside an existing
  method**. That is the acceptance test of the design.
- Every 1.5.2 non-goal, unchanged: no Future-resident controls, no outbound
  Collection movement, no entry editing or deleting, no `lib/`, `Gemfile`, or
  `PLAN.md` edits.

## The residency policy

One command-by-persisted-residency policy that every entry member command
crosses before its action body runs. It is keyed by the command and by the
entry's **persisted** `page_kind`. Request parameters never choose permission
and never choose a destination.

| Entry command | Daily | Monthly Calendar | Monthly Tasks | Future | Collection |
|---|---:|---:|---:|---:|---:|
| Complete | allow | allow | allow | refuse | allow |
| Reopen | allow | allow | allow | refuse | allow |
| Strike | allow | allow | allow | refuse | allow |
| Migrate to next Monthly Tasks | allow | allow | allow | refuse | refuse |
| Schedule to Future | allow | allow | allow | refuse | refuse |

Rules the policy must satisfy:

- It covers every member command by construction, the way the current
  `before_action … except: :create` does, so a command added later arrives
  gated rather than silently reachable. A command absent from the policy is
  refused, never allowed by default.
- It is **only** the residency gate. `Entry` remains the sole authority for
  kind, state, successor, structural destination, and Future-date validity. The
  policy never inspects state and the model never inspects page permission.
- A refused command produces the existing `REFUSAL_ALERT` and reaches the
  reader exactly as a lifecycle refusal does today.
- `migrate` must never evaluate `page_on.next_month` on a Collection or Future
  resident: the policy refuses before the action body is entered, so no `nil`
  is ever dereferenced.

## Entry lookup

`set_entry` scopes to the signed-in user's **kept** entries. A foreign,
missing, or soft-deleted entry is not a lifecycle refusal: the response is
HTTP 404, no row is written, and no id, Topic, or entry text is disclosed. A
Collection-resident command whose resident Collection is foreign, missing, or
soft-deleted renders the same themed missing state `collection-pages` shipped.

This tightens today's behavior: `user_entries` is not kept-scoped, so a
soft-deleted entry is currently commandable. It must not be.

## Where a Collection command returns

Success and every post-lookup refusal on a Collection resident return to that
resident's canonical kept Collection page, derived from the entry's persisted
same-user `collection_id`. Crafted `viewed_on`, `return_to`, `placement`,
Collection id, or Topic parameters cannot redirect the reader to a different
page or a different tenant. Daily and Monthly command returns keep their
established param-driven destinations exactly as they are today.

A refusal leaves the entry's state unchanged, creates no successor, and writes
no other row.

## The Collection rendering and command matrix

The view renders a control only where **both** the residency policy and the
entry lifecycle allow it. No controller ever infers permission from a rendered
control.

| Persisted Collection resident | Controls rendered | Crafted commands refused |
|---|---|---|
| open task | Complete, Strike | Reopen, Migrate, Schedule |
| done task | Reopen | Complete, Strike, Migrate, Schedule |
| struck task | Reopen | Complete, Strike, Migrate, Schedule |
| migrated task | none | all five |
| event, with or without successor | none | all five |
| note, with or without successor | none | all five |

A Collection resident with no permitted control renders as a plain line, not as
a toggle controlling an empty strip.

## The collapsed strip becomes command-aware

The action strip currently decides what to show from kind and state alone. It
must now also respect the residency policy, and it must keep every existing
Daily and Monthly control exactly as it is:

| resident | today | after this slice |
|---|---|---|
| Daily open task | Complete, Strike, Migrate, Schedule… | unchanged |
| Daily done or struck task | Reopen | unchanged |
| Daily event without successor | Schedule… | unchanged |
| Monthly open task | Complete, Strike, Migrate, Schedule… | unchanged |
| Collection open task | none | Complete, Strike |
| Collection done or struck task | none | Reopen |
| Collection event or note | none | none |
| Future resident, any kind | none | none |

The Schedule two-step reveal belongs only to rows that may actually schedule,
so a Collection row never renders a hidden date step.

## Ruled browser flow for this slice

This is the accepted spec's flow 5.

> A Collection open task completes and strikes; done and struck tasks reopen.
> The page retains the reader after successes and after lifecycle refusals.
> Collection Migrate and Schedule controls are absent, and crafted requests
> leave state and successor unchanged.

Existing Today, Month, Future, capture, lifecycle, and tab flows stay green.

## Required tests

Fixtures and real rows; fixed dates or `travel_to`; no doubles for Rails, the
clock, or Active Record.

- **Derive the command list from the routes**, not from a literal, and assert
  it equals the five commands that exist. That assertion is the tripwire that
  fails when `move-to-collection` adds the sixth without a policy row.
- Pin **every command against every one of the five page kinds** — all twenty-
  five cells of the matrix. Positive cells must be genuine successes, so a
  refuse-everything implementation fails; negative cells reload exact
  attributes and assert no successor and no unrelated write.
- Each `schedule` negative cell posts a legal Future date, so a missing-date
  refusal can never masquerade as the residency guard. Each `migrate` negative
  cell on a Collection or Future resident additionally proves no `nil`
  dereference occurred.
- Every row of the Collection rendering matrix: which controls appear in the
  rendered page, and that each absent control's command is refused when
  crafted.
- Collection command success and refusal both land on the resident's canonical
  Collection page; crafted `viewed_on`, `return_to`, `placement`, Collection
  id, and Topic parameters change neither the destination nor the tenant.
- Daily and Monthly returns are unchanged; every existing entry-command test
  stays green as written.
- A foreign entry, a nonexistent entry id, and a soft-deleted entry each
  return 404 with no write, for every command.
- A Collection resident whose Collection is soft-deleted or foreign returns the
  themed missing state with no write, for every command.
- Every existing 1.5.1a Future crafted-request assertion is retained unchanged.

**Deliberately superseded.** Two expectations move, and only these two:

1. `collection-pages` asserted that a Collection page renders no entry action
   strip. It now asserts the matrix above.
2. The 1.5.1a assertion that all five commands refuse a Collection resident now
   asserts the matrix: Complete, Strike, and Reopen succeed there; Migrate and
   Schedule are refused. The Future half of that assertion is unchanged.

Say so in the commit body. Nothing else in the suite may be weakened, and no
test may be deleted to reach green.

System lane covers flow 5, asserting the absent controls **and the server
refusal behind each**, the return destination after success and after refusal,
44 px targets, and truthful `aria-expanded` state on a Collection row.

It also carries this slice's share of the accepted spec's flow 10: the **open
Collection action strip** is inspected at phone width in both themes and at
two hand settings, with no horizontal scrolling and no collision with the
fixed tab bar. `collection-pages` covered the Index and Collection screens
themselves; `move-to-collection` covers its own two-step reveal.

## Invariants this slice must not disturb

UUIDv7 ids; tenant scoping on every query; append-only movement; soft deletion
without cascades; immutable entry placement; the unique successor chain; and
dormant `hlc`/`server_seq`, which this slice never writes.

## Quality bars

- `bin/rails test` and `bin/rails test:system` green, run in this worktree.
- `bin/rubocop` clean.
- `COVERAGE=1 bin/rails test` then
  `crap4rb --lcov coverage/lcov.info app/ lib/` — every measured method
  CRAP ≤ 6.
- `jscpd --min-tokens 50 --reporters console app/ lib/` — zero clones.
- `lib/` untouched, so `Bujo::RapidLog*` mutation remains exactly 1105/1105.

Hand-mutate at least these and show each is killed by an assertion that
explains the product failure, not by an incidental exception:

- allow Migrate or Schedule on a Collection resident;
- refuse Complete, Strike, or Reopen on a Collection resident;
- allow any command on a Future resident;
- key the policy off a request parameter instead of the persisted `page_kind`;
- drop a command from the policy and let the default be allow;
- drop `kept` from the entry lookup;
- derive a Collection command's return page from `params` instead of from the
  entry's persisted `collection_id`;
- render a Collection control the policy refuses.

## Handoff

Commit, `git_handoff` to `coder`, task `collection-commands`, priority `50`.
