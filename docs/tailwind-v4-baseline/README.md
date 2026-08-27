# Tailwind CSS v4 migration — T0 baseline receipt

**Status:** captured at `434a9a9478a5581494773c5660583e4d8f3cfa4e`
on 2026-08-27 and approved by Dan as the presentation-parity baseline the same
day. It authorizes no product-behavior expansion, root integration, or deploy.

This directory freezes the rendered system that Tailwind must initially
reproduce. The screenshots supplement the Rails system suite; they do not
replace behavior, request, domain, accessibility, or tenant-isolation tests.

## Capture boundary

- Repository: `/home/dlb/Work/bujo`
- Branch: `main`
- Baseline: `434a9a9478a5581494773c5660583e4d8f3cfa4e`
- Remote: `origin/main` at the same commit after `git fetch --prune`
- Worktrees: only `/home/dlb/Work/bujo`
- Bujo SwarmForge daemons: stopped
- Historical recovery branch: not used
- Browser: the same local Chrome/Capybara lane used by the Rails system tests
- Viewports: exact CSS viewports of `390 × 844` and `320 × 844`

The one-off capture harness used ordinary test fixtures and model setup, then
used Chrome device metrics and waited for `document.fonts.ready` before each
image and geometry sample. The harness is intentionally not a production or
test-suite dependency; these prepared receipts are the durable result once the
operator approves and commits the planning baseline.

## Green baseline

| Check | Result |
|---|---:|
| `bin/rails test` | 230 runs, 3822 assertions, 0 failures, 0 errors |
| `bin/rails test:system` | 81 runs, 1640 assertions, 0 failures, 0 errors |
| `bin/rubocop` | 102 files inspected, no offenses |
| `RAILS_ENV=production bin/rails assets:precompile` | passed |
| CRAP | every one of 234 measured methods ≤ 6 |
| jscpd | zero clones |
| `Bujo::RapidLog*` mutation | 1105/1105 killed |

The CRAP, clone, and mutation receipts are the accepted 1.5.3b terminal
receipts. They remain applicable because the diff from that candidate
(`dc2153c`) through this baseline contains no changes under `app/`, `lib/`,
`test/`, `config/`, `db/`, `Gemfile`, `Gemfile.lock`, `Dockerfile`, `bin/`, or
`.github/`. The Rails, system, RuboCop, and production-asset checks above were
also repeated directly at this baseline.

## Current stylesheet and production assets

`app/assets/stylesheets/application.css` is the only application stylesheet:

| Measurement | Baseline |
|---|---:|
| Source lines | 1,152 |
| Source bytes | 23,218 |
| SHA-256 | `df75385665a9f4f48af1f66156953e712493c2e85575de861ffc09963bfa5ceb` |
| Production bytes | 23,218 |
| gzip `-9` bytes | 5,023 |
| Brotli quality 11 bytes | 4,225 |
| Rendered application stylesheet links | exactly 1 |

The production application asset is
`application-11c000df.css`, with the same byte count and SHA-256 as the source.
The complete Propshaft manifest at T0 is:

| Logical path | Digested output | Bytes |
|---|---|---:|
| `action_cable.js` | `action_cable-5212cfee.js` | 16,604 |
| `actioncable.esm.js` | `actioncable.esm-e0ec9819.js` | 14,813 |
| `actioncable.js` | `actioncable-ac25813f.js` | 16,474 |
| `actiontext.esm.js` | `actiontext.esm-c376325e.js` | 31,650 |
| `actiontext.js` | `actiontext-c9c6c481.js` | 33,970 |
| `activestorage.esm.js` | `activestorage.esm-81bb34bc.js` | 28,343 |
| `activestorage.js` | `activestorage-f9e46063.js` | 30,573 |
| `application.css` | `application-11c000df.css` | 23,218 |
| `application.js` | `application-bfcdf840.js` | 157 |
| `controllers/application.js` | `controllers/application-3affb389.js` | 218 |
| `controllers/hello_controller.js` | `controllers/hello_controller-708796bd.js` | 157 |
| `controllers/index.js` | `controllers/index-ee64e1f1.js` | 272 |
| `controllers/migration_actions_controller.js` | `controllers/migration_actions_controller-94b1a6a9.js` | 1,205 |
| `controllers/placement_controller.js` | `controllers/placement_controller-31256f87.js` | 2,040 |
| `controllers/preference_controller.js` | `controllers/preference_controller-307c913f.js` | 1,158 |
| `controllers/rapid_log_controller.js` | `controllers/rapid_log_controller-a31c611d.js` | 699 |
| `controllers/task_actions_controller.js` | `controllers/task_actions_controller-7818fbc3.js` | 2,216 |
| `rails-ujs.esm.js` | `rails-ujs.esm-e925103b.js` | 22,369 |
| `rails-ujs.js` | `rails-ujs-20eaf715.js` | 24,018 |
| `stimulus-autoloader.js` | `stimulus-autoloader.js` | 1,747 |
| `stimulus-importmap-autoloader.js` | `stimulus-importmap-autoloader.js` | 989 |
| `stimulus-loading.js` | `stimulus-loading.js` | 3,315 |
| `stimulus.js` | `stimulus.js` | 88,790 |
| `stimulus.min.js` | `stimulus.min.js` | 45,657 |
| `stimulus.min.js.map` | `stimulus.min.js.map` | 164,428 |
| `trix.css` | `trix.css` | 19,638 |
| `trix.js` | `trix.js` | 526,142 |
| `turbo.js` | `turbo.js` | 189,223 |
| `turbo.min.js` | `turbo.min.js` | 105,579 |
| `turbo.min.js.map` | `turbo.min.js.map` | 369,655 |

T1 must reduce the application side back to one generated stylesheet link. It
must not serve both the legacy source and its compiled copy.

## Screenshot inventory

[`screenshots.json`](screenshots.json) records every image's profile, state,
dimensions, byte count, SHA-256, and relative path. There are 135 PNGs totaling
5,157,927 bytes: 45 states in each of these profiles.

| Profile | Viewport | Explicit preference |
|---|---:|---|
| `390-light-rock-salt` | 390 × 844 | light theme, Rock Salt hand |
| `320-dark-architects` | 320 × 844 | dark theme, Architects Daughter hand |
| `390-system-marker` | 390 × 844 | no explicit theme/hand attributes; Permanent Marker default |

The capture host resolved the system profile to dark. That is evidence of the
current system-following result, not a requirement that every host resolve
system mode to dark.

The 45 states are grouped below. Their filenames are
`<profile>--<state>.png`.

| Surface | States |
|---|---|
| Authentication | `auth-sign-in-normal`, `auth-sign-in-refusal`, `auth-password-request` |
| Daily | `daily-empty`, `daily-populated-long`, `daily-actions`, `daily-edit`, `daily-move`, `daily-schedule-empty`, `daily-schedule-selected`, `daily-refusal` |
| Monthly Tasks | `monthly-tasks-empty`, `monthly-tasks-populated`, `monthly-tasks-capture` |
| Monthly Calendar | `monthly-calendar-populated`, `monthly-calendar-capture`, `monthly-calendar-residents` |
| Future | `future-empty`, `future-populated`, `future-capture` |
| Index | `index-empty`, `index-populated-long`, `index-create`, `index-refusal` |
| Collection | `collection-empty-unindexed`, `collection-populated-indexed`, `collection-manage`, `collection-missing`, `collection-deleted`, `collection-tenant-isolated` |
| Migration setup | `migration-setup-empty`, `migration-setup-populated`, `migration-not-found` |
| Migration outgoing | `migration-outgoing`, `migration-outgoing-checkpoint`, `migration-outgoing-collection-step`, `migration-outgoing-future-step` |
| Migration Future/finish | `migration-future-checkpoint`, `migration-future-task`, `migration-future-event`, `migration-complete` |
| Migration defenses | `migration-undo`, `migration-refusal`, `migration-stale-refusal`, `migration-item-missing` |

