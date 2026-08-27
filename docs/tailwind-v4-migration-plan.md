# Tailwind CSS v4 migration plan

Status: **PROPOSED — planning artifact only; no implementation authorized.**

Date: 2026-08-26

This document describes what it would take to move Bujo's phone application
from its current standalone stylesheet to Tailwind CSS v4 without changing
journal behavior, page residency, the visual identity, or the Rails/Hotwire
architecture. It is deliberately a migration plan, not a slice specification.
Every implementation slice still needs an approved scope and acceptance
contract before a swarm starts.

Product authority remains `docs/METHOD.md`, then `PLAN.md`,
`ARCHITECTURE.md`, and the approved slice contracts. Tailwind is an
implementation tool; it receives no authority to reinterpret those documents.

## Recommendation in one page

Adopt Tailwind v4, but do it incrementally and keep Bujo's design custom:

- use the official `tailwindcss-rails` v4 integration and its standalone
  executable;
- keep Propshaft, import maps, Hotwire, plain ERB, and the existing Stimulus
  controllers;
- add no Node, PostCSS, Sass, component kit, or JavaScript date-picker package;
- initially omit Tailwind Preflight so its global reset cannot silently change
  every handwritten heading, button, input, list, and dialog at once;
- preserve the current CSS variables as the source of truth for the paper-light
  and Tokyo Night-dark palettes, then map them into Tailwind v4 theme utilities;
- preserve semantic classes and `data-*` attributes as stable JavaScript,
  accessibility, and test hooks while moving visual declarations to Tailwind;
- migrate shared primitives first, then one page family at a time, leaving the
  application green and releasable after every checkpoint;
- keep complex, meaningful CSS where it is clearer than utilities, especially
  the dot-grid background, Calendar grid, handwriting fallbacks, and native
  control normalization;
- remove the legacy stylesheet only after every owned selector has an explicit
  replacement and the complete phone matrix passes.

This is not a small dependency addition. It affects the asset build, local
development process, CI, Docker compilation, 1,152 existing CSS lines, roughly
40 rendered templates/partials, 141 current class-bearing declarations, two
fast tests that inspect CSS source directly, and all eight system-test files.
The safe unit of delivery is several small landing checkpoints, not one large
rewrite.

## Approved orchestration direction

The operator approved the following execution shape on 2026-08-26. This
approval selects how an eventual migration should be coordinated; it does not
yet authorize Tailwind installation, application changes, a running squad, or
integration into `main`.

Use a dynamic squad rather than treating the complete migration as one
two-pack assignment. Keep the squad deliberately small:

- one persistent leader owns decomposition, dependency ordering, assignment
  acceptance, and communication with the operator;
- at most two transient workers may be active concurrently;
- infrastructure and shared-component prerequisites remain sequential;
- only page families with explicit, non-overlapping ownership may run in
  parallel;
- accepted assignments merge into a dedicated `codex/tailwind-v4` integration
  branch, never directly into `main`;
- final QA is terminal only for the integration candidate; the operator still
  reviews it and explicitly authorizes the merge into `main`;
- the squad and its worktrees are retired before root integration.

The approved model and effort roster is:

| Responsibility | Model and effort |
|---|---|
| Persistent squad leader | GPT-5.6 Sol Max |
| Specification worker, when a packet needs one | GPT-5.6 Sol Max |
| Implementer workers | GPT-5.6 Sol High |
| Cleaner and hardener workers | Grok 4.6 High |
| Architecture reviewer | GPT-5.6 Sol High |
| Terminal QA | GPT-5.6 Sol XHigh |

The leader is a coordinator, not a substitute implementer or spec author. A
specifier worker authors any product artifact required after the squad starts;
the leader may frame and accept that assignment but may not bypass its own
write boundary.

### Squad tooling prerequisite

When this plan was approved on 2026-08-26, the installed SwarmForge squad
launcher recorded only an agent **kind** (`claude`, `codex`, or `grok`). It
could not pin model or reasoning effort for the leader or transient templates.
The prerequisite implementation is now prepared on the canonical tool's
feature branch and passes its complete 375-check smoke suite; it still must be
integrated before this squad is launched.

Before `swarm squad up` is allowed for this migration, SwarmForge must provide
and test all of the following:

1. A leader model-and-effort pin independent of transient-worker defaults.
2. A default model-and-effort pin per worker template, with an explicit
   per-assignment override for exceptional work.
3. Durable recording of the resolved kind, model, and effort on each worker so
   status and audit output report what actually ran.
4. Identical resolution when a worker is spawned directly or by `squadd` from
   a spawn request.
