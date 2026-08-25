# 1.5.2d — Move to Collection…

Task name: `move-to-collection`

Derived from the operator-approved `docs/slices/1.5.2-custom-collections-and-index.md`.
That document is the authority; this one only chooses the order in which its
fixed behavior lands. Where the two disagree, the accepted spec wins.
`docs/METHOD.md`, `PLAN.md`, and `ARCHITECTURE.md` bind ahead of both, in that
order. Approved ruling 3 — this gesture ships now, carries the same exact-Topic
friction as Open by Topic, and is the primitive 1.5.3 will reuse rather than
replace — is fixed and may not be reopened.

Builds on `collection-domain` (exact-Topic scope, append-only `Entry#move_to!`),
`collection-pages` (Collection screens), and `collection-commands` (the
residency policy). This is the last slice of 1.5.2.

`docs/METHOD.md` already promises a Custom Collection as the natural non-daily
destination for a Daily note, and the monthly ritual reviews unresolved tasks
rather than notes. Without this gesture a writable Collection page would exist
with no deliberate way to move anything into it.

## In scope

`config/routes.rb`, `app/controllers/`, `app/views/`, `app/javascript/`, `app/assets/stylesheets/`, and `test/`.

The accepted spec's file scope governs and is not widened here: one migration
plus `db/schema.rb`, `app/models/`, `app/controllers/`, `app/views/`,
`app/assets/stylesheets/`, `app/javascript/`, `config/routes.rb`, and `test/`.
`app/helpers/` is not on that list, so a predicate a view needs is exposed from
a controller or concern with `helper_method`, as `FutureLogTargets` already
does.

## Out of scope

- Outbound movement **from** a Collection, and Collection-to-Collection
  movement. Neither exists in 1.5.2.
- Future-resident controls; Future residents remain read-only until 1.5.3.
- The guided monthly task review that will reuse this gesture — 1.5.3.
- Every 1.5.2 non-goal, unchanged: no all-Collections picker, no suggestions,
  no autocomplete, no fuzzy or prefix match, no bulk movement, no implicit
  Collection creation from an entry, no automatic registration of a
  destination, no `lib/`, `Gemfile`, or `PLAN.md` edits.

## The command

One new `Entry` member command, `POST /entries/:id/move_to_collection`, added
to the existing `EntriesController`.

It gains one row in the residency policy `collection-commands` shipped —
**a row, not a branch**:

| Entry command | Daily | Monthly Calendar | Monthly Tasks | Future | Collection |
|---|---:|---:|---:|---:|---:|
| Move to Collection | allow | allow | allow | refuse | refuse |

The route-derived command-list assertion moves from five commands to six in
this slice, and that is the only reason it changes.

## Exactly where the sixth command goes

`collection-commands` delivered `app/controllers/concerns/EntryCommandAuthorization`
with three frozen tables. The gate, `entry_command_allowed?`, inspects only
`page_kind` and denies any command with no row. The view helper,
`offered_entry_commands`, intersects what a row's lifecycle supports with what
its residency admits, and `_entry.html.erb` makes a row a toggle exactly when
that list is nonempty.

Add the command to all of these:

| table | change |
|---|---|
| `COMMAND_RESIDENCIES` | one new row: `"move_to_collection" => %w[daily monthly_calendar monthly_tasks]` |
| `TASK_COMMANDS_BY_STATE` | `"open"` gains `move_to_collection`; `"done"` and `"struck"` do not |
| `EVENT_COMMANDS` | gains `move_to_collection`, still only for an event with no successor |
| `lifecycle_commands` | **needs a new `when "note"` branch** — a note with no successor offers `move_to_collection`, and today notes fall through to `NO_COMMANDS` |

The note branch is a new lifecycle capability, not a residency branch: it is
the first command a note has ever had. It does not violate the open-closed
rule `collection-commands` was held to — the residency table still grows by a
row, and the gate is untouched.

`RETURN_PAGE_KINDS` and `redirect_to_viewed_page` already send a Daily or
Monthly command back to its param-driven page and a Collection resident to its
persisted page. This command is offered only on Daily and Monthly residents, so
it inherits the source return with no change to that method.

The strip's two-step mechanics already exist: `_task_actions.html.erb` renders a
`[data-step]` region and `task_actions_controller.js#showStep` reveals exactly
one. The Schedule step is the working example; the Move step is its sibling and
must reuse those mechanics rather than copy them — jscpd is at zero clones and
stays there.

