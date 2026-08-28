# Daily Reflection: QA pass 1 corrections

Status: **CORRECTION SPECIFICATION, 2026-08-28.** Continue under the stable
`daily-reflection` task name. The approved contract at
`docs/slices/1.5.4-daily-reflection.md` remains binding and unchanged; this
companion makes its existing keyboard-focus and phone-presentation gates exact.
If the two documents conflict, the approved contract wins.

QA commit `fc77508136` is a finding, not a terminal candidate. Its automated
lanes passed, but an independent headless-Chrome probe found three real focus
failures, and the committed system suite does not exercise the required focus
or presentation-state matrix. This is a defect in the delivered code and tests,
not a new product decision.

## Classification and boundary ruling

The current candidate fails observable behavior in three places:

1. changing Morning to Evening leaves `document.activeElement` on `BODY`;
2. successful Morning capture leaves focus on `BODY`; and
3. opening Evening Schedule hides the focused `Schedule…` button without
   moving focus into the visible date step.

The accepted path fence remains sufficient. Scoped server-rendered views and
controllers can own response focus, and scoped markup may compose existing
focus-capable Stimulus behavior. `app/javascript/**` remains out of scope; no
new focus controller or edit to an existing controller is authorized.

The cleaner extracted the two modes' repeated capture markup into
`app/views/daily_reflections/_capture.html.erb`. This focused partial composes
the shared `entries/_rapid_log_form` rather than forking capture behavior, so it
is now explicitly admitted before correction coding begins. It joins the five
partials named by specifier commit `cb65665405`; no other new partial or test
support file is admitted.

## Exact focus contract

Every path below is driven through the real keyboard trigger. After navigation
or a Turbo response settles, the named target is `document.activeElement`, is
visible in the viewport, and has the app's visible focus treatment. Focus on
`BODY`, on a hidden element, or on an element covered by the fixed tab bar is a
failure.

| Reader action | Required settled focus and state |
|---|---|
| Activate **Evening** from Morning | The visible Evening mode control, with `aria-current="page"` |
| Activate **Morning** from Evening | The visible Morning mode control, with `aria-current="page"` |
| Submit a valid Morning capture | `What surfaced overnight?`, empty and ready for another line |
| Submit a valid Evening capture | `What did you miss?`, empty and ready for another line |
| Refuse capture in either mode | That mode's capture field, with the submitted line and selected kind preserved; the alert remains after the sole `h1` |
| Mark or clear priority successfully | The originating Entry toggle, collapsed with truthful `aria-expanded="false"`; signifier and order are recomputed |
| Refuse a priority command while its row remains actionable | The originating collapsed Entry toggle |
| Refuse a stale priority command after its row is no longer in Morning | The current Morning mode control; no missing focus target is attempted |
| Complete an Evening task | The changed resident row, now showing full-ink `x`, without adding a permanent sequential tab stop |
| Strike an Evening task | The changed resident row, now showing thick full-ink strike treatment, without adding a permanent sequential tab stop |
| Open **Schedule…** | The visible native `Schedule for` date input, not the now-hidden trigger |
| Cancel Schedule | The originating Entry toggle; its ordinary action strip is visible and its expanded state is truthful |
| Schedule successfully | The changed predecessor row with its persisted movement glyph and destination, without adding a permanent sequential tab stop |
| Refuse Schedule while the row remains actionable | The originating collapsed Entry toggle, with the alert visible and no successor |

When a Complete, Strike, Schedule, or stale command cannot leave the named row
visible, focus falls back to the current mode control. The fallback is part of
the contract: response focus never points at a row that live recomputation
removed.

Response focus is ephemeral navigation behavior. It creates no reflection,
Entry, cookie, local-storage value, URL-authored placement, saved expanded row,
or persisted mode. Refresh without a new command returns to the ordinary live
lens and does not replay an earlier focus instruction.

## Keyboard acceptance flow

The system test must cover one real keyboard walk rather than merely calling
`click` and checking that a page eventually rendered:

1. enter Morning through **Reflect**, Tab to **Evening**, and activate it with
   the keyboard; assert the active Evening control owns focus;
2. return to Morning by keyboard and assert the active Morning control owns
   focus;
3. type and submit a valid Morning line from the field; assert the cleared
   field owns focus;
4. submit a refused Morning line after choosing Event; assert the same field
   owns focus and both the line and Event selection survive;
5. reveal one Morning task, activate Mark and then Clear priority by keyboard,
   and assert the collapsed originating toggle owns focus after each return;
6. in Evening, reveal and activate Complete, then Strike on separate tasks;
   assert each changed resident row owns visible focus after return;
7. reveal another task and activate **Schedule…**; assert the native date field
   owns focus, then keyboard-cancel and assert the Entry toggle owns focus;
8. reopen Schedule, submit an inadmissible date, and assert the collapsed Entry
   toggle owns focus with no successor;
9. schedule a valid same-month task and a valid later-month task, asserting
   focus on each changed predecessor row as well as the existing Calendar and
   Future successor rules; and
10. repeat capture focus in Evening so neither mode succeeds only by accident.

Reading `document.activeElement` or computed focus styles from JavaScript is an
observation and is allowed. JavaScript must not focus, click, or submit the
control under test. A native date value may still be populated through the
existing headless-browser helper; opening, cancellation, and submission remain
real keyboard gestures.

