# ClubOS — Security Audit Report

**Application:** ClubOS (Flutter + Supabase, iOS & Android)
**Audit type:** Pre-deployment security review (static, read-only)
**Date:** 2026-06-27
**Auditor role:** Application security review
**Scope:** Source under `lib/`, database migrations & RLS under `supabase/`, edge function, Android/iOS platform config, secret handling, repository hygiene.

---

## 1. Executive Summary

ClubOS is **not yet safe to deploy.** The codebase hygiene is good — secrets are not committed, RLS is enabled on every table, no service-role key is exposed to the client — but the application's security perimeter has a **critical privilege-escalation flaw** that allows any registered user to take over any club on the platform, plus several supporting data-exposure and integrity issues.

A foundational point frames every finding below: the `SUPABASE_ANON_KEY` shipped in the app is **public by design**. It is embedded in every installed binary and can be trivially extracted. Client-side role checks (which screen renders, which button shows) are therefore **not security controls** — an attacker bypasses the app entirely and calls the Supabase REST/RPC API directly with the public key. **The only enforced security boundary is the Postgres Row Level Security (RLS) policy set.** That is where the vulnerabilities are, and where remediation must happen.

### Findings at a glance

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | **Critical** | Any user can self-appoint as approved President of any club | **Fixed** — `20260627000000_rls_hardening.sql`, verified live 2026-07-02 |
| 2 | **High** | Task-attachments storage bucket is public + unrestricted upload | **Fixed** — `20260627000001_storage_hardening.sql`, verified live 2026-07-02 |
| 3 | Medium | Notification spoofing / phishing (`notifications_insert` open) | **Fixed** — policy dropped, verified live 2026-07-02 |
| 4 | Medium | Platform-wide PII harvesting (`profiles_select` open) | **Fixed** — scoped to shared clubs, verified live 2026-07-02 |
| 5 | Medium | Club constitution readable across clubs | **Fixed** — membership-gated + column-limited RPCs, verified live 2026-07-02 |
| 6 | Medium | Edge function push-spam (optional webhook secret) | **Fixed** — fails closed; deployed function verified + webhook sends secret header |
| 7 | Medium | Email enumeration via anon RPC | **Accepted risk** — deliberate login-UX tradeoff (see §4 MED-05) |
| 8 | Medium | Password-reset deep-link hijacking (custom URL scheme) | **Open** — needs Universal Links / App Links on an owned domain |
| 9 | Medium | Forgeable audit log | **Fixed** — policy dropped, verified live 2026-07-02 |
| 10 | Low | RSVP list visible to all members (spec: President only) | **Fixed** — verified live 2026-07-02 |
| 11 | Low | Missing `WITH CHECK` on several UPDATE policies | **Fixed** — verified live 2026-07-02 |
| 12 | Low | Unrestricted club creation (spam) | **Fixed** — RPC rate-limited to 3/24h, verified live 2026-07-02 |

**2026-07-02 follow-up:** `20260702000000_function_privilege_hardening.sql` additionally pins `search_path` on `check_email_exists` and revokes anon/PUBLIC `EXECUTE` on all SECURITY DEFINER RPCs and trigger functions (Supabase advisor warnings). Remaining advisor item requiring dashboard access: enable leaked-password protection (Auth → Passwords).

### Recommended remediation order

Fix **#1 first** — until it is closed, the other access-control findings are academic because an attacker can simply become President. Then address #2, then #3–#9, then the Low items.

---

## 2. Critical Findings

### CRIT-01 — Privilege escalation: any user can become an approved President of any club

**Severity:** Critical
**Confidence:** Certain
**Location:** `supabase/migrations/20260602000000_initial_schema.sql` — `ucr_insert` policy

The insert policy on `user_club_roles` only verifies that the row's `user_id` matches the caller:

```sql
create policy "ucr_insert" on public.user_club_roles
  for insert to authenticated with check (user_id = auth.uid());
```

It places **no constraint on `role` or `status`.** Any authenticated user can insert a row for themselves with `role = 'president'` and `status = 'approved'` against **any** `club_id`, using the public anon key and a single crafted HTTP request — no application UI involved. Because a brand-new account has no existing `user_club_roles` rows, the `UNIQUE (user_id, club_id)` constraint does not protect any club an attacker has not already joined.

