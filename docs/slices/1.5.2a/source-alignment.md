# Slice 1.5.2a implementation alignment — baseline `ea6d946`

Status: **specifier-audited implementation companion** to the operator-approved
amendment in `docs/slices/1.5.2a-index-is-the-collection-register.md`.

This companion records how the approved behavior meets the landed Rails source
at `ea6d946f7752ead037377e8434b9daf3ebf9b379`. It does not amend or reopen the
approved amendment or `mockups/IndexSourceCorrection.dc.html`. If this file and
either approved authority can be read differently, the approved authority wins.

The audit found no product question or blocker. The correction remains one
coherent Collection/Index slice. It needs one migration, the existing Collection
domain and page surface, and focused regression changes. It needs no Entry
production change, new entity, dependency, parser change, JavaScript behavior,
active sync, authentication, deployment, or production-data work.

## Landed-source clarifications

These points make the approved contract executable against the landed tree.
They add no product behavior.

1. **The 1.5.2 migration stays historical.**
   `20260825210000_add_index_position_to_collections.rb` correctly records the
   old transition in which existing rows stayed unindexed. Do not edit it or
   reinterpret its focused test. Add the correction migration after it; only
   the complete migration chain backfills kept NULL-position rows and adds the
   live-row check.
2. **There is one legal kept-row creation boundary.** A persisted kept
   Collection must receive its server-owned position in the same transaction
   that creates it. An unpersisted form object may still have a NULL position,
   and a tombstone may retain or omit one. Ordinary model creation is not a
   second hidden allocation path and must not be made valid with a callback or
   a test-only exception.
3. **The optional id belongs to the domain creation boundary.** The named
   model-owned operation accepts the owner, Topic, and optional caller-supplied
   UUIDv7 id. The browser form still presents only Topic; this slice adds no id
   field, rank field, JSON/sync endpoint, or active client operation. A focused
   model test supplies the optional id directly and proves it is preserved.
4. **Exact-Topic lookup survives only where the amendment keeps it.** Remove
   the Index's locate action and UI, but retain `Collection.with_exact_topic`.
   `EntriesController#move_to_collection` and
   `MonthlyMigrationsController#outgoing_collection` still use that same-user,
   kept, exact-Topic relation. Removing it would change Entry behavior and fail
   the amendment.
5. **Removed command probes use literal paths.** Once the route helpers and
   actions are gone, tests address `/collections/locate`,
   `/collections/:id/register`, and `/collections/:id/registration` as literal
   verb/path pairs. They assert 404 and an exact before/after data snapshot,
   rather than retaining a helper or compatibility action solely for testing.
6. **The review board shows revealed ephemeral panels.** It does not make the
   New Collection or rapid-log form persistently open. Keep the landed reveal,
   cancellation, focus, refusal-reopen, and trailing-canvas behavior. A
   successful create lands on the canonical empty page with its notice; the
   reader still opens capture through the empty message or trailing canvas.
7. **Ordinary test data obeys the corrected invariant.** The landed `camping`
   fixture and valid test setup Collections become indexed rows. A kept NULL
   row exists only inside the isolated pre-correction migration harness (or as
   an intentional raw database attack before the new check is applied). Do not
   weaken the model or database rule to preserve old test setup shorthand.
8. **Frozen Tailwind T0 artifacts remain historical.** Do not rename or edit
   `docs/tailwind-v4-baseline/**` or
   `test/fixtures/files/tailwind_v4_t0.css`. Historical state labels such as
   `collection-empty-unindexed` may remain in the parity harness; their setup
   must create a valid current Collection and no longer call `register!`.

## Persistence transition

Add one irreversible migration after the landed index-position migration. It
owns both the one-time data correction and the new check. It must use migration
SQL or a migration-local table definition, never `Collection`, callbacks, or
the current application's validations.

For every user independently, the forward result is exactly:

| prior row | forward `index_position` |
|---|---:|
| kept, position `2` | `2` |
| kept, position `5` | `5` |
| tombstone, position `9` | `9` |
| first kept NULL row by `created_at, id` | `10` |
| second kept NULL row by `created_at, id` | `11` |
| tombstone, NULL position | NULL |

Another user's retained maximum and appended sequence are calculated from
that user's rows only. Equal `created_at` values are resolved by ascending
string id. Gaps below the greatest retained rank remain gaps. Ranked
tombstones contribute to the maximum, while NULL tombstones are neither
backfilled nor counted as a rank.

The migration proof snapshots every Collection column and representative Entry
rows before running. Afterwards, only the intended kept NULL rows differ, and
only in `index_position`. In particular, `updated_at`, `deleted_at`, `hlc`,
`server_seq`, ids, names, ownership, and every Entry attribute are byte-for-byte
unchanged. Running down raises `ActiveRecord::IrreversibleMigration`.

The final schema retains all three protections:

- nullable bigint `index_position`, with no default;
- the existing `index_position IS NULL OR index_position > 0` check and kept
  per-user partial unique index; and
- a new check equivalent to
  `deleted_at IS NOT NULL OR index_position IS NOT NULL`.

