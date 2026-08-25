# 1.5.2b — The Collection page and the deliberate Index

Task name: `collection-pages`

Derived from the operator-approved `docs/slices/1.5.2-custom-collections-and-index.md`.
That document is the authority; this one only chooses the order in which its
fixed behavior lands. Where the two disagree, the accepted spec wins.
`docs/METHOD.md`, `PLAN.md`, and `ARCHITECTURE.md` bind ahead of both, in that
order. None of the five approved digital rulings may be reopened here.

Builds on `collection-domain`, which already landed `index_position`, Topic
normalization, `register!`, `unindex!`, guarded deletion,
`Collection::LifecycleError`, the Index relation, the exact-Topic scope, and
the Collection root scope. **This slice adds no domain rule.** It gives those
rules their reader-facing gestures. A rule that seems to be missing is a
finding against `collection-domain`, not a licence to write it into a
controller.

## The API `collection-domain` delivered

Use these exact names. A rule that seems to be missing from them is a finding
against `collection-domain`, not a licence to write it into a controller.

| what you need | call |
|---|---|
| the reader's Collections | `Current.user.collections`, plus `.kept` for a live page |
| registered Topics in manual order | `.in_index_order` |
| one exact Topic, trimmed and case-insensitive | `.with_exact_topic(topic)` |
| a Collection page's kept root residents | `user_entries.collection_page(collection.id)` |
| may this be added to the Index? | `collection.registrable?` |
| add it | `collection.register!` |
| remove it | `collection.unindex!` |
| may this be deleted? | `collection.deletable?` |
| delete it | `collection.soft_delete_if_unused!` |
| is this row live? | `collection.kept?` |
| an invalid transition | `Collection::LifecycleError` |

`Collection#name` is already trimmed by a `before_validation`, so a controller
never trims a Topic itself.

## In scope

`config/routes.rb`, `app/controllers/`, `app/views/`, `app/assets/stylesheets/`, `app/javascript/`, and `test/`.

The accepted spec's file scope governs and is not widened here: one migration
plus `db/schema.rb`, `app/models/`, `app/controllers/`, `app/views/`,
`app/assets/stylesheets/`, `app/javascript/`, `config/routes.rb`, and `test/`.
`app/helpers/` is not on that list, so a predicate a view needs is exposed from
a controller or concern with `helper_method`, as `FutureLogTargets` already
does.

## Out of scope — arriving later in 1.5.2

- Entry command authorization and Collection-resident Complete/Strike/Reopen —
  `collection-commands`. **In this slice Collection residents render as plain
  lines with no action strip, and every crafted entry command against a
  Collection resident is still refused**, exactly as 1.5.1a left them.
- Move to Collection… — `move-to-collection`.
- Every 1.5.2 non-goal, unchanged: no all-Collections list, no search,
  suggestions, autocomplete, prefix or fuzzy match, no recent/favorite lens, no
  drag reordering, no entry counts or activity metadata, no Collection picker,
  no starter content, no automatic registration, no PWA or deployment work, no
  `lib/`, `Gemfile`, or `PLAN.md` edits.

## Routes

The URLs and verbs are the contract; Rails-conventional names are welcome.

| verb | path | gesture |
|---|---|---|
| GET | `/index` | the deliberate Index |
| POST | `/collections` | create an unindexed Collection |
| POST | `/collections/locate` | exact-Topic open gesture |
| GET | `/collections/:id` | one kept Collection page |
| PATCH | `/collections/:id` | rename |
| POST | `/collections/:id/register` | register |
| DELETE | `/collections/:id/registration` | unindex |
| DELETE | `/collections/:id` | guarded soft deletion |

No generic search endpoint and no route that lists Collections other than
`/index`. `GET /index` needs a path helper name that does not collide with the
`collections` name `POST /collections` already claims.

Keep normal framework controllers: one new `CollectionsController` beside the
existing `EntriesController`. Do not introduce a service-object or
policy-object layer.

## Tenant scoping

Every action begins from `Current.user.collections`. Routes that render or
mutate a live page add `kept`. No unscoped `Collection.find` appears anywhere
in `app/`. `JournalReading` gains the signed-in reader's Collection relation
beside `user_entries`, and controllers use it rather than reaching for
`Current.user` themselves. Every route requires authentication like the
existing journal screens.

## The uniform missing state

A Collection lookup failure renders one themed, signed-in page:

- HTTP **404**;
- title `Collection not found` as the first visible text and first heading;
- one Back to Index link, at least 44×44 CSS px;
- the Index tab active;
- the requested id, the requested Topic, and any entry content absent from
  the response body.

