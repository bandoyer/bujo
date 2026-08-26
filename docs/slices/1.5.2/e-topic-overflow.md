# 1.5.2e — An unbounded Topic must not widen a source page

Task name: `collection-topic-overflow`

An operator acceptance review of the terminal candidate at `a3ca631` found a
defect. This is the smallest corrective slice that closes it. The accepted
specification `docs/slices/1.5.2-custom-collections-and-index.md` is unchanged
and still governs, together with `docs/METHOD.md`, `PLAN.md`, and
`ARCHITECTURE.md` in that order. All five approved digital rulings stand. Every
1.5.2 non-goal stands.

## The defect

At 320 px, a Daily page horizontally overflows after Move to Collection when the
destination Topic is one long unbroken string: `document.scrollWidth` 2249
against `clientWidth` 305. Reproducer screenshot:
`tmp/screenshots/failures_test_long_Collection_destination_meta_stays_inside_a_320px_source_page.png`

The Topic renders through `app/views/entries/_meta.html.erb` into
`.entry__meta`, which is a flex child sitting in the fourth grid column of
`.entry__line`:

```css
.entry__line { grid-template-columns: 1rem 1.25rem minmax(0, 1fr) auto; }
.entry__meta { display: flex; flex-wrap: wrap; /* no wrapping rule for its own text */ }
```

An unbroken string has no break opportunity, so the `auto` track takes its
full width and the document grows past the viewport.

## Why this is a real defect, not a spec gap

Two accepted rulings combine into it, and both are binding:

- Topics are unbounded — *"Do not impose a new arbitrary length or character
  vocabulary in this slice."*
- The phone-state review requires that at 390×844 and at 320 px wide there is
  *"no horizontal scrolling, clipped Topic, covered writing control, or
  collision with the fixed tab bar."*

`move-to-collection` turned the Topic into a value that renders on Daily and
Monthly pages. The layout rule that already governs an unbounded Topic never
travelled with it.

**"No clipped Topic" is as binding as "no horizontal scrolling."** The fix is
to let the Topic wrap, not to truncate it. An ellipsis, a `text-overflow`
clip, a fixed `max-width` that hides characters, or a length cap in the model
each trade one violation for the other and are all refused.

## The rule already exists in this codebase

The Collection screens solved exactly this problem, with the reason recorded:

```css
/* A Topic is reader-written and unbounded, so its column may shrink below its
   content instead of widening the grid past the viewport. */
.collection-page__header      { grid-template-columns: minmax(0, 1fr) auto; }
.collection-page__heading     { min-width: 0; }
.collection-page__heading h1  { overflow-wrap: anywhere; }
.collection-index__topic-link { min-width: 0; overflow-wrap: anywhere; }
```

Carry that same rule to the entry line's metadata column. Reuse the existing
reasoning and idiom rather than inventing a second treatment; this is one rule
applied to one more surface, not a new mechanism.

## Required behavior

| condition | requirement |
|---|---|
| a Daily, Monthly Calendar, or Monthly Tasks page at 320 px and at 390 px, holding a resident whose successor is a Collection with a long unbroken Topic | `document.documentElement.scrollWidth <= document.documentElement.clientWidth` |
| the same | the complete Topic is present and readable, wrapped across lines — never truncated, ellipsized, or hidden |
| the same | no collision with the fixed tab bar; every target still at least 44×44 CSS px |
| a Monthly or Future successor | its date meta renders exactly as it does today |
| the Index and Collection screens | unchanged, and still free of horizontal overflow |

Both themes, as the existing phone reviews already do.

## In scope

`app/assets/stylesheets/application.css` and `test/`.

`app/views/entries/_meta.html.erb` is admitted **only** if the fix genuinely
needs a shrinkable box that the current markup cannot provide. If you change
it, say why in the commit body.

No model, controller, route, or JavaScript change. No Topic length limit, no
truncation, no new token, no new palette or font. Every 1.5.2 non-goal stands:
no search, no suggestions, no picker, no counts, no reordering, no outbound
Collection movement, no Future-resident controls, no active `hlc`/`server_seq`.
`lib/`, `Gemfile`, and `PLAN.md` stay untouched, so `Bujo::RapidLog*` mutation
stays exactly 1105/1105. Nothing is deployed and nothing is integrated into
`main`.

## Required test — the durable regression

The existing acceptance coverage checks overflow while the move step is **open**
(`assert_phone_move_step` in `test/system/move_to_collection_test.rb`). It never
re-checks the source page **after** a move has written the successor, which is
why this shipped. That is the hole to close.

Add one acceptance scenario that:

1. creates a Collection whose Topic is a single unbroken string with no spaces,
   long enough to exceed 320 px at every hand — put the exact literal in the
   test so a future reader can see what is being defended;
2. moves an eligible Daily resident into it through the real reader gesture,
   not by writing a row;
3. on the **returned source page**, at 320 px and at 390 px, in both themes,
   asserts no horizontal overflow, asserts the complete Topic string is present
   in the predecessor's destination meta, and asserts no tab-bar collision;
4. repeats that post-move assertion with a Monthly Calendar source and a
   Monthly Tasks source, because those pages render the same partial and the
   defect is in the partial, not in the Daily page;
5. places on that same page one further resident whose **own entry text** is a
   single long unbroken string. Entry text has always been unbounded and shares
   the same row, so this proves the sibling column under the same assertion. If
   it surfaces a latent overflow there, fix it with the same rule in the same
   component and say so in the commit — that is one rule in one row, not a
   widening of scope.

Keep the existing `assert_no_horizontal_overflow` idiom. The Collection
screens' existing overflow assertions stay green as written.

## Quality bars

- `bin/rails test` and `bin/rails test:system` green, run in this worktree.
- `bin/rubocop` clean.
- `COVERAGE=1 bin/rails test` then
  `crap4rb --lcov coverage/lcov.info app/ lib/` — every measured method
  CRAP ≤ 6.
- `jscpd --min-tokens 50 --reporters console app/ lib/` — zero clones.
- `bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'` — exactly
  1105/1105, since `lib/` is untouched.

Hand-mutate at least these and show each is killed by an assertion that
explains the product failure:

- remove the wrapping rule from the metadata column;
- truncate or ellipsize the Topic instead of wrapping it;
- fix 390 px but leave 320 px overflowing;
- fix the Daily page but leave the two Monthly pages overflowing;
- let the fix break a dated successor's date meta.

## Handoff

Commit, `git_handoff` to `coder`, task `collection-topic-overflow`, priority `50`.