**Impact:** Full compromise of every club on the platform. Once "President," the attacker can read the President-only activity log, edit the club constitution, remove members, and delete the club. The intended pending → President-approval workflow is entirely bypassed. The multi-step "type the club name to confirm" deletion guard is client-side only and provides no protection against a direct API call.

**Remediation:** Restrict self-insert to a non-privileged, non-approved join request. A user may only insert their own row as a Director or Vice President in `pending` status; the President role and `approved` status must only be reachable via the President-controlled `ucr_update` path (or a dedicated `SECURITY DEFINER` RPC for the create-club-as-president flow). For example:

```sql
create policy "ucr_insert" on public.user_club_roles
  for insert to authenticated with check (
    user_id = auth.uid()
    and status = 'pending'
    and role in ('vice_president', 'director')
  );
```

Club creation (where the creator legitimately becomes an approved President) should be handled by a `SECURITY DEFINER` function that creates the club and the President row atomically, rather than relying on a permissive client insert.

---

## 3. High Findings

### HIGH-01 — Public storage bucket exposes attachments and allows unrestricted uploads

**Severity:** High
**Confidence:** Certain
**Location:** `supabase/migrations/20260606000000_task_attachments_storage.sql`

The bucket is created public:

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('task-attachments', 'task-attachments', true)
ON CONFLICT (id) DO NOTHING;
```

A public bucket serves objects over unauthenticated public URLs, which **bypasses the SELECT RLS policy entirely** — anyone who has, guesses, or enumerates an object URL can download any club's task attachments without logging in. Separately, the upload policy applies no path, owner, or club scoping and no size/type limit:

```sql
CREATE POLICY "Authenticated users can upload task attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'task-attachments');
```

So any authenticated user can write arbitrary files into the bucket (cross-club access; abuse of your project as malware/file hosting).

**Impact:** Confidential club documents are world-readable; storage can be abused for hosting and cost/quota exhaustion.

**Remediation:** Make the bucket private (`public => false`) and generate signed URLs for downloads. Constrain uploads by an object-path prefix tied to the uploader and club (e.g. `"{club_id}/{auth.uid()}/..."`) and validate it in the INSERT policy. Enforce file size/MIME limits.

---

## 4. Medium Findings

### MED-01 — Notification spoofing / phishing
**Confidence:** Certain — `supabase/migrations/20260602000000_initial_schema.sql`, `notifications_insert`

```sql
create policy "notifications_insert" on public.notifications
  for insert to authenticated with check (true);
```

Any user can insert a notification for **any** `user_id` with arbitrary text — a phishing/social-engineering vector inside a trusted channel (and, combined with MED-04, arbitrary push notifications). The legitimate notification writers are `SECURITY DEFINER` triggers/RPCs that bypass RLS, so this broad policy is unnecessary. **Remediation:** restrict to `with check (user_id = auth.uid())`, or drop the authenticated INSERT policy entirely and rely on the definer functions.

### MED-02 — Platform-wide PII harvesting
**Confidence:** Certain — `profiles_select`

```sql
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);
```

Every authenticated user can read the full name and email of **every user on the entire platform**, including users in unrelated clubs. **Remediation:** scope to profiles that share at least one club with the caller (reuse the `get_my_approved_club_ids()` pattern via a club-membership join).

### MED-03 — Club constitution readable across clubs
**Confidence:** Likely — `clubs_select`

`clubs_select using (true)` is required so the join dropdown can list clubs, but it returns all columns including `constitution_content`, letting any user read any club's private governance document. **Remediation:** expose only `id`/`name` for the dropdown (a view or column-limited RPC) and gate `constitution_content` behind club membership.

### MED-04 — Edge function allows unauthenticated push-spam
**Confidence:** Likely — `supabase/functions/send-push-notification/index.ts`

The shared-secret check is optional:

```js
const expected = Deno.env.get("WEBHOOK_SECRET");
if (expected && req.headers.get("x-webhook-secret") !== expected) {
  return new Response("Unauthorized", { status: 401 });
}
```

There is no `supabase/config.toml` setting `verify_jwt` for this function. If it is deployed with `--no-verify-jwt` (typical for DB webhooks) and `WEBHOOK_SECRET` is unset, anyone who discovers the function URL can POST `{user_id, type, message}` and deliver arbitrary push notifications to any user. **Remediation:** make `WEBHOOK_SECRET` mandatory (fail closed if unset) and/or explicitly configure JWT verification; confirm the deploy flag.

### MED-05 — Email enumeration via anonymous RPC
**Confidence:** Certain — `supabase/migrations/20260604000001_check_email_exists.sql`

`check_email_exists` is `SECURITY DEFINER`, callable by the anon key, reads `auth.users`, and has no rate limiting. An attacker can determine which email addresses are registered. This is a deliberate tradeoff for the login UX (showing "forgot password" only for known emails); document it as an accepted risk or add rate limiting. **Remediation (if not accepted):** remove the pre-check and let the standard password-reset flow respond uniformly regardless of whether the email exists.

### MED-06 — Password-reset deep-link hijacking
**Confidence:** Likely — `lib/features/auth/data/auth_repository.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`

Password recovery redirects to the custom URL scheme `io.clubos://reset-password`. Custom schemes are not exclusive — a malicious app installed on the same device can register the same scheme and intercept the recovery link, which carries the auth token, enabling account takeover. **Remediation:** migrate to verified Android App Links / iOS Universal Links (https on a domain you control with `assetlinks.json` / AASA), which the OS binds exclusively to your app.

