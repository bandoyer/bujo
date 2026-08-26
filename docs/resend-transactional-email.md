# Resend transactional email plan

**Status:** `blackcat.dev` acquired 2026-08-26. Resend's Cloudflare automatic
setup has installed and individually verified the DKIM, SPF, and return-path
MX records. The monitoring-mode DMARC record was added manually in Cloudflare;
Resend's aggregate domain status is `Verified`. Provider, sender identities,
Bujo origin, and cross-app shape are decided. The domain-restricted
`bujo-production` key is stored in 1Password; application implementation has
not started. The provider foundation is complete and the current work gate is
Step 1 of the five-step Rails authentication rollout below. Bujo's planned
origin is `https://bujo.blackcat.dev`. Press Start's likely origin is
`https://lift.blackcat.dev`, but that hostname remains tentative until its own
deployment decision.

## Provider foundation

- [x] Acquire `blackcat.dev`.
- [x] Select Resend, shared `blackcat.dev` sending, and separate app keys.
- [x] Select `bujo@blackcat.dev` and `lift@blackcat.dev` From identities.
- [x] Confirm the Cloudflare zone and add Resend's generated DNS records.
- [x] Verify Resend's aggregate `blackcat.dev` domain status.
- [x] Confirm Cloudflare saved the monitoring-mode DMARC record
  `v=DMARC1; p=none;`.
- [x] Create the domain-restricted `bujo-production` Sending key and store it
  in 1Password.

## Rails authentication rollout

Current position: **ready to begin Step 1; no application code in these five
steps has started.** The approved visual direction is
[`mockups/SignIn.dc.html`](../mockups/SignIn.dc.html): passkey first, magic
email second, no password in the final product UI.

- [ ] **1 — Resend delivery and magic links.** Put Resend behind Action Mailer,
  send from `Bujo <bujo@blackcat.dev>`, and add short-lived, single-use magic
  links for known accounts. Preserve enumeration parity, rate limits, and the
  current password path as a temporary rollback while this proves out.
- [ ] **2 — Canonical origin.** Move the Rails app to
  `https://bujo.blackcat.dev`, update production URL generation, verify TLS and
  a real magic-link round trip, and stop issuing authentication links for
  `questlog.dev`.
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

- Use one Resend account and one exact verified sending domain shared by both
  applications: `blackcat.dev`. Resend requires the From domain to exactly
  match the verified domain.
- Give each application its own recognizable From identity on that domain,
  `Bujo <bujo@blackcat.dev>` and `Press Start <lift@blackcat.dev>`.
- Give each production application a separate Resend API key with Sending
  access restricted to the shared domain. Never share one key between apps
  and never give an application a Full access key.
- Send through Resend's HTTPS API, not SMTP. DigitalOcean blocks outbound
  ports 25, 465, and 587 on Droplets. Local development remains isolated:
  Rails uses its test delivery method and Press Start keeps Mailpit.
- The free-plan quota is shared by both apps. As checked 2026-08-26, it is
  3,000 messages per month, 100 per day, and one custom domain. Recheck the
  provider's pricing and limits immediately before implementation.
- Keep the applications independent. They share a provider account and
  sending domain, but no application code, deployed secret, job queue,
  failure state, or release step.
- Separate keys make revocation and logs independent, but domain-scoped keys
  cannot restrict a key to one local part of a shared domain. Either key could
  technically send from the other app's From address. Accept that small
  shared-domain trust boundary while both applications are operator-owned;
  separate verified domains are the stronger paid-plan boundary if that ever
  changes.

## Account and DNS setup

1. Confirm the acquired `blackcat.dev` zone is active in Cloudflare before
   configuring production mail. Do not set up `questlog.dev` and repeat the
   work after the domain change.
2. Create the Resend account/team and add the one shared sending domain.
3. Add exactly the Resend-generated Cloudflare records for that domain:
   return-path MX/SPF and DKIM. Keep them DNS-only where Cloudflare presents a
   proxy choice. Completed through Resend's Cloudflare automatic setup on
   2026-08-26; each generated record reports `Verified`.
4. Do not copy `questlog.dev`'s no-email lockdown onto `blackcat.dev`.
   Resend's exact records own its outbound policy. Decide inbound mail
   separately. Start DMARC in monitoring mode if required to prove all
   legitimate senders, then tighten it after test mail passes SPF, DKIM, and
   DMARC.
5. Create a `bujo-production` Sending access key restricted to the verified
   domain and store it in 1Password until Step 1 injects it into Kamal without
   committing it. Create the separate `press-start-production` key only when
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
   configuration, for example `APP_ORIGIN=https://bujo.blackcat.dev` and
   `MAIL_FROM=Bujo <bujo@blackcat.dev>`; do not bake them into mailer classes.
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

Operator handoff still needed at implementation time: identify the non-secret
1Password account/vault/item/field reference holding `RESEND_API_KEY`. The
secret value itself is never requested in chat or stored in source control.

## Press Start implementation slice

Press Start already owns an `IEmailSender` seam, Mailpit development delivery,
magic-link behavior, clean 503 handling when mail is unavailable, and tests
that protect account-enumeration parity. Its later deployment slice should:

1. Add a production `ResendEmailSender` that implements `IEmailSender` over
   HTTPS while leaving the Mailpit/MimeKit development path intact.
2. Select the sender by environment without letting tests or development use
   a real Resend key.
3. Supply its own domain-restricted Sending access key,
   `lift@blackcat.dev` From identity, and canonical magic-link redeem
   origin through production configuration. The planned origin is
   `https://lift.blackcat.dev`, subject to Press Start's later hostname ruling.
4. Preserve the existing synchronous failure contract unless a separate,
   explicitly designed queueing slice changes it.
5. Re-run the existing mail-down, enumeration, magic-link redemption, and
   browser authentication acceptance lanes, plus adapter-level HTTP failure
   tests. Then perform one real production magic-link round trip.

This choice must also be recorded in Press Start's own deployment plan when
that slice begins. This document is not authority to modify its currently
active Programs work or to couple its release to Bujo.

## Cross-app rollout order

1. Shared sending domain, DNS authentication, DMARC, and Bujo's scoped key are
   complete.
2. Execute Bujo's five-step Rails authentication rollout above in order.
3. Press Start adopts the same sending account/domain with its own key during
   its existing production deployment slice; its app origin, code, and passkey
   credentials remain independent.
4. Review aggregate usage, bounces, complaints, and inactive keys monthly at
   first. Upgrade only when the shared daily/monthly quota or one-domain limit
   is genuinely reached.

## Cost and upgrade triggers

Expected initial provider cost is **$0 per month** for both applications
combined. Move to Resend Pro only if either app needs a different verified
domain, aggregate use approaches 100 messages per day or 3,000 per month, or
paid support/retention becomes worthwhile. As checked 2026-08-26, the first
Pro tier is $20 per month for 50,000 messages and ten custom domains.

Provider references, to be rechecked when the slice is specified:

- [Resend pricing](https://resend.com/pricing)
- [Resend API-key permissions](https://resend.com/docs/dashboard/api-keys/introduction)
- [Resend with Cloudflare DNS](https://resend.com/docs/knowledge-base/cloudflare)
- [Resend with Rails](https://resend.com/rails)
- [Rails expiring record tokens](https://api.rubyonrails.org/classes/ActiveRecord/TokenFor/ClassMethods.html)
- [Kamal 1Password secret helper](https://kamal-deploy.org/docs/commands/secrets/)
- [DigitalOcean SMTP restriction](https://docs.digitalocean.com/support/why-is-smtp-blocked/)
