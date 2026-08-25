# The Method — bujo's binding reference

Distilled from *The Bullet Journal Method*, Parts II–III (operator
study, 2026-08-24, prompted by dogfooding: derived views were
surfacing entries nobody placed). **This document binds every future
spec the way ARCHITECTURE.md binds the schema.** Where the app and
the book disagree, this file says so out loud, and PLAN.md records
the ruling.

## The system, as the book defines it

**Rapid Logging is the language.** Short objective bullets on a
dated page: `•` task, `○` event (written `º`), `–` note. Task
states: `x` complete, `>` migrated (moved forward into a Monthly
Log or Collection), `<` scheduled (moved *backward* into the Future
Log), struck-through irrelevant. Signifiers prefix a bullet: `*`
priority ("if everything is a priority, nothing is"), `!`
inspiration. Subtasks nest under a master task; the master completes
only when every subtask is done or struck.

**Four core Collections:**

- **Daily Log** — the workhorse; a catchall created *the day of or
  the night before, never ahead*. Everything gets captured here
  first, even future-dated things. Never indexed.
- **Monthly Log** — a spread: the **Calendar page** (dates down the
  edge; events/tasks slotted by hand — prospectively as a planner,
  or after the fact as a timeline; Ryder prefers the timeline) and
  the **Tasks page**, the month's *mental inventory*: what matters
  this month, written at setup, plus what monthly migration carries
  in. It is a curated list, never a mirror.
- **Future Log** — the queue for anything dated beyond the current
  month. Fed two ways: directly at setup, or from Daily captures
  during reflection (capture freely in the Daily Log, then move the
  future-dated bullet here and mark the original `<`).
- **The Index** — collections registered by topic and page; the map
  of what you're saying yes to.

**Migration is the engine, and its friction is deliberate.** At
month's end: set up the new Monthly Log, then walk every open task
of the old month, one by one — strike the irrelevant, carry the
worthy (`>` to the new Tasks page or a Collection, `<` to the Future
Log if dated beyond the month). Then scan the Future Log for items
whose month has arrived and carry them into the new Monthly Log.
"We rewrite things until we get them done or they become
irrelevant." Nothing rolls over on its own — the cost of rewriting
IS the filter.

**Reflection is the rhythm.** AM: review the month's open tasks,
plan. PM: update the day's log, mark completions, strike
distractions, move future-dated captures to the Future Log. Five to
fifteen minutes; consistency over duration.

**The prime directive underneath all of it: nothing moves by
itself.** Every entry sits exactly where a hand put it, and every
movement is a deliberate, slightly costly act of re-commitment.

## Where the app stands (2026-08-24)

Faithful:

- Rapid logging, the bullet grammar, `*` priority, nesting, task
  lifecycle with the `>`/`<` successor trail (the successor chain is
  a good digital body for "rewrite and mark the old one").
- The Daily Log as capture-first catchall; capture hidden at rest;
  placement as gesture (the principle, if not yet every mechanism).
- Migration primitives (complete/strike/migrate/schedule) acting
  only on deliberate taps.

Divergent — each needs a ruling:

1. **The Monthly Tasks page is a derived mirror** (every task
   `logged_on` in the month). The book's Tasks page is a curated
   inventory: seeded at monthly setup, grown only by migration and
   deliberate adds. *This is the drift dogfooding caught.*
2. **Future entries materialize on daily pages.** The Future Log
   month-add writes `logged_on = occurs_on`, so the entry simply
   appears on that day when it arrives. The book's Future Log is a
   queue; items enter a month only when monthly migration carries
   them in.
3. **Write-on-a-future-day-page exists.** The book advises against
   creating Daily Logs ahead of time — future-dated content belongs
   in the Future Log until its month comes.
4. **The Monthly Calendar derives from `occurs_on`.** The book's
   calendar is hand-slotted — though Ryder blesses using it
   prospectively, and in digital form "writing an event on its date
   line" and "dating an event" are arguably the same deliberate act.
   The mildest divergence, possibly none.
5. **Master-task completion is not gated on subtasks** (book: it
   is). Small; noted.
6. **Missing organs**: the Index (planned, 1.6), custom Collections
   (model exists, no UI), the `!` inspiration signifier, and
   reflection as a first-class surface (the parked "Place from
   today" gesture is, in book terms, exactly the PM-reflection move
   of scheduling a day's capture into the Future Log).

## The likely shape of the fix (for discussion, not yet ruled)

Entries need a notion of *where they live* — a daily page, a
month's Tasks page, the Future Log, a Collection — with movement
only through migration gestures that leave the `>`/`<` trail the
model already knows how to write. The Monthly Tasks page becomes a
real page fed by monthly setup and migration; the Future Log
becomes a real queue whose items wait for the ritual; slice 1.5
(the migration ritual) stops being a screen and becomes the
system's heartbeat. Schema implications run through ARCHITECTURE.md
and the sync design before any spec is written.