These are byte-for-byte identical responses:

| probe |
|---|
| `GET /collections/not-a-uuid` |
| `GET /collections/0198f3b9-0000-7000-8000-0000000000ff` (nonexistent) |
| `GET /collections/<another user's id>` |
| `GET /collections/<soft-deleted id>` |

The same treatment covers `PATCH`, `DELETE`, `POST …/register`,
`DELETE …/registration`, and a Collection capture whose Collection is
missing, foreign, or soft-deleted: 404, no write, and never a redirect to
another tenant's resource.

## Refusals are not 404s

A lookup that succeeded and a rule that then refused is an ordinary reader
error, never a 404 and never a 500 or a raw exception page.
`Collection::LifecycleError` and validation failure both reach the reader as
the established alert copy or a concise field error.

| refusal | response |
|---|---|
| create with a blank or duplicate Topic | Index, New Collection form open, typed value preserved |
| locate with a blank/unknown/renamed-away/deleted/foreign Topic | Index, exact-Topic form open, `No Collection with that exact Topic.` |
| rename to blank or duplicate | same Collection page, persisted name unchanged |
| register an empty or already-indexed Collection | same Collection page |
| unindex an unindexed Collection | same Collection page |
| delete a Collection with any entry history | same Collection page |
| Collection capture the parser rejects | same Collection page |

Strong parameters permit only `name`. A raw `index_position` in the request
body is never admitted, and the domain guard from `collection-domain` refuses
it even if a parameter list is later widened by mistake.

## The Index screen — `GET /index`

Header, in source order:

1. `<h1>Index</h1>` — first visible text on the page;
2. the context line `Your collections` directly beneath it;
3. one New Collection control, at least 44×44 CSS px.

Body: one link per registered Topic, in `index_position` order, each at least
44 CSS px high, showing the Topic and nothing else. No entry counts, no dates,
no snippets, no tags, no ranking, no automatic sections.

Empty state: `Nothing indexed yet.` followed by the New Collection gesture.
It does not reveal unindexed Topics.

New Collection is a disclosure revealing one labelled Topic field and a Create
button. Success opens the new, empty, unindexed Collection page. Refusal keeps
the Index with the form open and the typed value preserved.

Open by Topic is a separate disclosure, at least 44×44 CSS px, revealing one
exact-Topic field (`autocomplete="off"`) and an Open button. Nothing appears
while typing: no results, no candidates, no suggestions.

## The exact-Topic open gesture — `POST /collections/locate`

The server trims the submitted Topic and performs one case-insensitive
equality lookup inside `Current.user.collections.kept`. On a hit it redirects
to that Collection's canonical UUID URL, whether the Collection is indexed or
unindexed. Every miss — blank, unknown, renamed-away, soft-deleted, or owned
only by another user — returns the Index with the exact-Topic form open and
exactly `No Collection with that exact Topic.` No record, id, former name, or
tenant distinction is disclosed, and the responses are indistinguishable from
one another.

## The Collection screen — `GET /collections/:id`

Header, in source order:

1. `<h1>` carrying the Topic — first visible text on the page;
2. the context line directly beneath it: `Collection · indexed` when
   `index_position` is present, `Collection · not indexed` when it is NULL;
3. one Manage disclosure, at least 44×44 CSS px.

Body: the Collection's kept root residents in capture order, rendered through
the shared `entries/entry` partial, children recursing through
`children.kept`. In this slice they render **without** the action strip.

Empty state: `Nothing logged yet.` followed by `Add a first entry before
indexing.` The Add to Index control is absent, and a crafted register is still
refused by the domain guard.

Writing surface: the existing hidden write-on-page gesture, reusing
`entries/rapid_log_form` with all three kind controls. It stays reachable and
at least 44×44 CSS px when the page is empty. A Custom Collection has no
temporal admission boundary, so the surface is always open on a kept
Collection.

Registration controls, mutually exclusive and never a toggle that acts merely
because a disclosure opened:

| Collection state | control |
|---|---|
| no kept entry yet | neither |
| has a kept entry, unindexed | one Add to Index action |
| indexed | one Remove from Index action |

The view asks the very predicate `register!` enforces, so the control a reader
sees and the guard behind it are one rule.

Manage contains Rename. Delete appears inside Manage only for a Collection
that has never held an entry row, and requires confirmation. Once any entry
row has ever existed the control is absent, and a crafted delete is still
refused.

Successful rename, register, and unindex return to the same Collection page.
Successful deletion returns to the Index with a confirmation; revisiting the
old URL then renders the uniform missing state.

## Collection capture

