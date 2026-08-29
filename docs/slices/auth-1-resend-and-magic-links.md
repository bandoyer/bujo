# Authentication Step 1 - Resend delivery and single-use magic links

Status: **APPROVED 2026-08-29 - implementation authorized through the isolated
`six-cg` swarm. Terminal integration and deployment remain separately gated.
The canonical `bujo.blackcat.dev` web-origin cutover completed independently
before implementation.**

This is Step 1 of the five-step Rails authentication rollout in
`docs/resend-transactional-email.md`. It puts the already configured Resend
provider behind Action Mailer and adds a deliberate, short-lived email sign-in
path for existing accounts. Password sign-in and password reset remain a
temporary rollback until passkeys and recovery have been proven in later
steps.

The provider foundation is already complete and is inherited, not repeated:

- `bujo.blackcat.dev` is verified in Resend in North Virginia (`us-east-1`);
- tracking is not configured, inbound receiving is out of scope, and TLS is
  Opportunistic;
- `bujo-production` has Sending access restricted to that exact domain;
- its credential remains in 1Password and Kamal resolves only the non-secret
  `op://Personal/bujo-production/credential` reference; and
- `RESEND_API_KEY` is exposed only to the Rails application service.

The authority order is `docs/METHOD.md` -> `PLAN.md` -> `ARCHITECTURE.md` ->
`docs/resend-transactional-email.md` -> this contract. Authentication details
follow the current
[Rails record-token API](https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html),
[Rails Active Job guidance](https://guides.rubyonrails.org/active_job_basics.html),
[official Resend Rails adapter](https://resend.com/rails),
[OWASP forgot-password guidance](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html),
and [RFC 3986 fragment handling](https://datatracker.ietf.org/doc/html/rfc3986#section-3.5).
The method contributes the product posture: access is explicit and quiet; no
link fetch, background process, or inferred action pretends the reader chose
to open the journal.

The smallest review board is `mockups/MagicLinkTransition.dc.html`. The older
`mockups/SignIn.dc.html` remains the final passkey-first direction for Steps
3-5. It is not the Step 1 interface and must not cause an unavailable passkey
control to appear early.

## Why this boundary is one slice

Resend delivery and magic-link authentication share one security boundary:
the mailer creates a bearer credential, the provider carries it, the browser
stages it, and Rails consumes it into the existing session mechanism. Shipping
only one half would either configure unused production mail or create a sign-in
path that has not been proved through its delivery seam.

This slice therefore includes:

1. Resend as production Action Mailer's HTTPS delivery adapter;
2. explicit sender and canonical-link configuration;
3. one non-sync user generation counter;
4. request, delivery, scanner-safe landing, and explicit redemption;
5. the temporary magic-first/password-fallback authentication presentation;
6. provider-edge, controller, model, job, mailer, and real-browser tests.

It does not include passkeys, password removal, public signup, account
management, email-address change, a settings page, TUI/device authorization,
PWA activation, generic notifications, or journal behavior. The independently
authorized `blackcat.dev` web-origin cutover is operational prerequisite work,
not authentication implementation.

## Current-source audit

The Rails 8.1 application currently has:

- generator-style password sign-in in `SessionsController`, with a database
  `Session`, a signed permanent `session_id` cookie, and an IP rate limit of ten
  attempts per three minutes;
- generator-style password reset in `PasswordsController`, with an
  enumeration-neutral visible response and `PasswordsMailer.reset(...).deliver_later`;
- `User#has_secure_password`, integer user IDs, no signup route, and no
  magic-link generation state;
- Solid Queue running inside Puma and a worker accepting every queue;
- test delivery in the test environment, but production still uses
  `from@example.com`, `example.com` URL generation, and no enabled delivery
  adapter or error reporting;
- parameter filtering for `email`, `password`, `token`, `secret`, and key-like
  values;
- a deliberately raw generator-era authentication presentation protected by
  Tailwind T0 parity tests; and
- an approved future `SignIn.dc.html` board containing passkeys, which do not
  exist yet.

The current password path is working rollback, not dead code. Step 1 must keep
its behavior usable while deliberately superseding its raw presentation.

## Approved product decision

Step 1 makes **email link the default sign-in method** and puts **Use password
instead** one explicit tap away. This is the smallest transition that will
actually dogfood the intended recovery path while retaining rollback.

- Default sign-in shows only the magic-email form.
- `Use password instead` renders the password form as a separate server state,
  not a disabled control, modal, or JavaScript-only disclosure.
- Password mode offers `Use email instead` and retains `Forgot password?`.
- No passkey control, placeholder, teaser, or unsupported-browser warning is
  rendered in Step 1.
- There is no automatic method selection based on browser, account, prior use,
  or email address.

Dan approved this product choice with the complete contract on 2026-08-29.

## Exact public route contract

Names may follow ordinary Rails helpers, but the public verbs and paths are
fixed:

| Request | Purpose | Side effect | Return |
|---|---|---|---|
| `GET /session/new` | default magic-email sign-in page | none | `200` |
| `GET /session/new?method=password` | temporary password fallback | none | `200` |
| `POST /session` | existing password authentication | valid credentials create the ordinary session | existing safe return path or `/` |
| `POST /sign-in-link` | request a magic link | known account advances its generation and queues delivery | `303` to `/sign-in-link/sent` |
| `GET /sign-in-link/sent` | generic request acknowledgement | none | `200` |
| `GET /sign-in-link/open` | neutral email-link landing page | none | `200` |
| `POST /sign-in-link/open` | explicit bearer redemption | one valid token is consumed and creates the ordinary session | safe return path or `/` |

Every route above is available without an existing session. There is no route
whose path or query contains a user ID, email address, generation number, or
magic token. There is no `GET` that authenticates, consumes a token, or changes
any row.

The existing `DELETE /session` and password-reset routes remain. No signup,
invite, resend-by-GET, token-inspection, provider callback, or inbound webhook
route is added.

## Exact phone interface and copy

Every authentication state uses one shared, responsive auth sheet with the
page title first. It follows the existing light/dark/system theme and stored
hand cookie, but exposes no preference selector before authentication. All
controls are at least 44 CSS pixels tall, labels remain visible, focus is
obvious, text wraps at 320 CSS pixels, and neither theme has horizontal scroll.

### Default magic-email state

Visible order and copy are exact:

1. title: `Open your journal`
2. supporting copy: `Pick up where you left off.`
3. label: `Email`
4. email placeholder: `you@example.com`
5. primary action: `Email me a sign-in link`
6. note: `A one-time link, with nothing to remember.`
7. secondary action: `Use password instead`

The email control uses `type=email`, `name=email_address`, `autocomplete=email`,
`autocapitalize=none`, `spellcheck=false`, `required`, and autofocus. The
submitted value may repopulate after ordinary validation, but it is not placed
in a URL.

### Password fallback state

Visible order and copy are exact:

1. title: `Open your journal`
2. supporting copy: `Use your current password.`
3. label: `Email`
4. email placeholder: `you@example.com`
5. label: `Password`
6. primary action: `Sign in`
7. link: `Forgot password?`
8. secondary action: `Use email instead`

The current field names, password autocomplete, 72-character maximum,
authentication behavior, and generic refusal copy remain. Switching methods is
a `GET`; it never submits, authenticates, or retains a password.

### Link-requested state

This is a dedicated page state, not a green flash styled like a field:

1. title: `Check your email`
2. copy: `If that email belongs to an account, a sign-in link is on its way.`
3. note: `It may take a minute to arrive.`
4. action: `Back to sign in`

It never echoes the submitted address or says whether mail was queued,
delivered, throttled, or matched an account. Refreshing the page sends nothing.
There is no immediate Resend button.

### Neutral link landing

When client-side staging finds a fragment token, visible order and copy are:

1. title: `Open your journal`
2. copy: `This link signs you in once.`
3. primary action: `Open your journal`
4. note: `If you requested more than one link, use the newest email.`
5. secondary action: `Back to sign in`

The button is initially disabled and becomes enabled only after the local
Stimulus controller has staged a nonblank token. It is the only action that
submits the bearer credential.

### Missing, malformed, expired, superseded, or reused link

All refusal reasons converge on the default sign-in page with one non-field
alert:

`That sign-in link is invalid or has expired.`

The normal email form follows immediately so recovery does not dead-end. The
response never distinguishes missing, malformed, expired, newer-link-issued,
already-used, wrong-user, or concurrency-lost cases.

Password-request and password-edit pages adopt the same auth sheet, title-first
hierarchy, fields, buttons, and non-field alert treatment. Their underlying
password semantics and copy remain otherwise unchanged. The frozen Tailwind T0
fixture stays historical; tests that intentionally pin raw auth presentation
are replaced by executable assertions for this accepted auth surface.

## Request and enumeration contract

`POST /sign-in-link` normalizes email through the existing `User` policy and
performs one indexed lookup. It never creates a user.

For a known account:

1. lock that user row;
2. increment `magic_link_version` and commit it before enqueueing;
3. enqueue one `MagicLinkDeliveryJob` with exactly the integer user ID and the
   resulting integer generation; and
4. redirect to the generic acknowledgement.

For an unknown account, enqueue no delivery and make no user change. Known and
unknown requests return the same status, location, flash/session disclosure,
rendered acknowledgement, and copy; normal per-session CSRF bytes are not an
account signal. Enqueue failure is reported internally without an email
address or token and still returns that same public result.

No response claims that an email definitely exists or was sent. Do not add a
sleep casually; if repeated request measurements expose a material known-vs-
unknown timing class after asynchronous delivery is in place, the hardening
pass must close it with a bounded, documented mechanism rather than scattered
delays.

## Rate-limit contract

Magic-link request uses independent server-side budgets:

- ten requests per three minutes per source IP, preserving the existing public
  auth baseline;
- five requests per fifteen minutes per normalized email identity; and
- twenty requests per twenty-four hours per normalized email identity.

The email bucket key is a keyed digest, never the raw address. Known and
unknown addresses enter the same bucket logic. Exceeding any budget returns the
same `303 /sign-in-link/sent` acknowledgement and queues no work; the response
does not reveal which bucket fired or how much capacity remains.

Magic-link redemption is limited to twenty `POST` attempts per ten minutes per
source IP. A limited, malformed, expired, superseded, reused, or competing
redemption creates no session and uses the same refusal destination and copy.
The token's cryptographic strength is not a substitute for this resource-abuse
boundary.

Password sign-in retains its current limit. Password-reset mail receives the
same per-IP and per-address outbound-mail protection during this slice so the
temporary rollback cannot bypass provider-quota and inbox-flood controls.
Rate limiting never locks the account or invalidates existing sessions.

## Token and data contract

Add exactly one user column:

| Field | Type | Constraints | Meaning |
|---|---|---|---|
| `magic_link_version` | integer | `null: false`, default `0`, nonnegative database check | current magic-link generation |

`users.id` remains the Rails generator's integer. Users do not sync, so this
field has no UUIDv7, `hlc`, `server_seq`, revision, tombstone, or client-write
semantics. No new magic-link, nonce, audit, account, or delivery table is
created.

`User` defines a Rails `generates_token_for :magic_link` purpose with an exact
15-minute expiry and embeds only `magic_link_version` in its comparison block.
The generation number is not secret; Rails documents that block values are
human-readable inside the signed token. The token is tamper-evident bearer
material and is treated as secret in every other context.

Issuing a newer request invalidates every earlier generation immediately,
including a link already delivered. Expiry is measured from token generation
inside the delivery job, so queue latency does not consume the reader's
15-minute window. Changing the configured expiry later invalidates previously
issued Rails tokens by design.

Successful redemption:

1. resolves the candidate with `find_by_token_for`;
2. locks that exact user row;
3. resolves and validates the same token again while holding the lock;
4. increments `magic_link_version` before session creation; and
5. creates the ordinary database `Session` through the existing
   `start_new_session_for` path.

Only one of competing redemptions may cross step 4. If ordinary session
creation subsequently fails, the credential remains consumed; the reader must
request another link. This fail-closed result is preferable to restoring a
bearer after a partial authentication attempt.

Magic-link sign-in does not revoke other device sessions, change the password,
mark the email verified, or alter journal data. Password reset keeps its
existing all-session invalidation behavior and also advances
`magic_link_version` when the new password is committed, invalidating every
outstanding email sign-in link. A future email-address change must do the same,
but email editing is not added here.

## Scanner-safe browser handoff

The email URL is constructed only from configured canonical origin plus:

`/sign-in-link/open#<encoded-token>`

RFC 3986 requires the user agent to remove the fragment before dereferencing
the HTTP resource. Therefore Rails, Kamal proxy access logs, and ordinary link
scanners receive only `GET /sign-in-link/open`.

That neutral `GET`:

- never reads a token parameter, looks up a user, advances a generation,
  creates a session, or redirects as authenticated;
- sets `Cache-Control: no-store`, a no-referrer policy, and Turbo no-cache
  metadata;
- renders a normal CSRF-protected form with an initially blank hidden token;
  and
- remains harmless when fetched repeatedly by scanners or previews.

A small, same-origin Stimulus controller is the only fragment reader. On
connect it:

1. copies the fragment value into the hidden form field;
2. removes the fragment immediately with `history.replaceState` without a
   navigation;
3. enables the explicit button only for a nonblank staged value; and
4. never writes the value to a query string, path, cookie, local storage,
   session storage, Turbo snapshot, analytics event, console, or log.

It never auto-submits. JavaScript-disabled or fragmentless visits cannot redeem
and render the unavailable recovery state. Turbo must not cache a DOM
containing the staged token.

The HTML email anchor carries `rel="noreferrer"`; both HTML and text parts put
the token only after `#`. No redirect service, tracking wrapper, URL shortener,
or Resend click/open tracking is allowed.

## Delivery and queue contract

- Add and lock the official `resend` gem at `1.6.0`.
- Production configures `Resend.api_key` only from
  `ENV.fetch("RESEND_API_KEY")` and uses Action Mailer's `:resend` delivery
  method. Missing production configuration fails boot rather than silently
  discarding authentication mail.
- Test always retains Action Mailer's `:test` adapter. No automated test calls
  Resend or another network endpoint.
- Production enables deliveries and raises delivery errors. Resend API errors
  must make the Solid Queue job visibly fail.
- `ApplicationMailer` reads the exact configured sender
  `Bujo <sign-in@bujo.blackcat.dev>`; `from@example.com` disappears.
- Both the new magic-link mailer and existing password-reset mailer use that
  sender and the configured canonical HTTPS origin.

Magic-link mail is queued through a small application job rather than
`MagicLinksMailer(...token...).deliver_later`. Its serialized arguments contain
only `user_id` and `magic_link_version`; they contain no email address, signed
token, fragment, URL, API key, or mail body. At performance time the job:

1. finds the user by integer ID;
2. exits without delivery when the user is absent or its generation is stale;
3. generates the Rails token in process;
4. invokes the Action Mailer synchronously inside the job; and
5. lets delivery exceptions fail visibly.

Do not add automatic retries for an ambiguously delivered magic-link job. A
retry would generate a different expiring token payload, while a reused Resend
idempotency key requires byte-equivalent request content. The safe recovery is
a new reader request, which advances the generation and makes any uncertain
older delivery unusable. This slice does not add an outbound-delivery ledger.

### Exact magic email

| Field | Contract |
|---|---|
| From | `Bujo <sign-in@bujo.blackcat.dev>` |
| To | the persisted normalized address for the matched user |
| Subject | `Your Bujo sign-in link` |
| Primary link copy | `Open your journal` |
| Expiry copy | `This link expires in 15 minutes and works once.` |
| Multiple-request copy | `If you requested more than one, use the newest email.` |
| Safety copy | `If you did not request this, you can ignore this email.` |

The message has equivalent HTML and plain-text parts, no image, attachment,
remote font, tracking pixel, marketing copy, unsubscribe fiction, account
existence detail, password, journal content, or reply promise.

## Canonical origin and deployment configuration

`APP_ORIGIN` and `MAIL_FROM` are explicit non-secret deployment values. Mailer
URLs never derive from an inbound `Host` header.

`APP_ORIGIN` must parse as an absolute HTTPS origin with no credentials, query,
fragment, or non-root path. Production boot fails on a missing or invalid
value. Development and test use their explicit local/test URL settings and do
not need production environment variables.

`APP_ORIGIN=https://bujo.blackcat.dev`

The independently authorized canonical-origin cutover completed before Step 1
implementation, so no production authentication email may ever
be issued for the retired host. The From identity is
`sign-in@bujo.blackcat.dev`. No email may point to an unresolved hostname. The
live end-to-end magic redeem remains an acceptance gate after Step 1 exists on
the reachable canonical origin.

Authentication success consumes only a server-stored internal path captured
from the original protected request; it never redirects to a stored absolute
URL or caller-authored return parameter. Without a safe stored path, return to
`/`. Refusals return to the default sign-in page, never to a protected or
external destination.

Production session cookies remain signed, HTTP-only, SameSite Lax, and become
explicitly Secure. TLS termination remains at Kamal proxy; health checks keep
their existing exception. Step 1 implements the canonical-origin validation;
Step 2 proves it against the already-cut-over live host.

## Failure and state matrix

| State | Required result |
|---|---|
| known normalized email | generation advances once; one safe-argument job; generic sent page |
| unknown email | no user/job/mail change; same public acknowledgement and disclosure |
| malformed/blank email | no lookup side effect or exception; generic acknowledgement |
| enqueue failure after generation advance | error reported without PII/token; old links stay invalid; generic acknowledgement |
| stale job after newer request | no mail and no exception |
| Resend accepts mail | job succeeds; provider message ID may remain provider/job metadata but is not a new app row |
| Resend timeout, 4xx, 5xx, or invalid key/from domain | job fails visibly; no success claim beyond the generic request page |
| scanner or repeated `GET` | neutral page only; generation/session unchanged |
| missing fragment | unavailable recovery state; no POST or lookup |
| malformed token POST | generic refusal; no session or user change |
| expired token POST | generic refusal; no session or user change |
| older token after a new request | generic refusal; no session or user change |
| first valid POST | generation advances and one ordinary session is created |
| reused or competing POST | generic refusal; no second session |
| already signed-in browser redeems valid link | token is consumed and the normal session cookie is replaced; other stored sessions are not revoked |
| password sign-in/reset | remains usable with existing semantics through Resend delivery |
| test/development | no Resend network request |

No state renders a success alert that resembles an input. No failed state
creates an account, session, token row, journal row, or provider retry loop.

## Privacy and logging

- Existing parameter filters must continue to cover every `token`, email,
  password, secret, and key field.
- Complete magic URLs, fragments, token prefixes/suffixes, mail bodies, and API
  keys never enter Rails logs, error context, job arguments, fixtures,
  screenshots, analytics, or test failure messages.
- Rate-limit keys contain a keyed digest rather than a raw email address.
- Operational errors may record job ID, exception class, provider status, and a
  nonreversible user identifier digest; they do not record the recipient or
  token.
- The requested page and refusal copy reveal no account membership.
- Authentication responses are `no-store`; email/redeem pages send a
  no-referrer policy.
- No third-party JavaScript, CAPTCHA, analytics, tracking pixel, or remote
  asset is introduced.

## Journal and architecture invariants

This authentication slice does not change the journal domain.

- Entry and Collection IDs remain UUIDv7; user IDs remain integer.
- Entry capture, correction, hierarchy, state, residency, and append-only
  movement remain untouched.
- Tenant ownership checks remain server-derived from the authenticated
  session.
- Soft deletion remains non-cascading; no user or session deletion behavior is
  broadened.
- `hlc`, `server_seq`, revision, tombstone, and sync fields remain untouched.
- `lib/bujo`, the Rapid Log parser/renderer, grammar, dates, and glyphs remain
  untouched.
- No authentication secret becomes sync data.

## Test contract

All tests use Minitest, fixtures, the real test database, Action Mailer's test
adapter, and the existing headless-Chrome system lane. Doubles are allowed
only at the actual Resend HTTP delivery edge. No test needs an in-app browser
backend or a live mailbox.

### Fast lane

Model and migration tests prove:

- existing users backfill generation `0`; default/null/check constraints hold;
- issued versions advance monotonically under the user lock;
- a newer request invalidates an older generated token;
- the token is valid immediately before 15 minutes and invalid at or after the
  expiry boundary;
- first consumption advances the generation; sequential reuse fails;
- two competing consumptions produce exactly one success;
- a successful password reset advances the generation and invalidates every
  outstanding magic link;
- malformed, blank, expired, superseded, and reused values make no session or
  unrelated user change.

Controller tests prove the full route/return matrix, including:

- public GETs are inert and every protected journal route stays protected;
- known/unknown/blank requests have the same redirect and acknowledgement;
- only a known request advances a version and queues the safe two-integer job;
- enqueue failure and every rate-limit bucket keep public parity;
- crafted tokens and return destinations cannot authenticate or redirect
  externally;
- a valid redemption uses the ordinary session path once and preserves other
  device sessions;
- password sign-in and reset remain usable.

Job and mailer tests prove:

- queued arguments contain no token, URL, email, or secret;
- a stale or missing-user job performs no delivery;
- sender, recipient, subject, exact copy, multipart shape, and 15-minute claim;
- the canonical origin is trusted configuration, the token appears only after
  `#`, and no query/path contains it;
- the HTML anchor is no-referrer and neither part contains remote/tracking
  content;
- Resend adapter selection and missing-production-config failure;
- a stubbed provider success crosses the official Action Mailer adapter once;
- a stubbed provider failure escapes the job visibly;
- test mode never invokes Resend.

### Browser lane

At 390px light/Rock Salt and 320px dark/Architects Daughter, plus the existing
system/default profile, prove:

1. title-first default magic form, exact controls/copy, focus, and method
   switch;
2. complete password fallback and existing invalid-password refusal;
3. generic link-requested state for known and unknown addresses;
4. a fragment-bearing visit causes only an inert GET, removes the fragment,
   stages the hidden token, and requires the explicit button;
5. explicit redemption signs in once and returns safely;
6. reuse/expired/missing states converge on the exact recovery alert;
7. no staged token survives Turbo snapshot/back navigation or appears in the
   visible DOM, current URL, console, or captured test diagnostics;
8. password request/edit use the same auth sheet;
9. controls remain at least 44px, labels are associated, keyboard focus is
   visible, text wraps, and there is no horizontal overflow in either theme;
10. no passkey, signup, tab bar, journal content, or preference control appears.

The existing complete quality bars remain binding:

```sh
bin/rails test
bin/rubocop
COVERAGE=1 bin/rails test && crap4rb --lcov coverage/lcov.info app/ lib/
jscpd --min-tokens 50 --reporters console app/ lib/
bin/rails test:system
bundle exec mutant run --integration minitest -- 'Bujo::RapidLog*'
```

Rapid Log mutation scope does not expand to Active Record authentication
models. No mutation exception or reduced bar is authorized.

## Implementation boundary

Expected files are limited to:

- `Gemfile` / `Gemfile.lock` for exact Resend SDK installation;
- one additive users migration and `db/schema.rb`;
- `User`, the two small magic-link controllers, one delivery job, one mailer,
  templates, routes, and the small fragment-staging Stimulus controller;
- authentication/session return safety and cookie security where ruled above;
- production/development/test Action Mailer configuration and Resend
  initializer;
- the shared auth views and `app/assets/tailwind/pages/auth.css`;
- focused fixtures, previews, fast tests, and system tests;
- `config/deploy.yml` clear values for `APP_ORIGIN` and `MAIL_FROM`; and
- planning/handoff receipts after approval and implementation.

Do not add Devise, Rodauth, passwordless-auth gems, JWTs, OAuth, WebAuthn,
Redis, a new queue, a service-object hierarchy, a mail/event ledger, generic
rate-limit framework, React, ViewComponent, a CSS framework change, or another
JavaScript dependency. Rails controllers/models, Action Mailer, Active Job,
Stimulus, ERB, and the existing Tailwind ownership are sufficient.

## Rollout and rollback

Implementation may be merged independently, but Dan remains the only deployer.
Before any production activation:

1. all automated lanes pass without network access;
2. production config resolves the 1Password key and boots with an explicit
   reachable `APP_ORIGIN`;
3. one provider-level test reaches at least two major mailbox providers and
   headers prove SPF, DKIM, and DMARC alignment;
4. no live bearer/token is copied into chat, source, screenshots, or commands
   retained in shell history; and
5. password sign-in is re-proven as rollback.

The Step 1 rollback is configuration/code rollback to password-only sign-in.
The additive generation column may remain harmlessly at zero/current values.
Rolling back never requires deleting users, sessions, mail history, or journal
data. Do not revoke the Resend key merely to roll back the UI; revoke or rotate
only for a credential incident.

The `bujo.blackcat.dev` proxy switch, TLS, health verification, and old-host
retirement completed 2026-08-29 as explicitly authorized operational
prerequisite work, using the unchanged deployed image. The final live
magic-link round trip and host-authorization proof remain Step 2 because they
require Step 1 code. Passkeys are Step 3. Recovery proof is Step 4. Password
UI/code retirement is Step 5.

## Approval receipt

Approval of this contract settles:

- magic-email-first with one-tap password fallback;
- exact UI and email copy;
- 15-minute, generation-invalidated, globally one-use tokens;
- fragment landing plus explicit POST;
- safe job serialization and no ambiguous auto-retry;
- enumeration/rate-limit behavior;
- existing-session and return-destination behavior;
- Resend sender/configuration/failure behavior; and
- the exact boundary between this slice and Steps 2-5.

Dan approved this contract on 2026-08-29 and, after the independently completed
canonical-origin cutover and production password re-proof, authorized the
planning commit/push and isolated `six-cg` implementation run. Passing terminal
QA does not authorize root integration, deployment, production mail, or the
live magic-link round trip; each remains a separate operator gate.
