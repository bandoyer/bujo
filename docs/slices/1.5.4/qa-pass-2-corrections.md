# Daily Reflection: QA pass 2 viewport corrections

Status: **SECOND AND FINAL ROUTED CORRECTION SPECIFICATION, 2026-08-28.**
Continue under the stable `daily-reflection` task name. The approved contract
in `docs/slices/1.5.4-daily-reflection.md` and the focus table in
`docs/slices/1.5.4/qa-pass-1-corrections.md` remain binding. This companion
only makes the already-required “visible in the viewport and not covered by
the fixed tab bar” result measurable. The approved contract wins any conflict;
this companion wins only for the bounded meaning of a changed Entry's focus
target described below.

QA commit `252eb99559` is verification pass 2 and a finding, not a terminal
candidate. It proves that the response now gives focus ownership and an
outline to the named control, but that browser focus can settle below the
viewport or behind the fixed tab bar. This is a delivered code defect and a
previously missing permanent geometry assertion, not a new product decision or
a change to Reflection membership, commands, or persistence.

## Reproduced defect and governing invariant

The four-profile probe measured the focused element after the response had
settled:

| Flow and profile | Observed result |
|---|---|
| Morning capture refusal, 390px light / Rock Salt | Passes: target bottom 589.20px, tab bar top 636px |
| Priority success, 320px light / Architects Daughter | Fails: target top 730.91px and bottom 774.91px in a 701px client viewport |
| Schedule open, 390px dark / Architects Daughter | Fails: date input top 845.22px and bottom 889.22px |
| Schedule refusal, 320px dark / Rock Salt | Fails: target top 1342.08px and bottom 1684.08px |

The permanent Daily Reflection system file now reports 17 runs, 418
assertions, and three failures with the required geometry check. The Schedule
input ends at 973.98px in a 701px client viewport, while the changed-row focus
targets in the two keyboard-response flows end at 663.02px behind tabs that
begin at 636px. Those red assertions are the acceptance starting point; they
must not be removed, bypassed, or relaxed.

After every response-focus path settles, without a test or reader issuing an
extra scroll, all of these conditions are true:

```text
target = document.activeElement.getBoundingClientRect()
tabs   = document.querySelector(".tab-bar").getBoundingClientRect()

target.top    >= 0
target.bottom <= document.documentElement.clientHeight
target.bottom <= tabs.top
```

The client viewport reported by the browser is authoritative; the test must
not assume that an outer 390x844 browser window has an 844px document viewport.
The target also remains horizontally inside the client viewport, and its full
focus treatment is visible rather than clipped by a viewport edge or painted
under the tabs. The rectangle checks above are the minimum automated invariant,
not permission to hide the outline's width or offset.

Focus arrival and viewport arrival are one settled behavior. It is a failure
for the correct element to own `document.activeElement` while remaining out of
sight, for browser scroll restoration to undo its placement, or for a test to
call `scrollIntoView`, `scrollTo`, or equivalent after the response.

## Exact target geometry

The focus ownership table from pass 1 is unchanged. Its targets now have these
bounded boxes:

| Response | Box that must satisfy the viewport invariant |
|---|---|
| Mode change | The active Morning or Evening mode control |
| Capture success or refusal | The visible capture field |
| Priority success or actionable refusal | The originating collapsed Entry toggle |
| Complete or Strike success | The changed Entry's own visible line, not its descendant subtree |
| Schedule open | The native `Schedule for` date input |
| Schedule cancel or actionable refusal | The originating Entry toggle |
| Schedule success | The predecessor Entry's own visible line, not its descendant subtree |
| Removed-row fallback | The current mode control |

“Changed resident row” in pass 1 means the changed Entry's own line: its glyph,
full text, priority signifier when present, and metadata. Nested descendants
remain rendered as required context, but their potentially unbounded height is
not part of the transient focus receiver's rectangle. Complete, Strike, and
Schedule therefore cannot satisfy this correction merely by focusing a branch
container whose bounds include every descendant. The own-line target identifies
the changed Entry to assistive technology, receives the visible focus treatment,
and is programmatically focusable for this response only; it never becomes a
permanent sequential tab stop.

Changing the permanent system selector from a whole-tree container to the
Entry's own-line focus receiver is allowed when needed to encode that exact
meaning. The change must retain the same Entry identity, active-element check,
outline check, and geometry assertions. It is not permission to focus an empty,
one-pixel, off-screen, or otherwise artificial proxy.

When Schedule opens, the input is the active target and the complete visible
step—label, full-size native field, Schedule, and Cancel—must remain clear of
the tab bar at both phone widths. When Schedule cancels or is refused, the
ordinary row state and truthful toggle return from pass 1 remain visible. A
successful movement leaves the predecessor's own line in context with its
persisted movement glyph and destination; it does not collapse, omit, or
reorder the qualifying tree to make the geometry pass.

The same visible-target result is required for every flow already named by the
pass-1 focus table, including the paths that happened to pass QA's sample
measurements. No command may regress capture, mode change, priority refusal,
Schedule cancel, either Schedule destination, or stale-row fallback while
repairing the three measured failures.

## Navigation and presentation constraints

The application, not the acceptance test, owns any scroll adjustment required
by response focus. The final position must be established after navigation and
layout settle, including the selected hand's wrapping and the fixed tabs' real
rectangle. The result must not depend on the target having been above the fold
before the command.

