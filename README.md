# bujo

A digital Bullet Journal (Ryder Carroll's method): rapid logging,
daily/monthly/future logs, collections, and migration as a deliberate
ritual. Rails 8 system of record serving a Hotwire PWA for the phone,
with a local-first TUI client (separate repo) to follow.

- **[PLAN.md](PLAN.md)** — living plan: current status, phases,
  decisions. Start here.
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — how sync between the TUI and
  the web app works.
- **[mockups](mockups/README.md)** — the
  design mocks this app is built to.

## Development

```sh
bin/setup                      # bundle, db prepare
BUJO_EMAIL=you@example.com BUJO_PASSWORD=... bin/rails db:seed
bin/dev
```

Quality bars (all must pass before merging):

```sh
bin/rails test                                                  # fast lane
bin/rubocop
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bin/rails test:system                                           # slow lane
```

Built with [swarm-forge-herdr](https://github.com/bandoyer/swarm-forge-herdr)
agent swarms; the swarm config lives in `swarmforge/`.
