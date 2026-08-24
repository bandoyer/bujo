# Handoff — paused mid-slice 1.3 (2026-08-24)

Snapshot for the next session. `PLAN.md` remains the living plan;
this file is the parked-state detail. Delete it once 1.3 is back in
flight.

## Exact state

- **Merged and verified on `main`**: slices 1.1 (rapid-log parser,
  mutation 1105/1105) and 1.2 (entries & collections, 21/21 operator
  probes). Suite at last check: 66 runs green, all bars passing.
- **Slice 1.3 (Daily Log UI + themes) is specced, not started.**
  `docs/slices/1.3-daily-log.md` is current: it already folds in ALL
  rulings, including the two the specifier raised in dialog before
  the pause (`default_kind` allowlist → `:task` fallback; migrated
  meta `→ SEP 1` from the successor). The dialog itself was abandoned
  with the swarm — nothing from it is lost.
- **The swarm is DOWN** (`swarm down` ran; herdr workspace closed,
  handoffd stopped). No 1.3 work was committed by any role — the
  specifier had only fast-forwarded its branch to main. Role branches
  and worktrees are otherwise at the 1.2 terminal state; they'll sync
  forward on the next run.

## To resume slice 1.3

1. From a herdr session in this repo: `swarm up`, answer any pane
   startup dialogs (`swarm bootstrap <role>` after).
2. Kick off:
   `swarm prompt specifier "Specify and drive the chain for docs/slices/1.3-daily-log.md — the Daily Log screen and theme system. The spec is current and pre-decides every ruling, including the default_kind allowlist and the migrated-row meta. The system lane is this slice's acceptance evidence; model, lib, and db layers are out of scope — report findings instead of touching them."`
3. Arm a watcher (role-branch commits + a 30-minute quiet alarm — the
   swarm's known stall class is a role stopping between protocol
   steps: finish-without-handoff, accept-without-working; the fix is
   a targeted `swarm prompt <role>` nudge, never a restart).
4. At the qa terminal broadcast: operator review before merge —
   drive the nine ruled browser flows, audit theme CSS against the
   token rules (hunt colors defined only inside a media/data-theme
   block), verify model/lib untouched, re-run every bar including
   mutant (must stay 1105/1105).

## After 1.3 merges (operator work, not swarm)

The first deploy: DigitalOcean droplet (chosen, not provisioned; 2 GB
is enough until press-start shares the box), Kamal (already in the
repo), Litestream → a non-DO object store (R2 on the questlog.dev
Cloudflare account), DNS `bujo.questlog.dev` via the zone-scoped
token at `~/.config/cloudflare/questlog-dns-token` (mode 600). The
zone already carries the no-email lockdown; DNSSEC one-click was
suggested to Dan, state unknown.

## Standing conventions (hard-won, do not relearn)

- Kickoff prompts to the specifier say **"specify and drive"**, never
  "implement".
- Operator spec commits stay **docs-only**; PLAN.md/other operator
  files go in separate commits (role contracts validate handoff
  commits by path).
- The role contracts in `swarmforge/contracts/` are already
  Rails-aware (fixed 2026-08-24) — don't regress them.
- Review protocol: independent bar runs, adversarial probes, and
  hand-mutations with **grep-verified application** before trusting a
  kill.
- The `bujo-conventions` and `testing` skills in `.claude/skills/`
  bind interactive sessions; the swarm articles bind roles.