The Collection writing surface submits to the existing entry capture action
with a Collection placement. The server resolves a kept, same-user Collection
from the request before calling `Entry.capture!`, and calls it with exactly:

```ruby
Entry.capture!(
  line,
  user:       Current.user,
  today:      @today,
  as_of:      @today,
  page_kind:  "collection",
  page_on:    nil,
  collection: @collection,
  default_kind: <the submitted kind>
)
```

- **A Collection capture needs no page date.** An absent or unparseable `on`
  parameter must not refuse it; only the Daily, Monthly, and Future placements
  judge a date.
- The parser may return `occurs_on` and `time_of_day`; both persist as ordinary
  attributes and neither becomes placement. `page_on` stays NULL and
  `collection_id` is the resolved Collection.
- A blank line remains a successful no-op that writes nothing, as on every
  other page.
- Success and refusal both keep the reader on that canonical Collection page.
- Capture never registers the Collection, never changes `index_position`, and
  never writes `hlc` or `server_seq`.
- An unresolvable, foreign, or soft-deleted destination Collection renders the
  uniform missing state and writes nothing.

## Chrome and the title-first invariant

The four-tab shell stays. Index becomes a real link and is the active tab on
the Index screen, the Collection screen, and the Collection-not-found screen.
Today, Month, and Future remain fixed peers; no Collection is ever promoted
into the tab bar.

**Page-header order is invariant across the app**: the page title is the first
visible text and the first heading in source order, and any descriptor, date,
kind, or status sits directly underneath it. Monthly Log and Future Log already
comply. The Daily Log is the one exception, so this slice reverses its heading
and viewed-date order — `<h1>Daily Log</h1>` first, the day eyebrow beneath it
— changing no wording, no navigation, and no behavior. Adjust the stylesheet
only as far as that reversal requires.

## Visual and layout rules

Use only the existing paper / Tokyo Night custom-property tokens and hand
settings. Add no literal palette value, font family, shadow, or background
fork. Every visible text role — headings, entries, context lines, tabs,
buttons, action labels, fields, metadata — uses the reader's currently selected
hand face exactly as the rest of the app does. A slot on the mono stack still
puts the hand face first and keeps monospace only as a glyph fallback, not as a
second visible type treatment.

**One token does not yet satisfy that last sentence.** `:root[data-hand="sans"]`
sets `--font-mono` to the monospace fallback with no hand face in front of it,
and has since before this slice. Fix that token rather than forking a new one
for these screens — see `b2-collection-pages-corrections.md`, correction 1.

At 390×844 and at 320 px wide, on both the Index and Collection screens: no
horizontal scrolling, no clipped Topic, no covered writing control, and no
collision with the fixed tab bar. Every button, link, disclosure, and input
action target is at least 44×44 CSS px with visible keyboard focus and truthful
`aria-expanded` / `aria-current` state.

```text
LIGHT · INDEX                         DARK · COLLECTION
┌──────────────────────┐             ┌──────────────────────┐
│ Index          [New] │             │ Camping Trip     [⋯] │
│ Your collections     │             │ Collection · indexed │
│──────────────────────│             │──────────────────────│
│ Camping Trip       › │             │ • reserve campsite   │
│ Reading List       › │             │ – call after 5       │
│ [Open by Topic]      │             │                      │
│                      │             │   write-on-page area │
│                      │             │                      │
│ Today Month Future ● │             │ Today Month Future ● │
└──────────────────────┘             └──────────────────────┘
```

## Ruled browser flows for this slice

These are the accepted spec's flows 1, 2, 3, 4, 8, 9, and its layout review
restricted to the screens this slice ships. Flow 5 belongs to
`collection-commands`; flows 6 and 7 to `move-to-collection`.

1. A first-time reader opens the now-live Index tab, sees no automatic
   Collection rows, creates `Camping Trip`, and lands on its empty, unindexed
   page. The empty page offers no Add to Index and refuses a crafted register.
2. The reader captures a task, an event, and a note on that page. They appear
   only there, a reload preserves capture order, and Add to Index appears only
   once content exists.
3. Add to Index returns to the page, whose context line now reads
   `Collection · indexed`, and the Index then lists `Camping Trip`. Creating,
   filling, and registering `Reading List` appends it below. Rename preserves
   order; Remove from Index hides only that row; re-registering appends it at
   the end.
4. An unindexed Collection never appears on the Index. Typing its complete
   Topic into Open by Topic opens it. Partial, fuzzy, entry-text, deleted, and
   foreign-only queries all fail identically with no candidates.
