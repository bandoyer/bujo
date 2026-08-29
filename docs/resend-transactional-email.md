# Resend transactional email plan

**Status:** `blackcat.dev` was acquired and its root sending records verified
2026-08-26. After Resend expanded its free tier to three verified domains,
Bujo moved to the stronger app-specific boundary: `bujo.blackcat.dev` was
verified through Resend's Cloudflare automatic setup in North Virginia
(`us-east-1`) on 2026-08-29. Tracking is not configured, receiving is out of
scope, and TLS remains Opportunistic. The Sending-only `bujo-production` key
is restricted to that exact domain and remains stored in 1Password. Its
non-secret Kamal reference is now wired for deployment; mailer and
authentication implementation has not started. The approved Step 1 contract
is `docs/slices/auth-1-resend-and-magic-links.md`, with review board
`mockups/MagicLinkTransition.dc.html`. Its isolated `six-cg` implementation run
was authorized on 2026-08-29; terminal integration and deployment remain
separately gated. The canonical-origin cutover to `https://bujo.blackcat.dev` is
complete: DNS, TLS, the canonical redirect, and health were verified on the
unchanged production image before the old `bujo.questlog.dev` proxy host and A
record were retired. Press Start's likely origin is
`https://lift.blackcat.dev`, but that hostname remains tentative until its own
deployment decision.

## Provider foundation

- [x] Acquire `blackcat.dev`.
- [x] Select Resend, independently verified app subdomains, and separate app
  keys.
- [x] Select `Bujo <sign-in@bujo.blackcat.dev>` as Bujo's From identity.
- [x] Confirm the Cloudflare zone and add Resend's generated DNS records.
- [x] Verify Resend's aggregate `blackcat.dev` domain status.
- [x] Verify `bujo.blackcat.dev` in `us-east-1` with tracking disabled.
- [x] Confirm Cloudflare saved the monitoring-mode DMARC record
  `v=DMARC1; p=none;`.
- [x] Create the domain-restricted `bujo-production` Sending key and store it
  in 1Password.
- [x] Restrict `bujo-production` to `bujo.blackcat.dev` and wire its non-secret
  `op://Personal/bujo-production/credential` reference into Kamal.

## Rails authentication rollout

Current position: **Step 1 approved and authorized for implementation through
the isolated `six-cg` swarm; no application code in these five steps had
started at the planning baseline. The Step 2 operational web-origin cutover is
complete; its live magic-link round trip remains pending until Step 1 exists.**
The approved final visual direction is
[`mockups/SignIn.dc.html`](../mockups/SignIn.dc.html): passkey first, magic
email second, no password in the final product UI. The approved Step 1
transition is [`mockups/MagicLinkTransition.dc.html`](../mockups/MagicLinkTransition.dc.html):
magic email first, password one tap away, and no premature passkey control.

- [ ] **1 — Resend delivery and magic links.** Put Resend behind Action Mailer,
  send from `Bujo <sign-in@bujo.blackcat.dev>`, and add short-lived, single-use
  magic links for known accounts. Preserve enumeration parity, rate limits,
  and the current password path as a temporary rollback while this proves out.
- [ ] **2 — Canonical origin.**
  - [x] Move the live Rails endpoint to `https://bujo.blackcat.dev`, set the
    deployment contract for canonical production URL generation, verify DNS,
    TLS, redirect, and health, and retire the old `bujo.questlog.dev` proxy host
    and A record without changing the deployed image.
  - [ ] After Step 1 exists, verify a real provider-delivered magic-link round
    trip and prove no authentication link is issued for `questlog.dev`.
- [ ] **3 — Passkeys.** Add passkey registration and username-free sign-in with
  discoverable credentials. Pin the allowed WebAuthn origin to
  `https://bujo.blackcat.dev` and the RP ID to `bujo.blackcat.dev`; never
  register Bujo credentials on `questlog.dev` or share them with Press Start.
- [ ] **4 — Recovery proof.** Register at least two independent passkeys (for
  example phone and laptop), prove both in production, and prove magic email
  still recovers access when a passkey is unavailable.
- [ ] **5 — Retire the password UI.** Remove password sign-in and reset from the
  product UI only after Steps 1–4 pass in production. Decide separately when
  to remove transitional password data and rollback code.
- [ ] Confirm Press Start's hostname and implement its production delivery
  during that project's deployment slice; it gets its own API key and exact
  passkey RP ID.