Within each profile, Collection missing, soft-deleted, and another tenant's
Collection intentionally have identical image hashes. The current
nondisclosure contract renders those cases identically.

## Geometry contract

[`geometry.json`](geometry.json) holds 102 targeted computed-geometry samples:
34 layout-bearing states in each of the three profiles. Authentication and
several modal/behavior-only screenshot states are represented by images and
the authoritative system tests rather than redundant geometry rows. The file
records rectangles, font metrics, grid columns, viewport dimensions, and
scroll dimensions, and is the exact source when a value below differs by hand
or viewport. High-value anchors include:

- the fixed tab bar is 65px high, starts at `y = 779`, spans the viewport, and
  divides into four equal columns (`97.5px` at 390; `80px` at 320);
- the normal page inset is 16px, yielding 358px of content at 390 and 288px at
  320;
- Daily's empty trailing writing surface ends at `y = 776` immediately above
  the tab bar: `x = 16`, `y = 189`, `w = 358`, `h = 587` in the light profile;
- Monthly Tasks' light empty trailing surface is `x = 16`, `y = 385.65625`,
  `w = 358`, `h = 390.34375`, also ending at `y = 776`;
- the light long Daily entry preserves the shared row grid
  `16px 20px 148.906px 161.094px` while reaching 342px high;
- the light Daily refusal flash is `x = 32`, `y = 189`, `w = 326`, `h = 64`;
- the light empty schedule field is `x = 56`, `y = 567.984375`, `w = 318`,
  `h = 44`;
- a light Calendar row is 358px wide and 54px high, with outer columns
  `60px 230.031px 44px`; the final 44px is the distinct Daily chevron target;
- the light Monthly Migration Future-date field is `x = 56`,
  `y = 478.8125`, `w = 218.890625`, `h = 44`.

The parity gate compares behavior and useful layout invariants, not fragile
pixel identity across different Chrome/font-rendering builds. Any intentional
change to these anchors requires a separately approved visual correction.

## Selector ownership ledger

[`selectors.csv`](selectors.csv) classifies every selector in the 1,152-line
stylesheet before migration.

| Category | Selector rows |
|---|---:|
| Token/base | 15 |
| Reusable component | 61 |
| Page-specific layout | 122 |
| Behavior/test hook | 23 |
| Dead or superseded | 1 |
| **Total** | **222** |

The source contains 158 rule blocks (including media rules) and 111 unique CSS
class tokens. Seven rules participate directly in Stimulus behavior; 122
selector rows are referenced by tests. The only selector without a live owner
is `.monthly-calendar__glyph--event`; removal waits for the final cleanup gate,
after the new bundle and complete suite prove it is still dead.

Runtime hooks such as `.entry`, `.entry__toggle`, `.entry__action-strip`,
`.entry--selected`, `.future-log__month--empty`, and
`.rapid-log__kind--selected`, together with `hidden`, `aria-*`, IDs, Turbo
targets, and Stimulus data attributes, remain behavior contracts until a
separate tested refactor moves them to explicit data targets.

## Artifact integrity

| Artifact | SHA-256 |
|---|---|
| `geometry.json` | `7058c8dbf766e420964c1aaa78a01d3ddbd6f3df91f1014070279e221c316b2c` |
| `selectors.csv` | `1941f8bfd4dce0336658423b9d05368e2fd8265b0047339500606fa5c7ed7f64` |
| `screenshots.json` | `24e90401941422a8e26674d4144f4fd1287b1755e265e43fb8472987c40d7713` |

Recompute screenshot hashes from `screenshots.json` before accepting a changed
baseline. Do not update T0 artifacts merely to make a migration diff disappear;
first determine whether the change is a regression or a separately approved
product correction.

## Known observations, not migration scope

The baseline intentionally records the current native date control, Monthly
Calendar resident alignment, notice presentation, Index/Open-by-Topic flow,
Collection registration flow, preference placement, and Monthly Migration
workflow. Phone dogfooding has raised questions about those surfaces, but this
presentation migration neither settles nor silently changes them. They belong
in a separately approved phone-correction amendment.
