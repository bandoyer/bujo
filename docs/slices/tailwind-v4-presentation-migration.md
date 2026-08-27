# Infrastructure slice — Tailwind CSS v4 presentation migration

- **Status:** APPROVED by Dan on 2026-08-27
- **Planning baseline:** `434a9a9478a5581494773c5660583e4d8f3cfa4e`
- **T0 receipt:** [`docs/tailwind-v4-baseline/README.md`](../tailwind-v4-baseline/README.md)
- **Integration branch:** `codex/tailwind-v4`
- **Implementation:** authorized only through the bounded squad below
- **Deployment:** not authorized

## Outcome

Replace Bujo's single hand-written application stylesheet with a deliberately
small Tailwind CSS v4 toolchain and a modular, Bujo-owned presentation system.
The final app must look, behave, and disclose information like the T0 app
unless a later, separately approved product correction says otherwise.

This is infrastructure and presentation work. Tailwind supplies compilation,
tokens, and layout utilities; it receives no authority over the Bullet Journal
method, page residency, command availability, or workflow.

## Product authority and invariant boundary

Ryder Carroll's *The Bullet Journal Method*, especially Parts II and III,
remains the product authority as interpreted by `docs/METHOD.md`. `PLAN.md`,
`ARCHITECTURE.md`, and the accepted page/migration slice contracts remain
binding. If a visual conversion exposes a source question, stop and return it
to the operator; do not answer it with a conventional digital-product pattern
or a Tailwind example.

No part of this slice may change:

- the Collection or Entry models, validations, page-kind admission matrix, or
  command matrix;
- rapid-log parsing, glyph meaning, lifecycle meaning, or return destinations;
- append-only movement and compensating Undo;
- same-user validation and tenant-scoped lookup/nondisclosure;
- UUIDv7 identity, immutable residency, or unique successor chains;
- soft deletion without cascades;
- the exact-null state of events and notes;
- ordering of resident entries, Index rows, migration review, or successor
  chains;
- any sync-sensitive Entry field: `id`, `user_id`, `collection_id`, `kind`,
  `text`, `state`, `occurs_on`, `time_of_day`, `page_kind`, `page_on`,
  `parent_id`, `migrated_from_id`, `priority`, `tags`, `hlc`, `server_seq`,
  `deleted_at`, `created_at`, or `updated_at`;
- any sync-sensitive Collection field: `id`, `user_id`, `name`,
  `index_position`, `hlc`, `server_seq`, `deleted_at`, `created_at`, or
  `updated_at`.

There are no migrations, backfills, background jobs, data repairs, or journal
writes in this slice.

## Explicit behavior freeze

Phone dogfooding has exposed useful follow-up questions. They are not implicit
Tailwind requirements. T1 through T5 preserve the current behavior and current
meaning of all of these surfaces:

- a newly created Collection is deliberately unindexed until the operator
  chooses **Add to Index**;
- Index uses its current manual registration order, New Collection/trailing
  writing gesture, and exact **Open by Topic** access;
- an unindexed Collection is not automatically discovered or broadly searched;
- the current native date input remains the scheduling control and keeps its
  current closed/empty semantics;
- Monthly Calendar keeps its current row structure, resident placement, and
  distinct 44px Daily chevron;
- the preference controls remain in their current page locations;
- success, refusal, missing, and empty messages keep their present wording and
  state meaning;
- Monthly Migration keeps its current explicit setup, live-derived outgoing
  review, Future scan, checkpoints, second steps, Undo, and completion rules;
- completing a task changes the glyph to `X`; the text retains full ink and its
  current-color strike;
- Entry deletion remains deferred.

A separately approved phone-correction amendment may later change the native
date-field treatment, Calendar alignment, notice visual anatomy, Index
navigation/registration, preference placement, or Migration workflow. Such a
change must have its own source and command contract. It must not be smuggled
into a framework conversion or accepted as “close enough” visual parity.

## Acceptance contract

The migration is accepted only if all of the following are true:

1. The application uses the official Ruby-hosted Tailwind v4 integration with
   exact locked versions and no Node toolchain.
2. Development, test preparation, CI, production asset compilation, and Docker
   all build one source tree deterministically.
3. The rendered application loads exactly one fingerprinted application CSS
   asset; source and generated rules are not served twice.
4. Tailwind Preflight is absent. Bujo continues to own every global reset and
   native-control decision.
