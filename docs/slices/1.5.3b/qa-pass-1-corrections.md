# Slice 1.5.3b — QA pass 1 corrections

Task: `dogfood-entry-corrections`

Finding count: **1 of at most 2 routable findings**
Finding baseline: QA commit `c1b2c3774938707f552670ebdb13dc96a6e11d8b`

This is one bounded follow-up to the approved contract in
`docs/slices/1.5.3b-dogfood-entry-corrections.md` and its source-alignment
companion. The approved contract and mock remain unchanged and outrank this
file if they can be read differently. Every original non-goal and forbidden
surface still binds.

## Specifier ruling

**The defects are in delivered code and acceptance coverage, not in the
specification.** The approved contract already requires all of the following:

- every current kept Entry can correct its words while children remain
  structurally valid on their persisted page;
- no visible copy appears above a page title;
- the native Schedule date field spans the available phone width with its
  actions below it; and
- the system lane browser-drives existing Event/Note and moved-live-end edits,
  invalid Edit, all seven ritual resolutions with Undo, and a stale second-tab
  Undo refusal.

QA found three observable contradictions and confirmed the named browser cases
are absent. The otherwise-green lanes do not waive those acceptance criteria.

The nested defect was independently reproduced after merging QA: a kept Note
child of a Future task reported `valid=true`, `kept=true`, and the correct
parent, then `Entry#correct!` refused a same-Note wording change with
`Entry::LifecycleError` and retained the old text.

## Acceptance criteria

This follow-up is complete only when all six criteria hold together:

1. A structurally valid Future Note child can correct its words and metadata
   while remaining a Note child on the same Future residency.
2. The editor always shows the current kind selected. For the Future Note
   child it shows Task, Event, and Note with only Note at
   `aria-pressed="true"`; it never presents no selected choice.
3. Root vocabulary remains closed: ordinary Future capture and Future roots
   still admit Task/Event only, and changing a Future Task/Event child to Note
   remains refused. Fixing the child must not add Note to Future root
   vocabulary.
4. Every refused Edit or Schedule on Daily, Monthly Calendar, Monthly Tasks,
   Future, or Collection keeps the page title as the first visible text and
   places the established alert after that title. A refused Edit remains open
   with its submitted line and truthful kind selection.
5. At 390px and 320px the native date field occupies the full available width
   of the Schedule step. Its visible label precedes it; Schedule and Cancel are
   on a later row beneath it; all three controls remain at least 44px high;
   the selected value is legible; and the document does not overflow.
6. The authoritative headless-Chrome lane exercises every correction and Undo
   case the approved contract names, including stale cross-tab refusal. It
   proves the durable row/chain result, not only visible confirmation copy.

## Correction semantics for nested residents

The page vocabulary is a rule for roots and for **changing** kind. It is not a
reason to reject an already-valid child's unchanged kind.

| persisted current row | requested kind | result |
|---|---|---|
| Future Note child, current live end | Note | allow words/metadata correction; preserve NULL state, parent, placement, and history |
| Future Note child, standalone in movement history | Task or Event | allow under the existing standalone kind-change rules |
| Future Task/Event child | Note | refuse atomically because Note is not a Future kind-change destination |
| Future root | Note | structurally impossible; capture/model refusal remains |
| any row with a successor | any | refuse as before |
| movement live end with a predecessor | its inherited kind | allow words/metadata correction as before |
| movement live end with a predecessor | another kind | refuse as before |

The model guard therefore distinguishes “keep this structurally valid current
kind” from “reinterpret this row as a page-admitted kind.” It must not broaden
`Entry::ROOT_KINDS["future"]` or the Future capture controls.

The inline controls mirror that rule:

- when kind change is allowed, offer the normal page-admitted destinations
  plus the row's current kind if a valid child already carries a narrower-page
  context kind;
- when kind change is locked, offer exactly the inherited/current kind; and
- in either case, exactly one rendered control matches the hidden
  `default_kind` and has `aria-pressed="true"`.

Worked browser example:

```text
Future task root · Sep 4
  – old child words

Edit child → [• false] [○ false] [– true]
Save "new child words +camp"

same child id · same parent · future / NULL page_on · kind note · state NULL
text "new child words" · tags ["camp"] · no successor
```

## Title-first refusals

The current global layout renders flash before each page's `<main>`. Collection
and Monthly Migration already defer it beneath their titles, while Daily,
Monthly, and Future do not. The correction applies the existing title-first
rule to every ordinary Entry return page rather than special-casing only the
reported Future screenshot.

For each resident page kind, a refused Edit must render in this source and
visual order:

```text
page title
page context/navigation, where present
That entry can't do that.
resident row with submitted Edit still open
```

The alert keeps `role="alert"`, the established copy, current theme/hand, and
canonical return URL. It must not be hidden, converted to a toast over the tab
bar, or moved before the heading by layout geometry. Schedule refusal follows
the same title-first rule. Success notices on the changed Collection page and
ritual confirmations remain where the accepted implementation already puts
them.