5. Safe argument handling with no shell interpolation of configuration values.
6. Backward compatibility for existing kind-only squad configurations.
7. Tests covering defaults, overrides, invalid values, daemon spawning, and
   restart/recovery behavior.

Do not achieve this by temporarily rewriting `~/.codex`, `~/.claude`, or
`~/.grok` configuration between assignments. Global mutable defaults would
make a long-lived squad nondeterministic and could affect unrelated sessions.
The SwarmForge capability belongs in its own repository and review; Bujo should
consume a released or locally installed version only after that change lands.

After the prerequisite exists, add a repository-owned `swarmforge/squad.conf`
with this policy:

```text
main_branch codex/tailwind-v4
max_transient_agents 2
max_merger_depth 2
leader_profile codex gpt-5.6-sol max
worker_profile codex gpt-5.6-sol high
template_profile specifier codex gpt-5.6-sol max
template_profile coder codex gpt-5.6-sol high
template_profile cleaner grok grok-4.6 high
template_profile hardener grok grok-4.6 high
template_profile architect codex gpt-5.6-sol high
template_profile qa codex gpt-5.6-sol xhigh
```

The squad may merge accepted assignments into its integration branch
automatically. Nothing in squad configuration authorizes merging or pushing
that branch to `main`.

That configuration is now present and validation resolves every approved
template to the roster above. It is inert policy until the tool prerequisite
and migration specification gates are both satisfied; no squad was started by
preparing it.

## Why switch

The current CSS was a sound starting choice for a small, highly bespoke Rails
application. The application has since accumulated Daily, Monthly Calendar,
Monthly Tasks, Future, Index, Custom Collection, Monthly Migration, correction,
and several transient form states. Shared concepts now have page-specific
implementations:

- page containers and headers;
- preference placement;
- buttons and action strips;
- fields and native controls;
- notices and errors;
- empty writing surfaces;
- Entry grids embedded inside page-specific grids;
- focus, selected, expanded, and disabled states.

Tailwind can provide one constrained vocabulary for spacing, sizing, grid,
wrapping, focus, breakpoints, and design tokens. It will not provide product
judgment, accessibility, a component hierarchy, or a better iOS date picker by
itself. The migration succeeds only if repeated UI is also made structurally
reusable through existing Rails partials and stable component contracts.

## Current baseline

### Runtime and assets

- Ruby 4.0.6 and Rails 8.1.3.1.
- Propshaft through `stylesheet_link_tag :app`.
- Import maps, Turbo, and Stimulus; no JavaScript package manager.
- `app/assets/stylesheets/application.css` is the only application stylesheet
  and is currently 1,152 lines.
- `bin/dev` directly executes `bin/rails server`; there is no `Procfile.dev`.
- Production builds run `SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile`
  in the Docker build stage and Kamal serves fingerprinted assets from
  `/rails/public/assets`.

### Visual system that must survive

- The root CSS variables own paper-light and Tokyo Night-dark colors.
- System theme is the default; explicit `data-theme="light|dark"` overrides it.
- `data-hand` selects Permanent Marker, Rock Salt, Architects Daughter,
  Patrick Hand, Gochi Hand, or Public Sans.
- The glyph stack deliberately falls back to JetBrains Mono for characters a
  hand font does not contain.
- The fixed four-tab shell, dot grid, 44px minimum targets, title-first page
  hierarchy, and 320px/390px phone layouts are existing contracts.
- Long entry text and Collection Topics must wrap without widening the page.
- `hidden`, `aria-expanded`, focus return, and Stimulus targets carry behavior;
  styling may not falsify them.

### Coupling that must be handled explicitly

- `task_actions_controller.js` currently queries `.entry`, `.entry__toggle`,
  and `.entry__action-strip`, and toggles `.entry--selected`.
- System tests locate many semantic classes and measure their rendered boxes.
- `test/lettering_tokens_test.rb` and
  `test/unbounded_text_wrapping_test.rb` parse the source text of
  `application.css`; they cannot simply keep pointing at a removed source file.
- Turbo Stream responses target stable ids such as `flash_messages` and Entry
  ids. A styling conversion may not rename those contracts accidentally.

### Green reference receipt

The pre-migration reference tree at `14f45bc` passes:

- `bin/rails test`: 230 runs, 3,822 assertions;
- `bin/rails test:system`: 81 runs, 1,640 assertions through headless Chrome;
- `bin/rubocop`: 102 files, no offenses;
- CRAP at or below 6 for all measured methods;
- jscpd with zero clones;
- `Bujo::RapidLog*` mutation: 1,105 killed, zero alive.