## Required phone-state matrix

The present system test covers Morning only in light/Rock Salt and Evening only
in dark/Architects Daughter. That pairing cannot prove the approved opposite
themes, stateful controls, refusals, or both widths. Each state below must be
rendered under all four profiles:

1. 390px light / Rock Salt;
2. 320px light / Architects Daughter;
3. 390px dark / Architects Daughter; and
4. 320px dark / Rock Salt.

These four profiles give every state both approved phone widths, both palettes,
and two non-sans hands without inventing an unnecessary eight-profile product
matrix.

| State | Required visible evidence |
|---|---|
| Morning populated | Title/date/mode/capture, ruled source links, complete long nested context, open count, active Today |
| Morning priority selected | Selected-row background, truthful expanded toggle, exactly Mark or Clear priority, stable Entry geometry |
| Morning empty | Exact empty copy plus the available `What surfaced overnight?` form |
| Morning refusal | Alert after the title, preserved long line and selected kind, focused field |
| Evening populated | Mixed complete Daily tree, full glyph/meta/nesting, positive derived progress and closing prompt |
| Evening action strip | One selected open task with exactly Complete, Strike, and Schedule; no broad source-page commands |
| Evening Schedule step | Full-size native date field, Schedule and Cancel below it, focused field |
| Evening empty | Exact empty copy plus the available `What did you miss?` form and zero progress number |
| Evening refusal | Alert, unchanged actionable row, no successor, and the ruled focus return |

For every profile and state, assert all of the following rather than relying on
a screenshot alone:

- no horizontal document overflow, clipped authored text, source label, field,
  action, or metadata;
- no visible control smaller than 44x44 CSS px;
- no content or focused target covered by the fixed tab bar after scrolling;
- exactly one title-first `h1`, accurate `aria-current`, `aria-expanded`, and
  `aria-pressed`, and Today active;
- complete long Entry text, nested descendants, glyphs, metadata, selected-row
  treatment, and native date anatomy; and
- the requested theme and hand on the document, with representative title,
  copy, fields, actions, entries, preferences, and tabs resolving through the
  selected hand tokens.

Screenshots may supplement these assertions, but do not replace them. Sample
dates and words remain illustrative exactly as the approved mock rules.

## Fast-lane and adversarial coverage

Keep every landed domain, membership, tenant, return-allowlist, and command
matrix assertion. Add only focused request tests needed to prove that success,
refusal, and stale fallbacks provide enough response state for the browser to
land on a visible target. Tests continue to use real rows from
`Current.user`'s relations and must prove no focus hint can authorize an Entry,
page, mode, placement, or return URL.

The corrected system assertions must fail under at least these plausible wrong
behaviors:

- current mode renders accurately but focus falls to `BODY`;
- successful capture clears the field but leaves focus at the page root;
- capture refusal restores text but not kind or focus;
- priority return names a task that live recomputation removed;
- Complete, Strike, or Schedule success focuses a hidden former toggle;
- Schedule reveals its date step while focus remains on hidden `Schedule…`;
- Cancel rewinds the step but not focus; and
- a phone test silently drops one mode, palette, width, selected state, empty
  state, refusal, or one of the two required hands.

Do not weaken or delete the 107 landed system flows to make the new assertions
green. The focused tests are added first and must reproduce QA's current focus
failures before production correction.

## Correction scope

The approved 1.5.4 path fence remains the maximum implementation scope. The
expected correction is bounded to its existing Daily Reflection controllers,
views, shared form/action partials, page-owned stylesheet, and named controller
and system tests. In particular:

- `app/views/daily_reflections/_capture.html.erb` may remain as the newly named
  focused composition partial;
- `app/views/entries/_rapid_log_form.html.erb` and
  `app/views/entries/_task_actions.html.erb` may accept focus-related locals or
  markup only while all non-Reflection callers remain behaviorally unchanged;
- new focus presentation belongs only to
  `app/assets/tailwind/pages/daily-reflection.css`; and
- test changes stay in the already named 1.5.4 controller/system/source files.

Do not edit `app/javascript/**`, add a test helper, add another partial, or
change Entry lifecycle, priority, movement, residency, auth, schema, parser,
sync, dependency, deployment, planning authority, the approved mock, or frozen
Tailwind T0 artifacts. If the correction genuinely cannot meet the focus table
without one of those changes, stop and return to specifier rather than widening
silently.

## Terminal gates

The whole corrected candidate, not only the focused tests, must pass the
approved terminal battery again:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
```

Every method remains at CRAP <= 6, duplication remains zero, and the unchanged
RapidLog receipt remains exactly 1105/1105. Passing QA is terminal only for the
isolated implementation candidate; operator verification and Dan's separate
integration approval remain mandatory.

## Non-goals

- no new global focus manager, JavaScript controller, keyboard shortcut, modal,
  live region framework, or client-side router;
- no persisted focus, mode, expanded row, reflection session, completion, or
  progress state;
- no redesign of the approved mode switch, capture form, Entry row, action
  strip, Schedule step, themes, hands, tab bar, copy, or mock;
- no widening of commands in either Reflection mode or narrowing of the source
  Daily page; and
- no unrelated accessibility, Tailwind, authentication, sync, PWA, deployment,
  or planning work.