### MED-07 — Forgeable audit log
**Confidence:** Certain — `activity_log_insert`

```sql
create policy "activity_log_insert" on public.activity_log
  for insert to authenticated with check (
    exists (select 1 from public.user_club_roles
            where club_id = activity_log.club_id and user_id = auth.uid()
            and status = 'approved'));
```

The policy verifies the caller is an approved member but does **not** require `user_id = auth.uid()`, so a member can insert log entries attributed to other users — undermining the President's trust in the audit feed. The real writers are `SECURITY DEFINER` triggers, so the authenticated INSERT policy is unnecessary. **Remediation:** drop the authenticated INSERT policy (rely on triggers) or add `user_id = auth.uid()`.

---

## 5. Low Findings

### LOW-01 — RSVP list visible to all members
**Confidence:** Certain — `event_rsvps_select`. The policy allows any approved member to read RSVPs; the product spec (`CLAUDE.md`) states only the President may view the RSVP list. Tighten the SELECT policy to President-only if confidentiality is intended.

### LOW-02 — Missing `WITH CHECK` on UPDATE policies
**Confidence:** Likely — `tasks_update`, `ucr_update`, `profiles_update`. These define `USING` (which rows may be targeted) but no `WITH CHECK` (what the row may become). A caller who passes `USING` can mutate a row into a state that should be disallowed — e.g. moving a task's `club_id`, or an assigned Director editing fields beyond `status`. Add explicit `WITH CHECK` clauses mirroring the intended constraints.

### LOW-03 — Unrestricted club creation
**Confidence:** Certain — `clubs_insert with check (true)` permits unlimited club creation by any user (spam / resource abuse). Consider rate limiting or a creation gate.

---

## 6. What Was Verified as Sound

The following were checked and present no issue at the time of audit:

- `.env`, Firebase config files (`google-services.json`, `GoogleService-Info.plist`), and `.claude/settings.local.json` are correctly listed in `.gitignore` and are **not** tracked in git.
- No secrets are hardcoded in `lib/`; Supabase URL and anon key are read from `.env` at runtime.
- No service-role key or other privileged credential is present in the client.
- Row Level Security is enabled on every application table.
- The edge function correctly uses the service-role key only server-side and mints short-lived FCM OAuth tokens; database trigger/RPC functions correctly use `SECURITY DEFINER` with `set search_path = public`.
- No cleartext-traffic or debuggable flags in the Android build; iOS ATS not weakened.
- The recursive-RLS fix (`get_my_approved_club_ids`, `is_my_club_president`) is implemented correctly.

These confirm good baseline hygiene; the open findings are policy-logic flaws, not leaked-file flaws.

---

## 7. Methodology & Limitations

This was a **static, read-only** review of source code, database migrations, edge function, and platform configuration. It did **not** include: dynamic testing against the live Supabase project, verification of the *actually deployed* RLS state (migrations are assumed to reflect production), penetration testing, dependency CVE scanning, or review of Supabase Auth dashboard settings (e.g. email-confirmation enforcement, JWT expiry, leaked-password protection). Recommended next steps before launch: (1) apply fixes starting with CRIT-01; (2) re-run this review against the deployed database via Supabase advisors; (3) perform authenticated dynamic testing simulating a malicious member crafting direct API calls; (4) review Auth configuration and dependency advisories.

*End of report.*
