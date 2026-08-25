# 1.5.2b (pass 2) — Corrections to `collection-pages`

Task name: `collection-pages` — the same name. This is a second verification
pass at the same slice, not new work, so the pack article's bound on routing
back keeps counting.

Qa's pass-1 finding is at `01ce36ad97`. It raised two discrepancies. Both are
real; I checked each against the code rather than against the summary. One is
a defect in the specification I wrote, one is a defect in the delivered work.
Everything else qa verified — domain gestures, tenant scoping, capture
placement, lifecycle refusals, the uniform missing response — stands as
delivered and must stay green.

Read this together with `b-collection-pages.md`, which is otherwise unchanged.

---

## Correction 1 — the `sans` hand's mono slot. My specification was wrong.

**The facts.** `:root[data-hand="sans"]` sets
`--font-mono: var(--font-mono-fallback)` — JetBrains Mono with no hand face in
front of it. Every other hand puts its face first and keeps the monospace
stack only as a glyph fallback. That line is byte-identical at `5b94ce413e`,
before this slice began; it is pre-existing and app-wide, and it already
affects the Daily eyebrow, the day navigation, entry meta, the monthly views,
and the tab bar. The new Collection context line and Index-active tab inherited
it by correctly using the same token.

**Why this is my defect.** `b-collection-pages.md` required both "use only the
existing paper / Tokyo Night custom-property tokens and hand settings; add no
literal font family" and "a slot on the mono stack still puts the hand face
first." Under the `sans` hand those two sentences cannot both be satisfied.
The coder followed the existing tokens, which is what I told them to do, and my
own second requirement then made that a violation. Qa was right to fail it and
right about where it shows.

**The ruling.** Fix the token, not the screens. In
`app/assets/stylesheets/application.css`:

```css
:root[data-hand="sans"] {
  --font-body: "Public Sans", var(--font-body-fallback);
  --font-serif: "Public Sans", var(--font-body-fallback);
  --font-mono: "Public Sans", var(--font-mono-fallback);   /* was: no hand face */
}
```

One line. It is inside the accepted file scope, it introduces no new font
family — `Public Sans` is already named twice in that same block — and it makes
the `sans` hand consistent with the five hands beside it.

**It deliberately changes existing screens too.** Under the `sans` hand the
Daily eyebrow, day navigation, entry meta, monthly views, and tab bar will stop
mixing JetBrains Mono into a Public Sans page. That is the accepted spec's
visual clause applied where it actually lives, and it is in scope precisely
because the token is the one the new screens consume. Do not instead fork a
new token for the Collection screens; that would be the second visible type
treatment the accepted spec forbids.

**Tests.** In the acceptance lane, with `data-hand="sans"` selected, assert the
computed `font-family` of a mono-stack slot begins with `Public Sans` — using
the existing computed-style idiom that `title_font_family` already
demonstrates in `test/system/daily_log_test.rb`. Assert it on **both**:

- a new screen — the Collection context line, or the Index-active tab; and
- an existing screen — entry meta or the day navigation,

so the fix is pinned app-wide rather than only where this slice looked. The
existing hand-cycle test compares only the title face and stays green as
written; do not weaken it.

---

## Correction 2 — the acceptance lane is short. This is a defect in the work.

**The facts.** `b-collection-pages.md` requires the system lane to cover seven
ruled browser flows. `test/system/collection_pages_test.rb` has five scenarios.
Controller coverage is genuinely strong — seventeen tests, and qa's HTTP probes
passed — but my specification asked for both lanes, and the accepted spec asks
for the acceptance lane by name. Specified behavior with no acceptance test is
exactly the finding qa is meant to catch.

**The ruling.** Keep the five scenarios that exist and add these. Numbering
continues from the file's current scenario 5.

### 6 — empty and refused states, at phone width, in both themes

At 390×844 and at 320 px wide, in light and in dark:

- the empty Index shows `Nothing indexed yet.` and the New Collection gesture,
  and shows no unindexed Topic;
- an empty Collection shows `Nothing logged yet.` and
  `Add a first entry before indexing.`, offers **no** Add to Index control, and
  still offers a reachable 44 px writing gesture;
- an exact-Topic miss returns to the Index with
  `No Collection with that exact Topic.`, the exact-Topic form still open, and
  no candidate list, suggestion, or partial match anywhere in the page;
- the not-found screen shows `Collection not found` as its first heading, a
  44 px Back to Index link, and the Index tab active.

No horizontal scrolling and no collision with the fixed tab bar in any of them.

### 7 — the deletion boundary as a reader sees it

- a Collection that has never held an entry offers Delete inside Manage,
  deletes with confirmation, returns to the Index, and its old URL then renders
  the missing screen;
- a Collection that holds a kept entry offers **no** Delete;
- a Collection whose only entry has since been soft-deleted **still** offers
  none, and its entry rows are still present afterwards.

### 8 — cross-tenant invisibility, driven through the browser

Signed in as the second user:

- the first user's Collection URL renders the same missing screen, with no
  Topic and no entry text anywhere in the response;
- the Index lists only the second user's registered Topics;
- Open by Topic with the first user's exact Topic misses with the same copy as
  any other miss.

### 9 — crafted gestures no control offers

For each of: register on an empty Collection, delete on a Collection with entry
history, rename to a duplicate Topic, and a capture naming a foreign
Collection — issue the request from the loaded page using its own CSRF token,
then assert the reader-facing outcome and that no row changed.

**If the driver cannot issue such a request, say so plainly in the commit body
and cite the controller tests that already pin each refusal as the evidence.**
An honest blocker is the correct outcome there; silently dropping the scenario
is not, and neither is inventing a result.

---

## Out of scope for this pass

Nothing else changes. Do not touch the domain, the routes, the controllers, or
the views beyond what these two corrections require — every other part of
`collection-pages` verified clean and must stay that way. `collection-commands`
and `move-to-collection` remain later slices. `lib/`, `Gemfile`, and `PLAN.md`
remain untouched.

The two system-test race fixes qa applied — the Daily open-count wait and the
placement preference-redirect waits — are unrelated to this slice and stay.

## Quality bars

Unchanged from `b-collection-pages.md`: both Minitest lanes green in this
worktree, `bin/rubocop` clean, fresh coverage with every measured method at
CRAP ≤ 6, jscpd zero clones, and `Bujo::RapidLog*` mutation still exactly
1105/1105.

## Handoff

Commit, `git_handoff` to `coder`, task `collection-pages`, priority `50`.