Counts may legitimately rise as acceptance coverage is added. No count may fall
without explaining which behavior was removed or consolidated.

## Target technical architecture

### Integration choice

Use the official
[`tailwindcss-rails`](https://github.com/rails/tailwindcss-rails) v4 gem. It
ships the Tailwind executable through Ruby gems, builds during Rails test and
asset preparation, and avoids introducing Node solely for CSS. The current
[Rails asset-pipeline guide](https://guides.rubyonrails.org/asset_pipeline.html)
documents both the standalone integration and Node-based `cssbundling-rails`;
the standalone path matches this repository's import-map/Propshaft setup.

At implementation time:

1. Pin `tailwindcss-rails` to the approved v4 compatibility range.
2. Record the resolved `tailwindcss-ruby` version in `Gemfile.lock`; do not
   float across a Tailwind upgrade during the migration.
3. Run `bin/rails tailwindcss:install` only on the migration branch and review
   every generated change. The installer may replace `bin/dev`, create a
   `Procfile.dev`, touch the layout, and create asset directories; generated
   defaults are suggestions, not permission to overwrite Bujo's shell.
4. Add no Tailwind plugins initially. In particular, do not add DaisyUI,
   `@tailwindcss/forms`, a generic component library, or a date-picker package.

### Development runner

Prefer the gem's Puma watcher plugin over adding a global Foreman dependency:

- keep `bin/dev` as the simple Rails server entry point;
- enable Tailwind's watch plugin only in development in `config/puma.rb`;
- retain the ability to run Rails directly with a Tailscale binding;
- prove that editing an ERB template or Tailwind source rebuilds CSS without a
  second manually managed process;
- document `bin/rails tailwindcss:build` as the deterministic one-shot build.

If the pinned gem cannot run the watcher reliably under this Ruby/Puma version,
fall back to a committed `Procfile.dev` and a Bundler-managed process runner.
Do not rely on `gem install foreman` outside the repository without recording
that dependency.

### Source layout

The intended end state is one compiled asset and several readable source
modules:

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
    tab-bar.css
  pages/
    auth.css
    collections.css
    daily.css
    future.css
    monthly.css
    monthly-migration.css
app/assets/builds/
  tailwind.css                 # generated; ignored except .keep
```

During coexistence, `legacy.css` lives under `app/assets/tailwind/` and is
imported into the compiled bundle in a deterministic layer. Moving it out of
`app/assets/stylesheets/` prevents Propshaft from serving the same rules twice.
The final checkpoint deletes `legacy.css` when it is empty.

`app/assets/tailwind/application.css` should explicitly declare layer order,
import the project sources, and constrain source scanning to locations that
can author real classes (`app/views`, relevant helpers, and
`app/javascript`). Do not scan `docs/`, `mockups/`, screenshots, coverage, or
test prose merely because they contain strings resembling utilities.

The exact directives must match the pinned v4 release. The intended shape is:

```css
@layer theme, base, components, utilities;

/* Tailwind theme and utilities; omit preflight.css during migration. */
@import "tailwindcss/theme.css" layer(theme);
@import "./tokens.css" layer(theme);
@import "./base.css" layer(base);
@import "./legacy.css" layer(components);
@import "tailwindcss/utilities.css" layer(utilities) source(none);

@source "../../views";
@source "../../helpers";
@source "../../javascript";
```

This outline must be proven with the installed compiler before it is committed;
it is not a substitute for reading the versioned installer output. Tailwind's
[Preflight documentation](https://tailwindcss.com/docs/preflight) explicitly
supports omitting the reset for an existing application.

### Token bridge

Keep the existing semantic CSS variables and map them to Tailwind utilities
rather than replacing them with generic palette names:

| Existing authority | Tailwind-facing concept |
|---|---|
| `--bg` | page background |
| `--surface` | controls and selected surfaces |
| `--ink` | primary ink |
| `--muted`, `--faint` | secondary and tertiary ink |
| `--line` | rules and control borders |
| `--accent`, `--warn` | intentional action and refusal ink |
| `--selected-row`, `--today-row` | state surfaces |
| `--font-body`, `--font-serif`, `--font-mono` | current hand and glyph fallback |

Use Tailwind v4 `@theme inline` mappings so utilities such as `bg-page`,
`bg-surface`, `text-ink`, `text-muted`, `border-rule`, and `font-hand` resolve
through the live `data-theme`/`data-hand` variables. Tailwind's
[theme-variable documentation](https://tailwindcss.com/docs/theme) confirms
that custom design tokens can remain CSS variables rather than adopting the
default Tailwind palette.

Do not encode dark colors twice in utility strings. Theme switching must
continue to change token values at the root so the same markup works for
system, light, and dark preferences.

### Class strategy

Use a hybrid strategy:

- static Tailwind utilities in ERB for local layout and state;
- small component classes for repeated primitives and complex selectors;
- semantic classes and `data-*` attributes retained as stable behavior/test
  hooks even when they no longer carry most visual declarations;
- no tests that select opaque utility sequences;
- no dynamic construction such as `"text-#{state}-600"`.

Tailwind scans source as text and cannot understand interpolated fragments.
Every possible utility must appear as a complete literal or as a complete
string in an explicit mapping, per Tailwind's
[class-detection guidance](https://tailwindcss.com/docs/detecting-classes-in-source-files).

Do not add ViewComponent or Phlex in this migration. Existing ERB partials are
sufficient for the first component boundary. A separate decision can revisit
Ruby view objects if partial APIs become hard to maintain.

### Preflight ruling

Preflight is **off for the migration**. Bujo already owns a purposeful base
layer, and an all-at-once reset would remove margins, normalize borders, and
change native controls before page components are ready.

After legacy removal, make one explicit decision:

- recommended: continue without Preflight and retain Bujo's audited base;
- alternative: enable Preflight in a dedicated visual-change commit, rebuild
  every base rule, and rerun the complete screenshot matrix.

Merely importing `tailwindcss` and accepting its reset implicitly is not
allowed.

## Scope boundaries

### In scope

- Tailwind v4 gem/build integration;
- deterministic development, test, CI, and production compilation;
- theme-token and font-token mapping;
- component-by-component conversion of current presentation rules;
- stable semantic hooks for Stimulus and tests;
- removal of obsolete CSS only after rendered parity;
- visual, geometry, accessibility, and asset-build tests needed to prove the
  conversion;
- documentation of the new CSS workflow.

### Out of scope

- Entry, Collection, page-residency, migration, Index, or capture semantics;
- schema or data migrations;
- route/controller/model changes except a truly necessary presentation helper;
- Rapid Log grammar or `lib/bujo/`;
- active sync fields;
- automatic behavior;
- a generic UI kit;
- a custom JavaScript date picker;
- the pending product decisions about Monthly Migration, automatic Index
  registration, `Open by Topic`, unindexing, and Settings;
- visual redesign merely because a default Tailwind example looks different.

The recent phone findings need their own approved behavior amendment. Tailwind
can supply the primitives used to implement that amendment, but framework
migration must not quietly decide those product questions.

## Delivery sequence

Each checkpoint below must be independently green, reviewable, and revertible.

### T0 — baseline and migration specification

Deliverables:

1. Approve this direction and turn it into a bounded slice contract.
2. Capture reference screenshots from the current `main` in Chrome at:
   - 390px paper-light with Rock Salt;
   - 320px Tokyo Night-dark with Architects Daughter;
   - system theme with the default hand.
3. Cover every state listed in the visual matrix below, not just happy pages.
4. Record computed geometry for page width, fixed-tab clearance, Entry columns,
   Calendar columns, form controls, notices, and trailing writing surfaces.
5. Record the current compiled CSS byte size and asset list.
6. Inventory every CSS selector as one of:
   - behavior/test hook;
   - reusable component;
   - page-specific layout;
   - token/base rule;
   - dead or superseded.
7. Confirm root `main` and `origin/main`, clean checkout, stopped swarm, and one
   main worktree before implementation begins.

Gate: no production or rendered change.

### T1 — Tailwind plumbing with byte-for-behavior parity

Deliverables:

1. Add and lock the official v4 gems.
2. Generate then manually reconcile Tailwind's installer changes.
3. Establish the single compiled `tailwind.css` asset.
4. Move the current stylesheet into the Tailwind source tree as `legacy.css`
   without rewriting selectors.
5. Omit Preflight and generate no component utilities yet.
6. Configure the development watcher while preserving direct Rails/Tailscale
   startup.
7. Add explicit Tailwind build steps to local CI and GitHub Actions rather than
   depending only on an implicit Rake hook.
8. Prove `assets:precompile` and a production Docker build contain exactly one
   fingerprinted Tailwind output and no raw source CSS.
9. Compare reference screenshots and computed styles against T0.

Gate: no intended pixel, DOM, behavior, or accessibility difference. Reverting
T1 restores the original stylesheet and removes only build tooling.

### T2 — tokens, base, and shared primitives

Migrate in this order:

1. palette, theme, hand, glyph fallback, dot grid, and box sizing;
2. visually-hidden and focus-visible rules;
3. page container and title-first header structure;
4. buttons, links, labels, text/date fields, and action rows;
5. notices, alerts, errors, and empty-state text;
6. preference control and tab bar;
7. shared Rapid Log kind selector and form shell.

For each primitive:

- define one rendered contract and one owner partial/class;
- migrate every existing use or explicitly leave it in legacy with a TODO tied
  to a later checkpoint;
- preserve minimum 44px targets and visible keyboard focus;
- verify light, dark, system, and all hand choices;
- remove only the legacy declarations now proven unused.

Gate: every page remains usable even though page-specific layouts may still be
legacy CSS.

### T3 — Entry system and core journal pages

Migrate the highest-reuse structure before page specializations:

1. Entry line, signifier, glyph, text, metadata, children, selected state, and
   lifecycle ink;
2. Entry toggle/action strip, Edit, Schedule, and Move-to-Collection steps;
3. Daily Log header, date navigation, list, empty state, and trailing capture;
4. Monthly Tasks list, count, and trailing capture;
5. Future runway, month sections, residents, capture forms, and empty runway.

The Entry component must retain `.entry`, `.entry__toggle`,
`.entry__action-strip`, and `.entry--selected` until the Stimulus controller is
changed to data targets in a separately reviewed refactor. Prefer adding data
targets and then removing class coupling over teaching JavaScript about
Tailwind utilities.

Gate: all existing entry-command matrices and return destinations remain
identical; this checkpoint owns presentation only.

### T4 — complex pages

Migrate one complete page family per commit:

1. Monthly Calendar, including its nested residents, day-writing target, Daily
   chevron, selected day, and expanded capture row;
2. Index and Custom Collection, including empty/populated/missing/deleted and
   tenant-isolated states;
3. Monthly Migration setup, outgoing, second-step, Future, Undo, complete,
   missing, and stale states;
4. session/password pages and remaining error surfaces.

The Calendar should keep custom grid CSS if an explicit seven-column component
is clearer than a long arbitrary-value utility. “Using Tailwind” does not mean
forcing every complex grid into class strings.

Gate: each family passes its full state grid before the next family begins.

### T5 — legacy removal and hardening

Deliverables:

1. Prove `legacy.css` contains no live selector, then delete it.
2. Remove duplicate utilities, dead semantic style classes, and obsolete
   comments while preserving semantic behavior hooks.
3. Verify Tailwind emits every conditional class in production mode; no class
   may exist only because development scanning accidentally saw a test or doc.
4. Compare final compiled size to the T0 baseline and explain meaningful growth.
5. Run security scans against the new gem lockfile.
6. Run the complete quality battery and production asset build.
7. Update README development instructions, `PLAN.md`, `HANDOFF.md`, and the
   repository session instructions only after the migration actually lands.

Gate: there is one compiled CSS asset, no legacy source, and no unexplained
visual regression.

### T6 — operator phone review and rollout

1. Run the final candidate locally over Tailscale on the actual iPhone.
2. Walk every state in both themes and at least two hands.
3. Test native date selection, keyboard focus, rotation, browser zoom, long
   entry text, and the bottom safe area.
4. Obtain explicit integration approval.
5. Merge and push; do not deploy automatically.
6. When the operator later deploys, inspect fingerprinted CSS loading and
   Turbo navigation on production before declaring the migration complete.

## Squad assignment graph

T0 remains operator/planning-session work and must be approved before the
squad starts. The squad receives the approved migration specification,
reference receipt, screenshots, selector ledger, module map, and this ordered
graph as one theme packet.

| Order | Assignment | Worker | Depends on | Concurrency rule |
|---|---|---|---|---|
| 1 | Tailwind plumbing and legacy-bundle parity (T1) | Sol High implementer | approved T0 and squad tooling prerequisite | exclusive |
| 2 | Plumbing adversarial review | Grok 4.6 High hardener/reviewer | assignment 1 | exclusive; may route a bounded repair |
| 3 | Tokens, base, page shell, fields, notices, preferences, tab bar, Rapid Log shell (T2) | Sol High implementer | accepted plumbing | exclusive |
| 4 | Shared-primitives architecture review | Sol High architect | assignment 3 | exclusive; shared contracts freeze after acceptance |
| 5 | Entry component and Entry command surfaces | Sol High implementer | accepted primitives | exclusive |
| 6A | Daily, Monthly Tasks, and Future page composition | Sol High implementer | accepted Entry component | may overlap 6B only |
| 6B | Monthly Calendar composition and geometry | Sol High implementer | accepted Entry component | may overlap 6A only |
| 7A | Index and Custom Collection pages | Sol High implementer | 6A and 6B integrated | may overlap 7B only |
| 7B | Monthly Migration, authentication, and remaining errors | Sol High implementer | 6A and 6B integrated | may overlap 7A only |
| 8 | Cross-page cleanup, dead CSS removal, production build, and quality evidence (T5) | Grok 4.6 High cleaner/hardener | all page families integrated | exclusive |
| 9 | Specification, behavior, visual, accessibility, and rollback verification | Sol XHigh QA | hardening accepted; no other worker active | terminal and exclusive |

Spawn a Sol Max specification worker only when an accepted packet is missing a
testable contract or a finding exposes a genuine specification gap. It may
clarify the packet but may not expand product behavior. Ordinary implementation
findings return to a bounded repair assignment instead of reopening product
design.

The assignment template names are exact: use `coder` for every implementer,
`hardener` for the adversarial review, and `cleaner`, `architect`, `qa`, or
`specifier` only for the matching rows above. The default worker profile is
the Sol High implementation/merger fallback; it is not permission to invent
new role names.

### Parallel ownership rule

Assignments 6A/6B and 7A/7B are the only intended parallel pairs. Before each
pair starts, the leader records an exact module map. Parallel workers may read
shared files but may not both edit them.

During page-family work, these are frozen shared owners:

- `app/assets/tailwind/application.css`, `tokens.css`, and `base.css`;
- shared component sources under `app/assets/tailwind/components/`;
- the application layout, shared page shell, tab bar, preferences, Rapid Log,
  and Entry partials;
- shared Stimulus controllers and test helpers.

If a page worker proves a shared change is necessary, it reports the need to
the leader. The leader pauses the affected parallel work, routes one bounded
shared-component repair, integrates it, and only then resumes dependent page
assignments. Workers must not independently patch the same shared primitive and
leave conflict resolution to a merger.

### Acceptance and integration boundaries

- Every assignment starts from the current integration-branch head and carries
  its own executable acceptance commands.
- A worker result is not accepted from prose alone; its declared build, test,
  browser, or quality evidence must be reproducible.
- `squadd` is the only process allowed to merge accepted assignment commits into
  `codex/tailwind-v4` while the squad is active.
- Merge-conflict workers resolve mechanics only and may not choose between
  competing product or component contracts.
- Terminal QA verifies the accumulated candidate, not merely the last diff.
- After QA passes, stop and retire the squad. The operator runs the real-phone
  review before authorizing root integration into `main`.

## Component migration matrix

| Surface | Current owner | Tailwind target | Principal risk |
|---|---|---|---|
| Root theme and hands | `application.css`, layout `data-*` | token bridge plus base source | system/explicit theme precedence or glyph fallback drifts |
| Page shell/header | repeated `daily-log*` classes | shared shell/header partial contract | title-first order or fixed-tab clearance changes |
| Preferences | preference partials plus page-specific placement | one shared utility/component | moving controls becomes an unauthorized Settings decision |
| Notices/errors | shared flash partial plus auth one-offs | notice variants | success still resembles an input or appears before the title |
| Buttons/fields | several page-specific classes | action and field primitives | native date appearance, 44px targets, disabled/focus state |
| Tab bar | shared partial | tab component | safe-area overlap and active-state contrast |
| Rapid Log | shared partial | kind selector and form component | selected kind no longer matches hidden input |
| Entry row | Entry partial family | stable semantic hook plus utilities | wrapping, glyph fallback, metadata squeeze, Stimulus selectors |
| Daily | Daily template | page composition | empty/trailing tap surface shrinks |
| Monthly Tasks | Tasks partial | page composition | entries and trailing capture stop sharing height |
| Monthly Calendar | Calendar partial | explicit complex grid | day, bullet, text, metadata, and chevron misalign |
| Future | Future partials | runway/month composition | baselines and empty-month capture drift |
| Index/Collection | Collection templates | page composition | invisible creation target, long Topic wrapping, state disclosure |
| Monthly Migration | migration partial family | staged page composition | action availability or stage meaning changes during restyle |
| Auth/password/errors | generator-era templates | shared form/page primitives | unthemed or inaccessible fallback pages remain |

## Verification plan

### Asset and tooling tests

Add deterministic checks for:

- `bin/rails tailwindcss:build` succeeds from a clean checkout;
- a second build without source changes is byte-stable;
- test preparation cannot use a stale compiled file;
- `bin/rails assets:precompile` emits the expected digest and no duplicate
  standalone `application.css`;
- the Docker build succeeds without Node or network-fetched CSS tooling beyond
  Bundler's locked gems;
- `stylesheet_link_tag :app` loads the compiled output exactly once;
- Turbo reload tracking remains present;
- production-mode class extraction includes every conditional variant.

### Fast-test changes

Do not preserve implementation-coupled regex tests merely by pointing them at
generated minified CSS:

- replace `test/lettering_tokens_test.rb` with a focused token-source contract
  for the semantic hand mappings plus rendered system coverage;
- replace the source-regex assertions in
  `test/unbounded_text_wrapping_test.rb` with browser geometry assertions where
  wrapping behavior is actually observable;
- retain controller/model tests unchanged unless a view assertion refers to a
  class that no longer serves a semantic purpose;
- keep fixtures, real database objects, explicit ordering, and fixed dates per
  the project testing conventions.

### Authoritative browser matrix

The Rails headless-Chrome system lane remains authoritative. For every changed
surface, test 390px light/Rock Salt and 320px dark/Architects Daughter; sample
system/default theme and the remaining hands across the suite.

Required state coverage:

| Page | States |
|---|---|
| Sign in/password | normal, refusal, narrow phone |
| Daily | empty, populated, long text, selected actions, Edit, Schedule empty/selected, Move, refusal |
| Monthly Calendar | empty day, populated day, today, three kinds, expanded capture, long resident |
| Monthly Tasks | empty, populated, lifecycle states, expanded capture |
| Future | empty months, populated month, long text/meta, expanded capture |
| Index | empty, populated, creation open, refusal, long Topic |
| Collection | empty, populated, indexed/unindexed under the then-approved product contract, Manage, missing/deleted |
| Monthly Migration | setup empty/populated, outgoing, both second steps, Future task/event, Undo, checkpoints, complete, stale/refused/missing |

For each applicable state assert:

- no horizontal overflow;
- no content beneath the fixed tab bar or unsafe bottom area;
- title is first visible page content;
- visible focus and truthful `aria-expanded`/`aria-current` state;
- every interactive target is at least 44×44 CSS px;
- full text and control visibility at both phone widths;
- Entry and Calendar baseline/column tolerances;
- empty and selected native date control legibility;
- notice/error geometry is distinguishable from an editable field;
- light/dark contrast and selected-state readability;
- trailing blank writing surfaces begin immediately after content and extend to
  the tab boundary.

Screenshots supplement assertions. They do not replace DOM, geometry,
accessibility, request, or domain checks.

### Quality battery

Every Tailwind checkpoint runs at minimum:

```sh
bin/rails tailwindcss:build
bin/rails test
bin/rubocop
bin/rails test:system
SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin/rails assets:precompile
```

The terminal candidate also runs:

```sh
COVERAGE=1 bin/rails test
crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
docker build -t bujo-tailwind-verification .
```

Rapid Log mutation is unchanged in scope because Tailwind must not touch the
parser. A changed mutation receipt is a blocking scope finding.

## CI and deployment changes

### GitHub Actions

- Add an explicit Tailwind build step before fast and system tests.
- Cache only Bundler artifacts; the generated stylesheet is cheap and should be
  rebuilt from source on every job.
- Upload failed system screenshots as today.
- Add one production asset-precompile job or step so development watcher success
  cannot mask production compilation failure.
- Correct the existing workflow's branch trigger separately if needed; do not
  hide that unrelated change inside Tailwind migration.

### Local development

- `bin/dev` starts Rails plus Tailwind watching through the chosen repository-
  owned mechanism.
- `bin/rails tailwindcss:build` is the repair command when generated CSS is
  missing or stale.
- Direct Tailscale review continues to work by binding Rails to the Tailscale IP;
  CSS watching must not require a second terminal.
- Document how to distinguish a stale asset from a browser cache issue.

### Docker and Kamal

- Keep the current multi-stage Dockerfile and Node-free image unless the pinned
  gem proves otherwise.
- Verify `assets:precompile` invokes the Tailwind build in the build stage.
- Ensure generated CSS is copied into the final image and fingerprinted under
  `public/assets`.
- Preserve Kamal's `asset_path` and deployment boundary.
- Do not deploy as part of migration QA; the operator owns deployment.

## Risks and controls

| Risk | Control |
|---|---|
| Preflight resets the whole application | omit it; any later enablement is a separate reviewed commit |
| Legacy and Tailwind rules fight by specificity/order | one compiled bundle with explicit cascade layers and an ownership ledger |
| Propshaft serves source and output twice | keep Tailwind sources outside normal served stylesheets and inspect rendered links/assets |
| Installer overwrites `bin/dev` or layout | run only on a branch, review generated diff, preserve Bujo shell manually |
| Production omits dynamically constructed utilities | full literal class mappings, constrained source scanning, production build tests |
| Stimulus depends on a removed semantic class | retain hooks first; migrate JS to data targets before removing any hook |
| Tests pass against stale generated CSS | explicit clean build in every CI lane and before screenshots |
| Theme or hand changes flash/default incorrectly | preserve root token model and test system/light/dark plus all hands |
| Tailwind defaults erase the bespoke look | use Bujo tokens; no component kit/default palette; screenshot parity gate |
| Date input remains visually confusing | treat closed-field presentation as a separate approved component correction; Tailwind alone is not the picker |
| Large mixed conversion obscures product regressions | independent checkpoints and no journal behavior changes in migration commits |
| CSS-source tests become meaningless | replace with token contracts or rendered/computed behavior, not generated-text regexes |
| Bundle grows despite utility pruning | record T0 and final sizes; constrain sources and inspect generated output |
| External Google Fonts make visual tests nondeterministic | wait for fonts in browser assertions now; vendor fonts only in the existing later PWA scope |

## Relationship to the current phone findings

The latest dogfood notes contain both styling defects and product decisions.
They must not be silently conflated with Tailwind adoption.

Recommended ordering:

1. Approve the Monthly Migration and Index behavior corrections in their own
   source-aligned amendment.
2. Land T1 Tailwind plumbing with visual parity.
3. Land T2 shared primitives, including fields, notices, headers, and page
   shell, still without changing workflow semantics.
4. Implement the approved phone correction using those primitives: date-field
   presentation, Calendar columns, preference destination, Migration entry
   point/copy, Index creation/navigation, and notice treatment.
5. Continue T3–T5 until legacy CSS is gone.

This ordering avoids polishing a component twice while keeping the semantic
change reviewable apart from framework churn.

## Rollback strategy

There is no database change, so rollback is entirely code-and-assets:

- T1 preserves the full legacy source inside the compiled Tailwind entry;
- each later commit converts one named component family and deletes only its
  proven legacy declarations;
- a failed checkpoint can be reverted without touching journal rows;
- the legacy source is not deleted until T5;
- production rollback uses the prior application image/commit and its prior
  fingerprinted assets;
- no data cleanup, backfill, or sync reconciliation is needed.

## Definition of done

Tailwind migration is complete only when all of the following are true:

- the approved Tailwind v4 gem versions are locked;
- local watch, one-shot build, test preparation, GitHub Actions, asset
  precompile, Docker, and Kamal image construction all use the same source;
- one fingerprinted compiled CSS asset is delivered;
- `legacy.css` and the old standalone `application.css` are gone;
- remaining custom CSS is intentionally owned by tokens, base behavior,
  reusable components, or genuinely complex page layout;
- no JavaScript or tests depend on utility-class strings;
- every conditional utility is statically discoverable in a production build;
- themes, hands, glyph fallback, dot grid, wrapping, focus, 44px targets,
  fixed tabs, and all phone states pass;
- all fast, system, lint, coverage/CRAP, duplication, mutation, security, and
  production-asset gates pass;
- a real iPhone review over Tailscale passes in both themes;
- `PLAN.md`, `HANDOFF.md`, and README accurately describe the landed toolchain;
- no product behavior, schema, parser, sync field, deployment, or journal data
  changed merely because the styling implementation changed.

Success is **not** “zero custom CSS.” Success is one coherent Tailwind-backed
design system whose remaining custom CSS is deliberate, small, testable, and
faithful to Bujo.

## Decisions required before specification

One orchestration decision is resolved: use the approved bounded squad and
model roster described above after its tooling prerequisite lands. The
technical decisions below remain proposed; the recommended answers are
included so approval can be concise:

1. **Standalone Rails gem or Node toolchain?** Use `tailwindcss-rails` v4,
   without Node. **Recommended.**
2. **Enable Preflight?** Omit it throughout migration and likely retain Bujo's
   audited base permanently. **Recommended.**
3. **Utility-only markup or hybrid components?** Keep semantic hooks and use a
   hybrid of static utilities plus small component CSS. **Recommended.**
4. **One rewrite or staged landing?** Use T0–T6 checkpoints, each green and
   revertible. **Recommended.**
5. **Combine phone behavior corrections with migration?** Approve them
   separately, then implement them after plumbing/shared primitives and before
   the final page conversion. **Recommended.**
6. **Add a component framework too?** No; keep Rails partials for this
   migration and revisit only if they become an evidenced constraint.
   **Recommended.**