The fixed four-tab bar stays fixed, keeps Today active, and is not moved,
shrunk, hidden, or given a different stacking role to manufacture a pass. The
page may not collapse authored Entry text, discard descendants, reduce a 44px
control, change the selected hand, or introduce horizontal overflow to shorten
the page. Long wrapping content and deeply nested qualifying trees remain
complete.

Response placement remains transient. A refresh without another command does
not replay it, and no focus or scroll instruction is saved to an Entry,
reflection, preference, cookie, local storage, or session. The settled Morning
and Evening locations remain their canonical paths; no focus-only query or
fragment is left in the address bar. Mode, expanded-row, and Schedule-step
state remain exactly as ruled in pass 1.

## Acceptance examples

1. At 320px light / Architects Daughter, put enough long nested Morning
   content before a priority-eligible task that the task's returned toggle
   would begin below the client viewport without correction. Activate Mark and
   Clear priority through the keyboard. After each response the collapsed
   originating toggle owns focus, its entire rectangle and outline are above
   the tabs, the signifier is truthful, and no test-side scroll occurs.
2. At 390px dark / Architects Daughter, open Schedule on a Daily task whose
   form begins below the fold. The native date field owns focus and the full
   Schedule step is visible above the tabs. Keyboard Cancel returns to the
   unobscured originating toggle.
3. At 320px dark / Rock Salt, refuse an inadmissible Schedule date after a
   long nested tree. The alert and unchanged Entry remain, no successor exists,
   and the collapsed originating toggle is automatically visible above the
   tabs despite the selected hand's extra wrapping.
4. Complete and Strike separate Evening tasks whose old action controls sit
   near the tab boundary. Each response focuses the changed Entry's bounded own
   line with the correct `x` or strike treatment; descendants stay present and
   the target bottom is no lower than the tab bar top.
5. Repeat the already-passing 390px light / Rock Salt capture refusal. The
   preserved field, selected Event kind, alert, focus outline, and unobscured
   geometry continue to pass, proving the repair is not special-cased to Entry
   rows.

## Permanent test requirements

Keep QA's Evening capture-refusal coverage and the geometry checks now in
`test/system/daily_reflection_test.rb`. The corrected system lane must:

- exercise real keyboard triggers and wait for the final response target;
- inspect `document.activeElement`, computed outline, the target rectangle,
  the client viewport, and the real `.tab-bar` rectangle;
- perform no JavaScript focus, click, submit, scroll, element repositioning,
  or tab-bar hiding in test setup or assertions;
- make the relevant target begin below the fold or near the tab boundary, so a
  focus-owner-only implementation still fails;
- retain the four profiles from pass 1 for every required phone state: 390px
  light / Rock Salt, 320px light / Architects Daughter, 390px dark /
  Architects Daughter, and 320px dark / Rock Salt;
- retain no-horizontal-overflow, 44x44 controls, full authored content, theme,
  hand, accessibility-state, and fixed-tab assertions; and
- prove the final URL and persisted records contain no focus or scroll state.

The incoming 17-run focused file must move from its three geometry failures to
green because production behavior changed. Do not delete an assertion, shrink
the fixture tree, pre-scroll the browser, substitute a shorter hand, or weaken
the target from the Entry's meaningful own line to make it pass. Keep all
landed controller, membership, tenant, return-allowlist, movement, and command
matrix coverage.

## Correction scope

The approved 1.5.4 path fence remains the maximum. This correction is expected
to touch only the already admitted Daily Reflection controllers and views,
shared Entry form/action markup where Reflection supplies a scoped local,
`app/assets/tailwind/pages/daily-reflection.css`, and the named controller and
system tests. Existing
`app/views/daily_reflections/_capture.html.erb` remains the only partial added
by the correction chain.

Do not edit `app/javascript/**`, add inline application JavaScript, add another
partial or test-support file, or change the Entry model, lifecycle, residency,
movement chain, priority semantics, schema, parser, sync, authentication,
dependencies, deployment, planning authority, the approved mock, or frozen
Tailwind T0 artifacts. Shared markup changes must leave every non-Reflection
caller behaviorally unchanged. If unobscured settled focus cannot be achieved
inside that fence, stop and return the contradiction rather than widening it.

## Terminal gates and routing bound

The whole corrected candidate must pass the approved terminal battery:

```sh
bin/rails test
bin/rails test:system
bin/rubocop
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
```

Every method remains at CRAP <= 6, duplication remains zero, and the unchanged
RapidLog receipt remains exactly 1105/1105. QA's next review is verification
pass 3 for `daily-reflection`: it either passes and sends the isolated terminal
broadcast, or QA stops and puts the situation to the user. The pack permits no
third finding/reslice under this task name.

A passing QA broadcast remains terminal only for this isolated implementation
candidate. No swarm role integrates, rebases, pushes, deploys, or edits planning
authority; operator verification and Dan's separate explicit integration
approval remain mandatory.

## Non-goals

- no redesign of the approved page, focus table, commands, copy, themes,
  hands, tab bar, or responsive content;
- no global focus or scroll manager, new Stimulus controller, keyboard
  shortcut, persisted scroll restoration, client router, or animation system;
- no hiding, truncating, virtualizing, or flattening long nested Entry trees;
- no new Reflection state, session, preference, model, migration, or service;
  and
- no unrelated accessibility, Tailwind, authentication, sync, PWA,
  deployment, integration, or planning work.
