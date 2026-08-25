# Implementing slice 1.5.2 — the four-slice order

`docs/slices/1.5.2-custom-collections-and-index.md` is the operator-approved
specification. It is fixed: its acceptance contract, its schema ruling, its
entry-command matrix, its ruled browser flows, its file scope, its non-goals,
and its five approved digital translations all bind exactly as written.

The documents in this directory add nothing to it. They divide its fixed
behavior into four units, each implementable and verifiable on its own, each
running the full pack chain and each leaving the suite green. Where one of
them disagrees with the accepted spec, the accepted spec wins and the
disagreement is a defect in this directory.

`docs/METHOD.md`, `PLAN.md`, and `ARCHITECTURE.md` bind ahead of all of it, in
that order.

## Status

| # | task name | status |
|---|---|---|
| 1 | `collection-domain` | **done** — verified and closed at `8159581b5a` |
| 2 | `collection-pages` | **done** — closed at `d6c18945b4` after one finding (see `b2-collection-pages-corrections.md`) |
| 3 | `collection-commands` | **done** — verified and closed at `06a88b788d` |
| 4 | `move-to-collection` | **active** — handed to coder; last slice of 1.5.2 |

The specifier updates this table when a slice's completion broadcast returns
and the next slice is handed down.

## Order

| # | task name | file | delivers |
|---|---|---|---|
| 1 | `collection-domain` | `a-collection-domain.md` | the migration, Topic normalization, `register!` / `unindex!` / guarded deletion, `Collection::LifecycleError`, the Index relation, the exact-Topic scope, the Collection root scope |
| 2 | `collection-pages` | `b-collection-pages.md`, then `b2-collection-pages-corrections.md` | routes, `CollectionsController`, the Index / Collection / not-found screens, Collection capture, the live Index tab, the title-first header invariant |
| 3 | `collection-commands` | `c-collection-commands.md` | the command-by-residency policy replacing `ACTION_PAGE_KINDS`, Collection Complete / Strike / Reopen, the rendering matrix |
| 4 | `move-to-collection` | `d-move-to-collection.md` | the Move to Collection… gesture and its destination meta |

Each slice must be complete before the next begins, because each consumes
rules the previous one pinned.

## How the accepted spec's ruled browser flows are covered

| flow | slice |
|---|---|
| 1 create and land on an empty unindexed page | `collection-pages` |
| 2 capture three kinds on the page | `collection-pages` |
| 3 register, append, rename, unindex, re-register | `collection-pages` |
| 4 unindexed page opened only by exact Topic | `collection-pages` |
| 5 Collection task lifecycle, Migrate/Schedule absent | `collection-commands` |
| 6 Daily note moves to a Collection | `move-to-collection` |
| 7 every eligible source page and every refusal | `move-to-collection` |
| 8 guarded deletion and the themed 404 | `collection-pages` |
| 9 uniform missing state and cross-tenant probes | `collection-pages` |
| 10 phone-width review in both themes and two hands | split: screens in `collection-pages`, open action strip in `collection-commands`, two-step reveal in `move-to-collection` |

## Two things no pack role should redo

**The `ARCHITECTURE.md` amendment is already applied**, in commit `870e1fc`
"Accept the source-aligned 1.5.2 slice". The `collections` row already reads
`… name · index_position? · hlc · server_seq …` and the Index prose already
describes a query over kept Collections with a server-allocated rank. Do not
amend it again and do not improvise a different sync design.

**The approved mock delta is operator work.** The one review artboard,
`IndexCollection.dc.html` plus its `canvas.json` entry, belongs in the separate
`bujo-mockups` repository. No role in this swarm edits a file outside its own
worktree, so no role produces it. Implement the layout from the accepted
spec's rulings and review grid, and report the mock as outstanding.

## Two things that carry across all four slices

**The invariants.** UUIDv7 ids with caller-supplied ids preserved; `user_id`
tenant scoping on every query; append-only movement through `Entry#move_to!`;
soft deletion without cascades; immutable entry placement; the unique successor
chain; and `hlc` / `server_seq` dormant — never written by any of these slices.

**The untouchables.** `lib/`, `Gemfile`, and `PLAN.md` are not edited during
implementation, so `Bujo::RapidLog*` mutation stays exactly 1105/1105. No role
deploys, and no role integrates into `main`; the operator does that after human
review.