`_meta.html.erb` currently derives a destination from
`entry.successor.occurs_on || entry.successor.page_on`. A Collection successor
has neither, so today it would render a bare arrow. That is the line the Topic
destination belongs in.

## Resolving the destination

The reader submits a complete Topic. The server trims it and performs one
case-insensitive equality lookup inside `Current.user.collections.kept` — the
same exact-Topic scope Open by Topic uses. There is no picker, no candidate
list, no suggestion, no prefix or substring match, and no ordering by
relevance. The destination is resolved to a model object **before** the
movement is attempted; a Collection id or Topic in the request never bypasses
that lookup and never crosses a tenant boundary.

## The movement

On success the controller calls the existing operation exactly once:

```ruby
entry.move_to!(
  page_kind: "collection",
  page_on: nil,
  collection: destination,
  as_of: @today
)
```

No new movement code. The existing contract stands and is what this slice
verifies:

| aspect | result |
|---|---|
| eligible predecessor | an open task, or an event or note with NULL state, in every case with no successor |
| source | a root **or** a nested resident |
| successor | a new **root** — `parent_id` NULL — with a fresh UUIDv7 id and `migrated_from_id` pointing at the predecessor |
| task predecessor | `state` becomes `migrated` |
| event or note predecessor | `state` stays NULL; its moved-ness derives from the successor |
| copied to the successor | `kind`, `text`, `priority`, `tags`, `user` |
| **not** copied | `occurs_on` and `time_of_day` — the destination supplies no date, so the Collection successor clears both, as the existing move-to-a-page-without-a-date contract requires |
| predecessor's dates | unchanged; it keeps its historical `occurs_on` and `time_of_day` |
| children | do not follow |
| successor count | exactly one; a second move is refused by the unique successor chain |
| destination Collection | **not** registered as a side effect, and its `index_position` is unchanged |

Worked example. A Daily note `– call the ranger 17:00` on 2026-08-24, moved to
the unindexed Collection `Camping Trip`:

| row | kind | state | text | page_kind | page_on | collection_id | occurs_on | time_of_day | glyph |
|---|---|---|---|---|---|---|---|---|---|
| predecessor | note | NULL | call the ranger | `daily` | 2026-08-24 | NULL | 2026-08-24 | `17:00` | `>` |
| successor | note | NULL | call the ranger | `collection` | NULL | `Camping Trip` | NULL | NULL | `–` |

`Camping Trip` stays unindexed. The reader returns to the Daily Log for
2026-08-24.

## What the reader sees

The gesture lives in the existing collapsed action strip as a second two-step
reveal beside Schedule…: a `Move to Collection…` control opens a step holding
one labelled exact-Topic field (`autocomplete="off"`) and a Move button.
Nothing appears while typing.

It is offered on an eligible Daily, Monthly Calendar, or Monthly Tasks
resident, and only where the residency policy and the entry lifecycle both
allow it:

| resident | Move to Collection… offered |
|---|---|
| Daily / Monthly open task | yes |
| Daily / Monthly event with no successor | yes |
| Daily / Monthly note with no successor | yes — this row has one action where it previously had none |
| Daily / Monthly done, struck, or migrated task | no |
| Daily / Monthly entry with a successor | no |
| Future resident, any kind | no |
| Collection resident, any kind | no |

A Daily or Monthly note with no successor becomes actionable for the first
time, so the collapsed strip must now treat such a note as a toggle rather
than a plain line. Every existing Daily and Monthly task and event control
stays exactly as it is.

The predecessor renders `>` and its destination meta names the Collection —
`→ Camping Trip`. The existing date destination meta for Monthly and Future
successors is unchanged: a successor carrying `occurs_on` or `page_on` still
renders its date, and only a Collection successor renders a Topic.

## Where it returns

Success returns to the **persisted source page the reader was reviewing** —
the same destination that page's other commands already use. It never strands
the reader on the destination Collection.

Every refusal returns to that same source page with `REFUSAL_ALERT`, leaving
both sides unchanged — no successor, no state change, no row written:

| refusal |
|---|
| blank Topic |
| unknown Topic |
| Topic of a soft-deleted Collection |
| Topic owned only by another user |
| ineligible predecessor: done, struck, or migrated task |
| ineligible predecessor: an entry that already has a successor |
| a second move of the same entry |
| a Future or Collection resident (residency policy) |

A foreign, missing, or soft-deleted **entry** is 404, not a refusal, as
`collection-commands` established.

## Ruled browser flows for this slice