The database accepts a NULL-position tombstone and a ranked tombstone. It
rejects a kept NULL-position insert or update, zero/negative positions, and a
duplicate kept per-user rank. A fresh schema and a migrated prior schema prove
the same final checks and index.

## Collection domain alignment

`Collection` currently owns Topic normalization, UUIDv7 creation, direct-rank
write protection, registration allocation, guarded deletion, Index ordering,
and exact-Topic lookup. Align that ownership as follows:

- replace `registrable?`, `register!`, and `unindex!` with one named
  model-owned creation operation;
- retain `Collection::LifecycleError` for guarded deletion refusals;
- retain Topic trimming, case-insensitive kept per-user uniqueness,
  `deletable?`, `soft_delete_if_unused!`, `with_exact_topic`, UUIDv7 behavior,
  and the kept relation;
- make the model mirror the database's kept-position presence rule while
  continuing to permit either tombstone shape;
- keep raw and mass-assigned positions invalid outside the named creation
  operation; and
- make the Index relation the complete kept same-user set in
  `index_position, id` order.

The creation operation has these observable outcomes:

| request | durable result |
|---|---|
| valid unique Topic, no retained rank | one kept row at position `1` |
| valid unique Topic after retained ranks `2` and `9` | one kept row at position `10` |
| valid Topic for another user whose maximum is `3` | that user's row at position `4` |
| blank Topic | invalid record/refusal; no row and no durable rank |
| same-user case-insensitive duplicate | invalid record/refusal; no row and no durable rank |
| caller supplies a valid UUIDv7 id | same id is persisted with the allocated rank |
| caller does not supply an id | one UUIDv7 id is generated |
| caller or mass assignment supplies a rank | supplied rank is not accepted |

Allocation includes kept and soft-deleted rows for that owner, happens in the
same transaction as insertion, and leaves `hlc` and `server_seq` NULL. A
uniqueness collision is retried only a bounded number of times. Concurrent
valid creates either persist at distinct append positions or produce an
ordinary validation/refusal outcome; neither exposes `RecordNotUnique` or a
partial row. A duplicate-name race persists at most one Topic and consumes no
second durable rank.

Rename, reading, capture, correction, lifecycle actions, inbound movement, and
Monthly Migration leave the complete Collection snapshot unchanged except for
the field their existing contract owns. Guarded deletion changes only
`deleted_at` and its ordinary timestamp behavior; it retains the position on
the tombstone. A later create appends after that retained rank.

## Routes and controller alignment

`CollectionsController#create` currently builds and saves an unindexed
association row. It becomes the browser adapter to the model-owned atomic
creation boundary, always passing the signed-in user and submitted Topic.

Create keeps the landed response contract:

- success redirects to the canonical UUID Collection URL with
  `Collection created.`;
- blank or duplicate refusal renders Index with status 422, the New Collection
  panel open, the submitted Topic preserved, and no row or rank consumed; and
- a crafted `index_position` value cannot influence allocation.

`prepare_index` continues to build an unpersisted form object when no rejected
record exists. Its collection relation now contains every kept Collection for
the current user. It never consults a global Collection relation, a foreign
maximum, Entry content, Topic sort, activity, or request-supplied rank.

Remove `CollectionsController#locate`, `#register`, and `#unindex`, their
locate-specific alert, and their callback/action references. Keep the
current-user kept lookup for show, rename, and guarded delete; keep the uniform
Collection 404 renderer and the existing lifecycle refusal used by deletion.

The remaining Collection route surface is only:

| verb | path | behavior |
|---|---|---|
| GET | `/index` | complete same-user kept Index |
| POST | `/collections` | atomic create and append |
| GET | `/collections/:id` | kept same-user page |
| PATCH | `/collections/:id` | rename in place |
| DELETE | `/collections/:id` | existing guarded tombstone |

The three removed verb/path pairs are not routed to a controller action and
write nothing. The existing Entry capture, correction, lifecycle, scheduling,
Move to Collection, and Monthly Migration routes are unchanged. A malformed,
missing, foreign, or deleted id on a remaining Collection member route still
returns the same nondisclosing Collection 404.

## Index and Collection presentation alignment

The existing views already provide title-first headers, the explicit New
Collection control, the trailing Index create surface, Manage/Rename/guarded
Delete, deferred success flash, shared Collection capture, and the fixed Index
tab. Preserve those seams.

On Index:

- keep `Index` as the first visible text and heading, with
  `Your collections` immediately below;
- render every kept same-user Topic link in append order;
- show `Nothing indexed yet.` only when there are no kept rows;
- keep New Collection and the trailing blank canvas as two reveals of the same
  form; and
- remove the Open by Topic toggle, panel, labels, copy, and form completely.

On a Collection:

- render the Topic first and exact context `Collection`;
- render exact empty copy `Nothing logged yet.` with no second registration
  instruction;
- retain the shared Task/Event/Note capture form and its empty/trailing reveal;
- retain Manage, Rename, and guarded Delete; and
- remove Add to Index, Remove from Index, indexed/not-indexed status, the
  registration wrapper, and registration-dependent spacing.