Fast render assertions cover Daily, both Monthly views, Future, and Collection
with an alert. A headless-Chrome refused Edit at each ruled phone treatment
asserts that the heading's DOM/source position and top edge precede the alert,
the editor stays open with submitted content, and no fixed-tab collision or
horizontal overflow appears.

## Full-width native Schedule geometry

The current field declares `width: 100%` but shares a two-column form row with
the Schedule submit, so the property does not satisfy the behavior. Acceptance
is measured geometry, not the presence of that CSS declaration.

At both `390x844` paper-light/Rock Salt and `320x844` Tokyo Night-dark/
Architects Daughter:

- the date field's left and right edges match the available Schedule form row
  within 1 CSS px;
- the Schedule and Cancel controls begin no higher than the field's bottom and
  therefore occupy the following action row;
- the field and both buttons are at least 44 CSS px high;
- setting an ISO date leaves that value visibly rendered in headless Chrome;
- the Entry glyph/text/meta origins do not change when opening the step; and
- `document.documentElement.scrollWidth <= clientWidth` with the fixed tabs
  clear.

The same real flow still proves last-later-current-month → Calendar and
first-next-month → Future, with `>`/`<` and canonical source return. Do not add
a JavaScript picker or replace Rails' `date_field`.

## Required headless-Chrome coverage

Add focused browser scenarios before changing production behavior. They may
share setup/assertion helpers, but every listed gesture goes through the real
rendered controls.

### Entry Edit

1. Edit an Entry that is already an Event; save changed words/date/time/tags
   and prove exact NULL state, same id, placement, parent/history fields, and
   canonical return.
2. Edit an Entry that is already a Note with the Note control selected; save
   changed words/tags and prove exact NULL state and stable structure.
3. Edit a moved current successor; prove only its inherited kind is offered,
   words/metadata change on that same live id, the predecessor and movement
   link remain, and no additional successor is created.
4. Edit a wrapped row and compare glyph/text/meta origins at rest, selected,
   and Edit-open states.
5. Exercise the Future Note child worked example above through the browser.
6. Submit blank or structurally invalid correction at both ruled phone
   treatments; prove title-first alert placement, retained submitted line,
   truthful selected kind, unchanged persisted bytes, focus/targets, and no
   overflow.

Controller/model coverage remains necessary but cannot substitute for these
browser flows.

### Monthly Migration Undo

Browser-drive each successful resolution and its immediately offered Undo:

| stage | resolution |
|---|---|
| outgoing | Strike |
| outgoing | target Monthly Tasks |
| outgoing | exact-Topic Collection |
| outgoing | Future date |
| due Future task | Strike |
| due Future task | target Monthly Tasks |
| due Future event | target Calendar |

For each row, assert the action-specific confirmation, click Undo, assert the
offer disappears, and verify the exact durable outcome: Strike returns the
same task to `open`; movement retains the first two rows and appends a third
UUIDv7 live end at the exact original placement/date/time with the ruled state.
The restored live end re-enters the derived candidate set when applicable.

Add one real stale-second-tab case:

1. in the first tab, move an outgoing task to target Monthly Tasks and retain
   its offered Undo;
2. in a second tab sharing the signed-in browser session, deliberately resolve
   that current successor (for example Complete it) through its ordinary page;
3. return to the first tab and click Undo;
4. assert `REFUSAL_ALERT` below the Monthly Migration title, no compensating
   third row, no fork/deletion, the second-tab result retained, and redirect to
   the recomputed canonical ritual stage.

A controller-level POST helper, direct model call, or manually inserted
successor is supplemental evidence and does not satisfy these system flows.

## Focused test-first implementation scope

Expected production correction is limited to:

- `app/models/entry.rb` for current-child-kind versus kind-change admission;
- `app/views/entries/_task_actions.html.erb` and the shared kind partial for
  truthful current-kind controls;
- the Daily, Monthly, Future, Collection, layout/flash view boundary needed to
  keep alerts below titles;
- the existing Entry action markup and
  `app/assets/stylesheets/application.css` for measured Schedule layout; and
- the focused model/controller/render/system tests above.

No Monthly Migration production change is expected: QA reported missing
browser coverage, not a proved Undo behavior contradiction. Write those system
tests first. If a required real-browser flow exposes a contradiction, fix only
that approved Undo behavior within the original 1.5.3b model/controller/view
scope and say exactly what failed in the commit body.

No new route, schema, migration, dependency, service/form/policy layer,
JavaScript calendar, persisted ritual state, or generic history/Undo UI belongs
here. Do not touch `PLAN.md`, `HANDOFF.md`, `docs/METHOD.md`,
`ARCHITECTURE.md`, the approved contract, its source-alignment companion, its
mock, `db/`, `lib/`, parser tests, Gem files, jobs, auth/email, deployment,
production data, sync, Daily Reflection, or Entry deletion.

## Required implementation gates

Before forwarding an implementation candidate, run and record:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
```

Every measured method stays at CRAP <= 6, jscpd reports zero clones, and the
unchanged parser remains 1105/1105. Hand-mutate at least the unchanged-current-
child-kind allowance, the Future kind-change refusal, the selected-current-kind
union, title-first flash deferral, full-width/below-field Schedule geometry,
one previously untested Undo action, and stale current-successor revalidation.