5. A never-used Collection is deleted from Manage with confirmation, the reader
   returns to the Index, and the old route renders the themed 404. A Collection
   that has ever held an entry offers no Delete and refuses a crafted one;
   neither kept nor soft-deleted entries are cascaded.
6. Malformed, nonexistent, soft-deleted, and another user's Collection ids all
   render the same 404 inside Index chrome. Cross-tenant show, capture, rename,
   register, unindex, delete, and locate probes reveal no Topic or entry text
   and change no row.
7. The populated Index and the writable Collection are inspected in light and
   in dark — both screens in both themes — and at two hand settings, at phone
   width, together with the empty Index, the empty Collection, the exact-Topic
   miss, and the not-found state. Existing Today, Month, Future, capture,
   lifecycle, and tab flows stay green, including the Daily Log after its
   heading reversal.

## Required tests

Fast lane, controller and view level. Fixtures and real rows; fixed dates or
`travel_to`; no doubles for Rails, the clock, or Active Record; counts and
setup relative to fixtures, never to absolute database totals.

- Every route in the table above, exercised through the current user's kept
  scoping, and each of the four uniform-404 probes per route: status 404, the
  themed body, no write, no id or Topic echoed, no cross-tenant redirect.
- Each refusal row in the refusals table: status, destination, alert or field
  error, and the persisted record unchanged after `reload`.
- Create: trimming, the unindexed result, and the redirect to the new page.
- Locate: exact hit on an indexed and on an unindexed Collection; the five
  miss shapes producing one identical response; no candidate list in the body.
- Register and unindex through the web: the position after each, and that the
  view's control matches the guard for empty, nonempty, indexed, and unindexed
  Collections.
- Delete: success on a never-used Collection sets only `deleted_at`; refusal on
  one with kept-only, soft-deleted-only, and mixed entry history leaves every
  row intact.
- Index rendering: registration order, absence of Daily/Monthly/Future pages,
  absence of unindexed Topics, the empty state, and the tenant boundary.
- Collection rendering: kept roots in capture order, recursive kept children,
  no `occurs_on` leakage, the two context-line variants, the empty state copy,
  and — pinning this slice's read-only treatment — **no entry action strip and
  no lifecycle control in the body**. `collection-commands` supersedes exactly
  this expectation and nothing else.
- Capture: all three root kinds through `Entry.capture!`, asserting the exact
  placement tuple (`page_kind` `"collection"`, `page_on` NULL, the resolved
  `collection_id`), the same-user guard, an absent and an unparseable `on`
  parameter both capturing successfully, a blank line as a no-op, parser
  `occurs_on`/`time_of_day` persisting without becoming placement, and
  `index_position`, `hlc`, and `server_seq` unchanged.
- The tab bar: Index is a link, and is the active tab on all three screens.
- The title-first invariant: on Index, Collection, not-found, Daily, Monthly,
  and Future, assert the first heading in source order is the page title and
  that any context line follows it.
- Retain every existing 1.5.1a Future and Collection crafted-request assertion
  unchanged.

System lane covers the seven ruled browser flows above. It asserts absent
controls **and the server refusal behind each**, exact URL, status, and flash
destinations, the active tab, 44 px targets, the uniform tenant-safe
missing state, both themes on both new screens, and narrow-phone layout.

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
- `jscpd --min-tokens 50 --reporters console app/ lib/` — zero clones. The new
  screens share the existing entry, tab-bar, and rapid-log partials rather than
  copying them.
- `lib/` untouched, so `Bujo::RapidLog*` mutation remains exactly 1105/1105.

Hand-mutate at least these and show each is killed by an assertion that
explains the product failure, not by an incidental exception:

- drop `kept` from the Index query, and from the show lookup;
- drop the tenant scope from the show, capture, rename, register, unindex,
  delete, and locate lookups, one at a time;
- make the locate lookup a prefix or substring match;
- let the missing-Collection response echo the requested id or Topic, or
  return 200 instead of 404;
- render Add to Index on an empty Collection;
- render Delete on a Collection with entry history;
- register the Collection as a side effect of a successful capture;
- let a Collection capture refuse when `on` is absent;
- send a lifecycle refusal to the 404 page instead of back to the Collection.

## The approved mock delta — operator work, not swarm work

The accepted spec's one approved artboard, `IndexCollection.dc.html` plus its
`canvas.json` entry, belongs in the separate `bujo-mockups` repository. No role
in this swarm edits a file outside its own worktree, so no role produces it.
Implement the layout from the ruling and the review grid above and report the
mock as outstanding operator work in the handoff.

## Handoff

Commit, `git_handoff` to `coder`, task `collection-pages`, priority `50`.