The success notice remains shared semantic flash content directly below the
title/context area, never an input-like field. The approved mock's two states,
plus 390px/320px, light/dark, Rock Salt/Architects Daughter, empty, populated,
refused, missing, and deleted states, remain the visual acceptance matrix.
Every visible control is at least 44px, long Topics wrap, and content does not
collide with the fixed tabs or overflow horizontally.

Only dead locate/registration declarations leave
`app/assets/tailwind/pages/collections.css`; the surviving Collection page
owner and its import remain. Update `CollectionsPresentationSourceTest`'s
selector/declaration ledger to describe the surviving owner without modifying
the frozen T0 stylesheet. The shared `placement` controller still owns both
reveal behaviors, so the source audit found no dead Collection-only JavaScript
or manifest import to remove.

## Entry and tenant regression fence

No production file under `Entry`, its command controllers, Monthly Migration,
Daily Reflection, or shared Entry presentation needs to change.

Keep these exact seams green:

- Collection capture still goes through `Entry.capture!`, accepts Task/Event/
  Note roots, writes exact Collection residency, and leaves the destination's
  position and dormant sync fields unchanged;
- ordinary Move to Collection and Monthly Migration still resolve a known
  exact Topic inside `Current.user.collections.kept`, append one UUIDv7
  successor, preserve same-user ownership and ancestry rules, and leave the
  destination position unchanged;
- task predecessors retain their ruled migrated state, while moved events and
  notes retain exact NULL state;
- missing, deleted, or foreign destinations append nothing and mutate neither
  predecessor nor Collection; and
- guarded Collection deletion remains soft deletion without Entry cascades,
  and a used Collection still refuses.

Existing tests that asserted movement or capture left an *unindexed*
destination now snapshot its non-NULL position and assert that same value after
the command. That is a test expectation correction, not permission to alter
Entry production behavior.

## Focused test-data conversion

The live-row check means valid setup can no longer call bare
`user.collections.create!` and receive a kept NULL-position row. Convert valid
Collection setup to the named atomic operation in the focused Collection tests
and in the following regression files that need a Collection only as context or
destination:

- controller tests for Collection Entry commands, Daily Reflection, Entry
  command authorization/correction, Monthly Migration and Undo, Move to
  Collection, and page rendering;
- model tests for Entry and page placement;
- system tests for Monthly Migration, Move to Collection, shared Tailwind
  Entries, and Tailwind geometry parity; and
- `test/fixtures/collections.yml`.

Those compatibility edits change construction only. They do not add Index UI
assertions to unrelated tests, change command policy, rewrite page semantics,
or weaken exact snapshots. Intentional invalid-model tests and isolated
migration rows may continue to bypass the creation boundary for the specific
refusal or schema fact they prove.

`test/models/collection_index_position_migration_test.rb` remains the proof of
the landed 1.5.2 migration by itself. Add a separate focused correction-
migration test for the new migration, including multi-user ordering, equal-time
id ordering, gaps, ranked and NULL tombstones, untouched fields and Entries,
both checks, the partial unique index, fresh-schema behavior, and irreversible
down.

## Test-first acceptance receipt required downstream

Before production changes, focused tests must express the whole correction and
fail for the expected landed behavior: unindexed create, absent backfill/check,
present lifecycle routes/actions/controls, incomplete Index membership, and
superseded copy. Do not manufacture a red state by changing working code.

The fast and system matrices in the approved amendment remain binding. In
particular, the system lane covers all nine ruled flows, including literal
removed-route probes, full Collection snapshots, tenant isolation, append
stability after rename/capture/movement/deletion, and both phone profiles. Run
the project commands exactly:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
```

Every measured method remains at CRAP <= 6, jscpd reports zero clones, and the
unchanged parser receipt remains exactly 1105/1105. Hand-mutation targets remain
the seven named targets in the approved amendment. No parser source or parser
test change is authorized to obtain that receipt.

## Confirmed implementation fence

Expected production scope is the approved migration/schema, Collection model,
Collections controller/routes/views, and removal of dead Collection-owned CSS.
Focused tests and the mechanical valid-Collection setup conversions above are
inside the correction because the database invariant makes them necessary.

Do not edit `PLAN.md`, `HANDOFF.md`, `docs/METHOD.md`, `ARCHITECTURE.md`, the
approved amendment, approved mock, historical migrations, frozen Tailwind T0
artifacts, Entry production behavior, Monthly Migration production behavior,
Daily Reflection, `lib/`, parser grammar, dependencies, authentication, PWA,
active sync, deployment, or production data. A discovered need for any other
production surface is a blocker to return to the operator rather than a reason
to widen the slice.

## Specifier audit receipt

- Canonical baseline verified at
  `ea6d946f7752ead037377e8434b9daf3ebf9b379` before this companion was written.
- The governing method, plan, architecture, handoff, approved amendment,
  supersession notes, and complete review mock were read.
- The landed migration/schema, Collection model/controller/routes/views/CSS,
  focused migration/model/controller/presentation/system tests, exact-Topic
  movement callers, fixtures, and direct Collection-construction call sites
  were inspected.
- No product authority was edited, no implementation was performed, and no
  production, deployment, or external state was touched.