These are the accepted spec's flows 6 and 7.

6. An eligible Daily note uses Move to Collection… with an exact Topic. The
   predecessor shows `>` and the destination Topic; one root successor appears
   in the unindexed Collection, which remains unindexed. The source page is the
   return destination.
7. Eligible Daily, Monthly Calendar, and Monthly Tasks residents can all use
   the same gesture. A wrong, foreign, or deleted Topic, an already-moved event
   or note, a non-open task, a Collection resident, and a Future resident are
   all refused, with no second row and no predecessor mutation, returning
   according to the matrix.

Existing Today, Month, Future, capture, lifecycle, Index, Collection, and tab
flows stay green.

## Required tests

Fixtures and real rows; fixed dates or `travel_to`; no doubles for Rails, the
clock, or Active Record.

- The route-derived command list now equals six commands, and the twenty-five
  cells of the existing matrix grow to thirty: the new command is pinned
  against all five page kinds, positive cells succeeding and negative cells
  reloading exact attributes with no successor and no unrelated write.
- Move an **open task**, an **event**, and a **note** from each of the three
  structurally possible source pages — Daily, Monthly Calendar, Monthly
  Tasks — that admits that kind at root, and from a **nested** resident as well
  as a root.
- Every column of the movement table: successor is a root with a fresh UUIDv7
  id and `migrated_from_id`; `occurs_on` and `time_of_day` cleared on the
  successor and retained on the predecessor; `kind`, `text`, `priority`,
  `tags`, and `user` copied; task predecessor `migrated` and event/note
  predecessor NULL; children not followed.
- The one-successor rule: a second move is refused and writes nothing. Retain
  the existing raw unique-successor probe unchanged.
- Exact-Topic destination lookup: hit on an indexed and on an unindexed
  Collection; every refusal shape in the table above; the tenant boundary; and
  no prefix, substring, or fuzzy match.
- The destination Collection's `index_position` is unchanged after a
  successful move, and a move into an unindexed Collection leaves it
  unindexed.
- Destination meta: a Collection successor renders the Topic, a Monthly
  successor renders its date, and a Future successor renders its date.
- Source return after success and after every refusal, for each source page.
- The rendering table above: which residents offer the control and which do
  not, and that each absent control's command is refused when crafted.
- `hlc` and `server_seq` are unwritten on both rows.

System lane covers flows 6 and 7, asserting absent controls **and the server
refusal behind each**, exact URL, status, and flash destinations, the `>` glyph
and Topic meta on the predecessor, the single successor on the destination
page, 44 px targets, and truthful `aria-expanded` state on the two-step reveal.

## Invariants this slice must not disturb

UUIDv7 ids; tenant scoping on every query; append-only movement — `move_to!`
is the only writer of a successor and nothing updates a placement in place;
soft deletion without cascades; immutable entry placement; the unique successor
chain; and dormant `hlc`/`server_seq`, which this slice never writes.

## Quality bars

- `bin/rails test` and `bin/rails test:system` green, run in this worktree.
- `bin/rubocop` clean.
- `COVERAGE=1 bin/rails test` then
  `crap4rb --lcov coverage/lcov.info app/ lib/` — every measured method
  CRAP ≤ 6.
- `jscpd --min-tokens 50 --reporters console app/ lib/` — zero clones. The
  two-step reveal reuses the existing strip mechanics rather than copying the
  Schedule step.
- `lib/` untouched, so `Bujo::RapidLog*` mutation remains exactly 1105/1105.

Hand-mutate at least these and show each is killed by an assertion that
explains the product failure, not by an incidental exception:

- resolve the destination without the tenant scope, or without `kept`;
- make the destination lookup a prefix or substring match;
- register the destination Collection after a successful move;
- copy `occurs_on` or `time_of_day` onto the Collection successor;
- clear `occurs_on` on the predecessor;
- give the successor the predecessor's `parent_id`;
- allow the command on a Future or Collection resident;
- allow it on a task that is done, struck, or migrated;
- return to the destination Collection instead of the source page;
- render the successor's date instead of the Topic in destination meta.

## When this slice lands

1.5.2 is complete. Every acceptance-contract bullet and all ten ruled browser
flows of the accepted spec are then delivered across
`collection-domain`, `collection-pages`, `collection-commands`, and
`move-to-collection`. The terminal candidate goes to the operator for review;
no role integrates it into `main`.

## Handoff

Commit, `git_handoff` to `coder`, task `move-to-collection`, priority `50`.