This plan covers account and authentication email sent by Bujo and Press Start.
It does not cover newsletters, marketing mail, or a human mailbox.

## Decisions

- Use one Resend account with one independently verified sending subdomain per
  application. Bujo owns `bujo.blackcat.dev`; Press Start will verify its own
  subdomain only after its hostname is settled.
- Send Bujo authentication mail from
  `Bujo <sign-in@bujo.blackcat.dev>`. The local part does not imply an inbox;
  receiving and reply handling remain out of scope.
- Give each production application a separate Resend API key with Sending
  access restricted to its exact verified domain. Never share one key between
  apps and never give an application a Full access key.
- Send through Resend's HTTPS API, not SMTP. DigitalOcean blocks outbound
  ports 25, 465, and 587 on Droplets. Local development remains isolated:
  Rails uses its test delivery method and Press Start keeps Mailpit.
- The free-plan quota is shared by both apps. As rechecked 2026-08-29, it is
  3,000 messages per month, 100 per day, and three verified domains. Recheck
  the provider's pricing and limits immediately before implementation.
- Keep the applications independent. They share a provider account and
  billing quota, but no sending domain, API key, application code, deployed
  secret, job queue, failure state, or release step.
- Keep the already verified root `blackcat.dev` domain for now; do not delete
  working DNS while Bujo is being integrated. Retire it separately if no
  application ultimately sends from the root domain.

## Account and DNS setup

1. Confirm the acquired `blackcat.dev` zone is active in Cloudflare before
   configuring production mail. Do not set up `questlog.dev` and repeat the
   work after the domain change.
2. Create the Resend account/team and add the root sending domain, then add an
   app-specific `bujo.blackcat.dev` sending domain.
3. Add exactly the Resend-generated Cloudflare records for each domain:
   return-path MX/SPF and DKIM. Keep them DNS-only where Cloudflare presents a
   proxy choice. The root setup completed on 2026-08-26; the Bujo setup
   completed through Resend's Cloudflare automatic setup on 2026-08-29. Each
   generated record reports `Verified`.
4. Do not copy `questlog.dev`'s no-email lockdown onto `blackcat.dev`.
   Resend's exact records own its outbound policy. Decide inbound mail
   separately. Start DMARC in monitoring mode if required to prove all
   legitimate senders, then tighten it after test mail passes SPF, DKIM, and
   DMARC.
5. Create a `bujo-production` Sending access key restricted to
   `bujo.blackcat.dev` and store it in 1Password. Kamal resolves it at deploy
   time through `op://Personal/bujo-production/credential`; the credential is
   never committed. Create the separate `press-start-production` key only when
   Press Start begins its own mail implementation; do not create an unused
   long-lived secret now.
6. When each app integrates, send one provider-level test from its From
   identity to at least two major mailbox providers. Inspect the received
   headers rather than treating inbox arrival alone as proof of authentication.

Inbound mail is a separate concern. If replies should reach Dan, use a
Reply-To address forwarded by Cloudflare Email Routing or a later mailbox
provider. Resend receiving, inbound webhooks, and support-mail workflows are
out of scope for authentication mail.

## Step 1 implementation details

Bujo already queues `PasswordsMailer.reset` through Action Mailer and Solid
Queue. Step 1 should reuse that delivery seam, then add the actual long-term
fallback—magic links—without removing the password rollback yet:

1. Add the official `resend` gem, select Resend's HTTPS Action Mailer delivery
   method in production, and keep the provider behind Action Mailer.
2. Add a `RESEND_API_KEY` Kamal secret and expose it only to the web role. Fetch
   it from 1Password at deploy time through Kamal's secret helper (or an `op
   read` command substitution); never copy the value into the repository.
3. Make the public application origin and From address explicit deployment
   configuration. The cutover decision fixes
   `APP_ORIGIN=https://bujo.blackcat.dev`; Step 1 must not ship with an old-host
   alternative. `MAIL_FROM` is
   `Bujo <sign-in@bujo.blackcat.dev>`. Do not derive either value from an
   inbound request or bake it into mailer classes.
4. Replace production's `example.com` URL default and
   `from@example.com` sender. Generated links must use the canonical HTTPS
   origin.
5. Enable production delivery and error reporting so a failed Solid Queue job
   remains visible. Do not log API keys, reset tokens, or complete magic-link
   URLs.
