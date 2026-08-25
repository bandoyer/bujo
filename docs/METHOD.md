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
month's end: set up the new Monthly Log and seed its Tasks page with
a fresh mental inventory. Then scan every Daily and Monthly page of
the outgoing month, assessing each unresolved task in its tree context:
strike the irrelevant; rewrite the still-worthy into the new Tasks
page or a relevant Custom Collection (`>`); schedule anything dated
beyond the new current month into the Future Log (`<`). Finally scan
the Future Log: tasks whose month has arrived move to the new Tasks
page, while events move to the new Calendar page. A Custom Collection
is a possible destination, not a page that monthly migration silently
sweeps; its tasks are reviewed when that collection is deliberately
opened. "We rewrite things until we get them done or they become
irrelevant." Nothing rolls over on its own — the cost of rewriting
IS the filter.

**Reflection is the rhythm.** AM: review all open tasks for the
current month and choose what matters today. PM: review today's
entries, mark completions, strike distractions, schedule anything
outside the current month into the Future Log, and acknowledge
progress. Five to fifteen minutes; consistency over duration.

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
6. **Missing organs**: a deliberate Index, writable custom
   Collections (the model exists, no UI), the `!` inspiration
   signifier, and reflection as a first-class practice. The parked
   "Place from today" gesture is, in book terms, part of PM
   reflection rather than a free-floating entry action.

## The rulings (operator, 2026-08-24; corrected 2026-08-25)

**Book-faithful v1. Start minimal and true to Ryder's philosophy;
make it "smarter" later only where real use proves the pain.**

1. **Everything is a page** (Option B): the Monthly Calendar and
   Tasks pages, Future Log, Daily Logs, and Custom Collections are
   places an entry can reside. Page membership is never derived from
   an entry's dates and never changes in place; only deliberate
   capture or append-only movement creates residency. This does not
   ban transient reflection, Index, or later search screens from
   *referencing* entries where they already live. Those are lenses,
   not additional pages and not additional residency.
2. **Each core page keeps the book's vocabulary.** A Daily Log may
   root tasks, events, and notes. A Monthly Calendar may root tasks
   and events. A Monthly Tasks page roots tasks. The Future Log roots
   dated tasks and events. A Custom Collection may root all three.
   Notes may still be nested as context under a valid root on a
   stricter page; a child always shares its parent's page.
3. **The Future Log means outside the current month, not merely
   after today.** Same-month plans belong on the current Monthly
   Calendar. New Future Log roots must be dated after the current
   month, but existing items remain visible when they become current
   or overdue until a hand migrates or resolves them.
4. **Direct writing is guarded by page time.** Daily writing is
   available for today and past days. Ryder also allows preparing
   tomorrow's Daily Log the night before; v1 deliberately omits that
   clock-dependent exception and will revisit it through dogfooding.
   Monthly Calendar and Tasks pages are directly writable for the
   current or past month. Future monthly pages may display entries
   deliberately carried there, but offer no ordinary capture surface;
   their setup is the migration ritual's job.
5. **Movement stays general; gestures stay source-specific.** The
   append-only successor mechanism can move an entry to any page that
   accepts its kind. In this slice, task actions expose `Migrate` to
   the next Monthly Tasks page and task/event actions expose
   `Schedule…` to the Future Log. Notes do not gain a Future Log
   action; their natural non-daily destination is a Custom Collection.
6. **Enforce placement at the domain boundary, not with a false
   database promise.** Public model/domain APIs and mass assignment
   must refuse placement changes. Direct SQL can bypass that rule and
   is not claimed as an invariant; database constraints still defend
   the structural rules they can actually express, including the
   one-successor chain.
7. **Build the practice before digital convenience.** After the page
   model: writable Custom Collections plus a deliberately maintained
   Index, the monthly migration ritual, AM/PM reflection, and the two
   small source gaps (`!` and master-task completion gating). Broad
   search, settings polish, and PWA work wait until this spine exists.
   No bespoke feature is required for every Part III example; generic
   Collections and reflection are the mechanism.
8. **Model-first sequencing**: pages are immutable columns, never
   container tables; movement is append-only migration, so the
   no-container-conflict property survives. The
   `bujo-conventions` skill's "logs are date queries" invariant
   updates to "logs are residency scopes over immutable page
   columns" only when the schema slice lands.