5. Tailwind's default design system is disabled. Utilities resolve through a
   small, explicit Bujo token bridge rather than an unused default palette and
   scale.
6. Every current light, dark, system, hand, page, form, lifecycle, refusal,
   missing, deleted, and tenant-isolation state preserves its behavior,
   information disclosure, useful phone geometry, focus behavior, and text.
7. No JavaScript controller or test depends on an opaque sequence of utility
   classes.
8. Every production utility is statically discoverable from an explicitly
   allowed application source; docs, mocks, screenshots, coverage, and tests do
   not accidentally keep classes alive.
9. `legacy.css` reaches zero live presentation rules and is deleted only after
   the complete system and production-build gates pass.
10. The operator completes a real iPhone review over Tailscale and explicitly
    approves integration. Passing squad QA does not merge to `main`, push, or
    deploy.

## Dependency and toolchain ruling

Use the official `tailwindcss-rails` integration and lock these versions for
the entire migration:

```ruby
gem "tailwindcss-rails", "4.6.0"
gem "tailwindcss-ruby", "4.3.3"
```

The direct `tailwindcss-ruby` pin is intentional even though it is transitive:
the standalone compiler must not float between checkpoints. Upgrade decisions
after this slice require their own lockfile review.

Version-sensitive implementation references, verified 2026-08-27:

- [Tailwind's Rails installation guide](https://tailwindcss.com/docs/installation/framework-guides/ruby-on-rails)
- [`tailwindcss-rails` v4.6.0 release](https://github.com/rails/tailwindcss-rails/releases/tag/v4.6.0)
- [`tailwindcss-rails` v4 README](https://github.com/rails/tailwindcss-rails)
- [`tailwindcss-ruby` 4.3.3 package](https://rubygems.org/gems/tailwindcss-ruby/versions/4.3.3)
- [disabling Preflight](https://tailwindcss.com/docs/preflight#disabling-preflight)
- [custom theme variables](https://tailwindcss.com/docs/theme)
- [explicit source detection](https://tailwindcss.com/docs/detecting-classes-in-source-files#disabling-automatic-detection)

Do not add:

- Node, npm, pnpm, Yarn, Bun, PostCSS, Sass, or `cssbundling-rails`;
- DaisyUI, Flowbite, a generic component framework, or a Tailwind forms plugin;
- a JavaScript date picker;
- ViewComponent, Phlex, or another view abstraction;
- a font package or vendored-font change;
- arbitrary Tailwind plugins “for convenience.”

Run `bin/rails tailwindcss:install` only on `codex/tailwind-v4`, inspect every
generated change, and reconcile it by hand. Installer output is not permission
to replace Bujo's application shell, layout behavior, or direct server path.

## Build and development architecture

Keep `bin/dev` as the repository's simple Rails-server entry point. Enable the
gem's development watcher through Puma:

```ruby
plugin :tailwindcss if ENV.fetch("RAILS_ENV", "development") == "development"
```

This keeps ordinary local startup and direct Tailscale binding in one process.
Do not retain an installer-generated `Procfile.dev`, Foreman dependency, or
replacement `bin/dev` unless the pinned gem demonstrably cannot watch under
the current Ruby/Puma versions. Such a failure is a specification issue and
returns to the operator before adopting a second process manager.

The deterministic one-shot command is:

```sh
bin/rails tailwindcss:build
```

It must work from a clean checkout and must produce the same bytes on a second
unchanged build.

## CSS source architecture

The final source tree is:

```text
app/assets/tailwind/
  application.css
  tokens.css
  base.css
  components/
    actions.css
    entries.css
    fields.css
    notices.css
    page-shell.css
    preferences.css
    rapid-log.css
    tab-bar.css
  pages/
    auth.css
    collections.css
    daily.css
    future.css
    monthly.css
    monthly-migration.css
app/assets/builds/
  .keep
  tailwind.css                 # generated and gitignored
```

During coexistence, `app/assets/tailwind/legacy.css` contains the byte-identical
T0 stylesheet. It is imported into the generated asset and shrinks only when a
named owner has passed its checkpoint. Moving it away from
`app/assets/stylesheets/` prevents Propshaft from publishing a second copy.

Use an explicit layer order:

```css
@layer theme, base, legacy, components, utilities;

@import "tailwindcss/theme.css" layer(theme);
@import "./tokens.css" layer(theme);
@import "./base.css" layer(base);
@import "./legacy.css" layer(legacy);
@import "./components/actions.css" layer(components);
/* remaining explicit component/page imports */
@import "tailwindcss/utilities.css" layer(utilities) source(none);

@source "../../views";
@source "../../helpers";
@source "../../javascript";
```

The implementer must validate the exact directives against the pinned compiler
rather than mechanically copying this illustrative entry. `source(none)` is a
hard requirement: only the three explicit application roots above may author
utilities. Do not scan `test/`, `docs/`, `mockups/`, `tmp/`, `coverage/`,
`public/`, generated CSS, or baseline screenshots.

### Preflight and theme

Preflight is permanently off for this migration. Import Tailwind's theme and
utilities modules separately; never use an import that silently adds
`preflight.css`. Enabling it later would be a separate all-page visual change.

Disable the complete default Tailwind theme before defining project tokens:

```css
@theme {
  --*: initial;
  /* only explicitly approved spacing, radius, shadow, and breakpoint tokens */
}

@theme inline {
  --color-page: var(--bg);
  --color-surface: var(--surface);
  --color-ink: var(--ink);
  --color-muted: var(--muted);
  --color-faint: var(--faint);
  --color-rule: var(--line);
  --color-accent: var(--accent);
  --color-warning: var(--warn);
  --font-hand: var(--font-body);
  --font-heading: var(--font-serif);
  --font-glyph: var(--font-mono);
}
```

The names above describe the bridge; the final token file must map every live
T0 variable, including selected/today row surfaces, and nothing unused. Theme
and hand changes continue to swap root variable values. Do not repeat dark
palette values in markup or add Tailwind color names alongside Bujo's tokens.

### Class policy

Use a hybrid presentation strategy:

- static utility literals for local, one-owner layout;
- small semantic component classes for repeated primitives, pseudo-elements,
  complex grids, native controls, and state selectors;
- existing semantic hooks for Stimulus, Turbo, tests, and recognizable DOM
  anatomy;
- `data-*`, `aria-*`, `hidden`, stable IDs, and Turbo target IDs for behavior;
- complete literal mappings for conditional utility variants.

Never construct fragments such as `"text-#{state}-600"`. Every possible
utility must appear as a complete literal in an allowed application source.
Tests select stable semantics or accessible roles, not utility strings.

These current runtime contracts remain until a separately tested data-target
refactor makes a class unnecessary:

- `.entry`
- `.entry__toggle`
- `.entry__action-strip`
- `.entry--selected`
- `.future-log__month--empty`
- `.rapid-log__kind--selected`

## Authorized file scope

The squad may change only presentation/tooling files needed by this contract:

- `Gemfile` and `Gemfile.lock` for the two exact gems;
- `app/assets/tailwind/**`, `app/assets/builds/.keep`, and asset ignore rules;
- `app/views/**` and `app/helpers/application_helper.rb` for static classes,
  stable component markup, or extracted existing partials;
- `app/javascript/controllers/**` only to replace a semantic styling-class
  dependency with an equivalent explicit data target, never to change behavior;
- `config/puma.rb`, asset configuration, `bin/dev`, and Docker/build configuration
  only as specified above;
- `.github/workflows/ci.yml` and repository documentation for deterministic
  builds;
- focused fast/system tests and test helpers needed to assert the contract.

Explicitly forbidden without a returned specification amendment:

- `app/models/**`, application/domain controllers, routes, jobs, mailers, or
  policies;
- `db/**`, `lib/bujo/**`, rapid-log grammar, fixtures that alter product
  meaning, or production journal data;
- authentication behavior, page-kind rules, command authorization, return
  destinations, wording, automatic behavior, or tenant disclosure;
- the unrelated existing GitHub Actions `master` branch-filter correction;
- deployment or production secrets.

## Checkpoint graph

Every checkpoint lands as a small, reviewable commit on the integration branch.
No page-family conversion starts until its dependency gate is accepted.

### T0 — reference capture — complete

The prepared T0 baseline provides:

- the exact repository/tooling boundary;
- green fast, system, lint, complexity, duplication, mutation, and production
  asset receipts;
- the 23,218-byte source/production CSS hash and compressed sizes;
- a complete selector ownership ledger;
- 135 screenshots: 45 states × three phone/theme/hand profiles;
- 102 targeted geometry samples: 34 layout-bearing states × the same three
  profiles;
- a screenshot manifest with exact dimensions and hashes.

Gate: documents and reference artifacts only; no rendered/runtime change.

### T1 — compiler plumbing with legacy parity

1. Add and lock `tailwindcss-rails` 4.6.0 and `tailwindcss-ruby` 4.3.3.
2. Run and inspect the installer; reconcile its output to this spec.
3. Move the T0 stylesheet byte-for-byte to `legacy.css`.
4. Create the explicit Tailwind entry, disabled default theme, no-Preflight
   imports, constrained source roots, generated build target, and Puma watcher.
5. Preserve `bin/dev` and direct Rails/Tailscale startup.
6. Update the layout only as needed to load one generated asset with Turbo
   reload tracking.
7. Make test preparation, both CI lanes, production precompile, and Docker run
   an explicit Tailwind build.
8. Update CSS-source tests temporarily to read the still-identical legacy
   owner rather than generated/minified output.
9. Compare all T0 states, geometry anchors, DOM behavior, focus, and
   accessibility.

Gate: no intended pixel, DOM, text, behavior, disclosure, or accessibility
difference. The generated CSS may contain Tailwind scaffolding, but the T0
legacy rules remain the sole presentation owner. Reverting T1 restores the
original source stylesheet and removes only build tooling.

### T2 — tokens, base, and shared primitives

Convert in this exact order:

1. theme/hand variables, glyph fallback, dot grid, sizing, and page background;
2. visually hidden content and focus-visible treatment;
3. page shell and title-first header;
4. actions, links, labels, text/date fields, and action rows;
5. notices, alerts, refusals, missing states, and empty-state text;
6. preferences and the fixed tab bar;
7. the shared Rapid Log kind selector and form shell.

Each primitive gets one named owner. Migrate every use or leave a ledger entry
for a later checkpoint. Preserve at least 44 × 44 CSS-pixel targets, keyboard
focus, accessible names, root theme/hand precedence, and current native-control
behavior.

Gate: all pages remain usable and visually equivalent even while their
page-specific layouts remain in legacy CSS.

### T3 — Entry and core log surfaces

1. Convert the shared Entry line: signifier, glyph, text, metadata, children,
   lifecycle ink, wrapping, selection, and action strip.
2. Convert its existing Complete/Strike/Reopen, Edit, Schedule, and Move steps
   without changing the page/kind command matrix or return destination.
3. Convert Daily's title-first header, date navigation, open count, residents,
   empty state, and trailing writing surface.
4. Convert Monthly Tasks residents, count, capture, empty state, and trailing
   writing surface.
5. Convert Future's runway, month sections, residents, empty state, and capture.

Gate: every existing Entry command succeeds or refuses in the same place, with
the same row ancestry and residency. Long content wraps without horizontal
overflow or column loss.

### T4 — complex and remaining page families

Convert one complete family per accepted commit:

1. Monthly Calendar, including day row, selected/today state, nested residents,
   capture reveal, and the separate Daily chevron;
2. Index and Custom Collection, including create, indexed/unindexed, Manage,
   empty, populated, refusal, missing, deleted, and tenant-isolated states;
3. Monthly Migration, including setup, outgoing, both second steps, Future
   task/event, checkpoints, Undo, complete, refusal, stale, and missing states;
4. sign-in, password, shared flashes, and remaining fallback/error surfaces.

Keep custom component CSS when it communicates the Calendar or Entry grid more
clearly than long arbitrary-value utility strings. Tailwind adoption does not
mean zero custom CSS.

Gate: every family passes its complete state grid before the next begins.

### T5 — legacy removal and hardening

1. Reconcile every row of `selectors.csv` against its new owner.
2. Remove legacy declarations only after the owning state matrix passes.
3. Confirm `.monthly-calendar__glyph--event` is still ownerless, then remove it
   as the only T0 dead selector.
4. Prove every conditional class is present in a production build without
   relying on docs/test scanning.
5. Delete empty `legacy.css` and the old stylesheet path.
6. Build twice and prove byte stability.
7. Inspect the final Propshaft manifest and rendered HTML for one application
   bundle and no raw source CSS.
8. Record raw, gzip `-9`, and Brotli quality-11 sizes against T0. There is no
   arbitrary size cap, but unexplained growth is blocking.
9. Run dependency/security, complete quality, production asset, and Docker
   gates.

Gate: no live selector lacks an owner; there is one coherent generated bundle,
no legacy source, and no unexplained presentation or behavior drift.

### T6 — real-phone acceptance and integration

1. Retire the squad after terminal QA; do not leave background agents or
   worktrees running.
2. Run the candidate locally over Tailscale on the actual iPhone.
3. Walk the state matrix in both themes and at least two hands, including native
   date selection, long text, rotation, browser zoom, bottom safe area, focus,
   and Turbo navigation.
4. Present receipts and any genuine product questions to Dan.
5. Merge and push only after Dan's explicit integration approval.
6. Do not deploy. Dan owns production deployment and its later smoke check.

## Squad execution contract

Use the repository's dynamic squad with at most two transient workers. Its
approved profile is already recorded in `swarmforge/squad.conf`:

| Responsibility | Model | Effort |
|---|---|---|
| Leader | Codex 5.6 Sol | Max |
| Default implementation/merge fallback | Codex 5.6 Sol | High |
| Specifier | Codex 5.6 Sol | Max |
| Coder | Codex 5.6 Sol | High |
| Architect | Codex 5.6 Sol | High |
| Cleaner | Grok 4.6 | High |
| Hardener | Grok 4.6 | High |
| QA | Codex 5.6 Sol | XHigh |

The deterministic per-role profile support is present on canonical
SwarmForge `main` at `b5b17bd65b1bf086173d2bc0bc9ddc76022f3fee` and passed
its complete 375-check smoke suite. This resolves the tooling prerequisite; it
does not authorize `swarm squad up` before this specification is approved.

### Assignment order

| Order | Assignment | Owner | Concurrency |
|---:|---|---|---|
| 1 | T1 compiler plumbing and legacy parity | coder | exclusive |
| 2 | adversarial plumbing review/repair routing | hardener | exclusive |
| 3 | T2 tokens, base, and shared primitives | coder | exclusive |
| 4 | shared-primitives architecture review | architect | exclusive |
| 5 | shared Entry component and command surfaces | coder | exclusive |
| 6A | Daily, Monthly Tasks, and Future composition | coder | may overlap only 6B |
| 6B | Monthly Calendar composition and geometry | coder | may overlap only 6A |
| 7A | Index and Custom Collection | coder | may overlap only 7B |
| 7B | Monthly Migration, auth, and remaining errors | coder | may overlap only 7A |
| 8 | cross-page cleanup, dead CSS, production build, quality evidence | cleaner/hardener | exclusive |
| 9 | accumulated spec/behavior/visual/accessibility/rollback verification | QA | terminal, exclusive |

A specifier is spawned only when an accepted packet lacks a testable contract
or a finding reveals a genuine spec gap. It may clarify; it may not invent or
expand product behavior.

### Parallel ownership

6A/6B and 7A/7B are the only parallel pairs. Before each pair, the leader
records exact file ownership. These shared owners are frozen while a pair runs:

- `app/assets/tailwind/application.css`, `tokens.css`, and `base.css`;
- all `app/assets/tailwind/components/**` files;
- the application layout, shared shell, tab bar, preferences, Rapid Log, and
  Entry partials;
- shared Stimulus controllers and system-test helpers.

If a worker needs a shared edit, it reports the seam. The leader pauses affected
work, routes one bounded shared-owner repair, integrates it, and resumes. A
merge-conflict worker may resolve mechanics only; it may not choose between
competing component or product contracts.

`squadd` alone integrates accepted assignment commits into
`codex/tailwind-v4`. Every assignment starts from the current integration head
and returns reproducible command evidence. Terminal QA covers the accumulated
candidate, not just the final diff.

## Test and evidence contract

The existing Rails system lane is the authoritative browser lane. An
unavailable Codex in-app Browser backend is neither a failure nor a reason to
claim a visual pass occurred. Use headless Chrome, screenshots, computed
geometry, accessibility/DOM assertions, and direct request/domain probes.

### Baseline counts

- Fast: 230 runs / 3822 assertions.
- System: 81 runs / 1640 assertions.
- RuboCop: clean over 102 files.
- CRAP: every one of 234 measured methods ≤ 6.
- jscpd: zero clones.
- `Bujo::RapidLog*`: 1105/1105 mutations killed.

Counts may rise. A count may not fall without a named consolidation and proof
that the accepted behavior remains covered.

### Build assertions

Add deterministic coverage that proves:

- a clean `bin/rails tailwindcss:build` succeeds;
- a second unchanged build has the same SHA-256;
- test preparation rebuilds rather than consuming a stale artifact;
- fast and system CI jobs explicitly build before tests;
- production precompile produces one fingerprinted Tailwind bundle;
- rendered HTML links that bundle once with Turbo tracking;
- the Docker build succeeds without Node;
- every complete conditional class literal survives production extraction.

### Browser state matrix

For every changed surface, the minimum profiles are:

- 390px light with Rock Salt;
- 320px dark with Architects Daughter.

Across the complete suite, also sample system/default behavior and Permanent
Marker, Patrick Hand, Gochi Hand, and Public Sans. Cover every one of the 45 T0
states listed in the baseline receipt.

For each applicable state assert:

- no horizontal overflow;
- no interactive/content region hidden behind the fixed tab bar or phone safe
  area;
- page title is the first visible page content and context follows it;
- visible keyboard focus and truthful `aria-expanded`, `aria-current`,
  `aria-selected`, `hidden`, and disabled state;
- every actionable target is at least 44 × 44 CSS pixels;
- the tab bar remains fixed, 65px high, and divided into four equal targets;
- empty and trailing writing surfaces extend from the last content to the tab
  boundary and open the same existing form;
- Entry glyph, signifier, content, metadata, lifecycle ink, child indentation,
  and action rows wrap without collision;
- Calendar day, residents, and Daily chevron stay inside their explicit grid;
- native date controls remain legible and usable in empty/selected states;
- notices, refusals, and missing states retain their current wording, roles,
  state boundaries, and recorded geometry; this gate does not correct the
  known field-like success style;
- missing, deleted, and tenant-isolated Collections remain nondisclosing.

Use `geometry.json` for exact T0 anchors. Browser rendering may vary by a
fractional pixel across Chrome/font builds, so write semantic tolerances around
columns, bounds, and non-overlap—not global screenshot pixel equality.

### Test refactors

`test/lettering_tokens_test.rb` becomes a source contract for the new semantic
token bridge plus rendered hand coverage. Do not point it at generated minified
CSS.

The implementation-coupled assertions in
`test/unbounded_text_wrapping_test.rb` move to browser geometry assertions for
the behavior they actually protect. Other controller/model tests stay
unchanged unless a view assertion refers only to a discarded styling selector.
Use fixtures, real database objects, explicit ordering, and fixed dates under
the repository testing conventions.

### Commands at every checkpoint

```sh
bin/rails tailwindcss:build
bin/rails test
bin/rubocop
bin/rails test:system
SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin/rails assets:precompile
```

Terminal hardening also runs:

```sh
COVERAGE=1 bin/rails test
crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
docker build -t bujo-tailwind-verification .
```

The mutation scope is intentionally unchanged because this slice cannot touch
the parser. A changed Rapid Log mutation receipt is a blocking scope finding.
Run the dependency/security checks already required by the project against the
new lockfile.

## Rollback

This migration has no data rollback:

- T1 retains the exact legacy rules inside the generated entry;
- each later commit removes only the rules owned by one accepted component or
  page family;
- any failed checkpoint can be reverted without touching journal rows;
- `legacy.css` survives until T5 proves it empty;
- production rollback is the prior app image/commit with its prior
  fingerprinted assets;
- no sync reconciliation, backfill, or cleanup is required.

## Mock impact

No mobile mock must change to review a parity migration. The existing app—not
a new design—is the visual authority, and the T0 screenshot/geometry matrix is
the smallest truthful review artifact. The known phone-correction ideas need a
separate approved mock only when their product and visual behavior is specified.

The 135 PNGs are intentionally kept with this documentation so every squad
role and later reviewer receives the same immutable reference rather than a
machine-local screenshot path.

## Approval record

There are no unresolved product decisions inside this slice. The choices
previously discussed are settled here as the approved contract: Ruby-hosted
Tailwind v4, exact pins, no Node, no Preflight, no default theme, hybrid
utilities/components, staged migration, two-worker squad, and phone behavior
corrections kept separate.

Dan approved this complete contract, including keeping the 135 reference PNGs
in the repository, on 2026-08-27. That approval authorizes committing/pushing
the planning baseline and running `swarm squad up`. It does not authorize a
merge from `codex/tailwind-v4` to `main` or a deployment; those retain their
later explicit approval gates.