6. Add a non-sync `magic_link_version` integer to `users`. Define a Rails
   `generates_token_for` magic-link purpose with a 15-minute expiry and embed
   that version in the signed token. Increment the version before issuing a
   link so a new request invalidates every older link.
7. Return the same request response for known and unknown addresses. Queue mail
   only for a known account, keep the existing rate limit, and do not let magic
   links create accounts; public signup remains a separate later decision.
8. Keep redemption scanner-safe: email a link to the neutral redeem page with
   the token in the URL fragment, which browsers do not send to Rails or the
   proxy. A small Stimulus controller removes the fragment from the address
   bar and stages the token for an explicit **Open your journal** POST. Merely
   fetching the email link must not consume it.
9. Redeem under a user-row lock, revalidate the token inside the lock, increment
   `magic_link_version` before creating the ordinary Rails session, and reject
   every later use of the same token. Reuse the generator's existing
   `start_new_session_for` path rather than inventing a second session type.
10. Add focused tests for sender/recipient/subject, HTTPS link host, expiry,
    request-time invalidation, single use (including competing redemption),
    queueing, scanner-safe GET behavior, enumeration parity, rate limiting,
    missing production configuration, and a failing delivery adapter.
    Automated tests must never call Resend.
11. Verify provider delivery, then perform the live redeem round trip after Step
    2 makes `bujo.blackcat.dev` canonical. Record a rollback that preserves the
    current password sign-in until Step 5. The final password-free sign-in mock
    is not substituted wholesale during Step 1.

Operator handoff completed 2026-08-29: the non-secret reference holding
`RESEND_API_KEY` is `op://Personal/bujo-production/credential`, and `op read`
was proven locally without printing the value. The secret itself is never
requested in chat or stored in source control.

## Press Start implementation slice

Press Start already owns an `IEmailSender` seam, Mailpit development delivery,
magic-link behavior, clean 503 handling when mail is unavailable, and tests
that protect account-enumeration parity. Its later deployment slice should:

1. Add a production `ResendEmailSender` that implements `IEmailSender` over
   HTTPS while leaving the Mailpit/MimeKit development path intact.
2. Select the sender by environment without letting tests or development use
   a real Resend key.
3. Verify its own sending subdomain and supply its own domain-restricted
   Sending access key, From identity, and canonical magic-link redeem origin
   through production configuration. The planned origin and likely sending
   domain are `https://lift.blackcat.dev` and `lift.blackcat.dev`, subject to
   Press Start's later hostname ruling.
4. Preserve the existing synchronous failure contract unless a separate,
   explicitly designed queueing slice changes it.
5. Re-run the existing mail-down, enumeration, magic-link redemption, and
   browser authentication acceptance lanes, plus adapter-level HTTP failure
   tests. Then perform one real production magic-link round trip.

This choice must also be recorded in Press Start's own deployment plan when
that slice begins. This document is not authority to modify its currently
active Programs work or to couple its release to Bujo.

## Cross-app rollout order

1. Root DNS authentication, Bujo's app-specific sending domain, DMARC, and
   Bujo's scoped key are complete.
2. Execute Bujo's five-step Rails authentication rollout above in order.
3. Press Start adopts the same Resend account with its own verified subdomain
   and key during its production deployment slice; its app origin, code, and
   passkey credentials remain independent.
4. Review aggregate usage, bounces, complaints, and inactive keys monthly at
   first. Upgrade only when the shared daily/monthly quota or verified-domain
   limit is genuinely reached.

## Cost and upgrade triggers

Expected initial provider cost is **$0 per month** for both applications
combined. The free tier's three verified domains cover the existing root,
Bujo, and one future app-specific domain. Move to Resend Pro only if another
verified domain is needed, aggregate use approaches 100 messages per day or
3,000 per month, or paid support/retention becomes worthwhile. Recheck pricing
before that decision.

Provider references, to be rechecked when the slice is specified:

- [Resend pricing](https://resend.com/pricing)
- [Resend API-key permissions](https://resend.com/docs/dashboard/api-keys/introduction)
- [Resend with Cloudflare DNS](https://resend.com/docs/knowledge-base/cloudflare)
- [Resend with Rails](https://resend.com/rails)
- [Rails expiring record tokens](https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html)
- [Kamal 1Password secret helper](https://kamal-deploy.org/docs/commands/secrets/)
- [DigitalOcean SMTP restriction](https://docs.digitalocean.com/support/why-is-smtp-blocked/)
