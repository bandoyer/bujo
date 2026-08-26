# Bujo Mockups

Design-source mockups for a digital Bullet Journal (Ryder Carroll's method) with two clients sharing one system:

- **TUI** for Omarchy/Linux — Tokyo Night palette, ratatui-style panes, vim-ish keys
- **Mobile web app** (Ruby on Rails, Hotwire PWA) — warm paper-and-ink direction

Live, editable canvas: https://claude.ai/code/artifact/749c4391-1504-488c-910e-e830d08efa45

## Screens

| File | Screen |
|---|---|
| `Main.dc.html` | TUI · Daily Log (rapid logging as a command line) |
| `TuiMonth.dc.html` | TUI · Monthly Log (calendar + task panes) |
| `TuiMigrate.dc.html` | TUI · Migration ritual (wizard, nothing auto-rolls over) |
| `TuiIndex.dc.html` | TUI · Index as a fuzzy finder across collections and entries |
| `Today.dc.html` | Mobile · Daily Log with thumb-reach rapid-log bar |
| `Month.dc.html` | Mobile · Monthly Log |
| `MonthTasks.dc.html` | Mobile · Monthly Tasks |
| `Future.dc.html` | Mobile · Future Log |
| `MonthlyMigration.dc.html` | Mobile · Monthly Migration review states |
| `PhoneCaptureCorrection.dc.html` | Mobile · Future/Calendar capture and empty migration checkpoints |
| `PhoneDogfoodCorrections.dc.html` | Mobile · Monthly kind parity, Entry Edit/Schedule, migration Undo, and post-create Collection clarity |
| `Migrate.dc.html` | Mobile · Migration as card-per-task review |
| `AltDark.dc.html` | Alt direction · low-fi dark "terminal-kin" variant |
| `canvas.json` | Canvas layout + design notes (architecture, open questions) |

The `.dc.html` files are the design-canvas source artboards; they render on the canvas linked above rather than standalone in a browser.

## Rapid-logging grammar

The shared core across every client is plain text:

```
• task    x done    > migrated    < scheduled
○ event   – note    * priority signifier
```

One parser in Rails can serve the TUI, the web app, and piped stdin.

## Architecture

The sync design — how data stays consistent between the TUI and the web app — is written up in [../ARCHITECTURE.md](../ARCHITECTURE.md). The short version:

- Rails is the single system of record: Hotwire/Turbo PWA for the phone, one `/api/sync` endpoint for everything else
- The TUI is a local-first Ruby client with a SQLite mirror — cursor-based sync, field-level conflict resolution, offline rapid logging
- TUI auth via the OAuth device grant; web auth via passkeys
- Migration is a deliberate ritual in both clients — the friction is the feature
