# Database setup and upgrades

The application uses one Supabase project and one administrator email per installation. Static hosting needs no build step or runtime server beyond Supabase. Keep email confirmation enabled in Supabase Auth: `is_admin()` authorizes the configured email from the authenticated JWT.

## First installation

1. Create a Supabase project. In its API settings, copy the project URL and publishable (or legacy anon) key. Never use a service-role or secret key in the HTML pages.
2. Download [first_install.sql](first_install.sql). Replace `YOUR_EMAIL_HERE` with the administrator's login email and run the whole file in the Supabase SQL editor. It includes all schema changes through **009 / version 2.3.21**, RLS policies, API grants, and Realtime publication setup in one transaction. It refuses to run with the placeholder or against an existing installation. **Do not also run 001–009.**
3. Configure Supabase Auth's Site URL and Redirect URLs for your deployment. Add the full `https://your-host/path/kyomei-admin.html` URL to Redirect URLs; the app requests that page as its magic-link return target. Add your exact localhost admin URL separately for local testing. See [Supabase's redirect documentation](https://supabase.com/docs/guides/auth/redirect-urls).
4. Configure custom SMTP for classroom use. Supabase's default mailer only delivers to project team members, has restrictive rate limits, and is intended for testing. See [Supabase's SMTP setup](https://supabase.com/docs/guides/auth/auth-smtp). With email signup enabled, the first successful magic-link login creates the administrator's Auth account. If signup is disabled, provision that email in Auth first. Other authenticated emails do not receive administrator permissions.
5. Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the CONFIG block of all three application pages. Each page stops with an explanation when these are still placeholders. For mmutube playback only, also configure `KALTURA_PARTNER_ID` and `KALTURA_UICONF_ID` in the display page. Local video files do not require Kaltura.
6. Serve `index.html`, `kyomei.html`, `kyomei-admin.html`, and `kyomei-display.html` together over HTTPS. Keep the template branch's placeholders if sharing your source; see [the main README](../README.md) for this project's main/live arrangement.
7. Follow the deployment checks below before a class.

## Existing installation

1. Back up the database and finish any active classes before upgrading.
2. Apply only the numbered migrations you have not already applied, in ascending order, through `010_fix_ambiguous_category_relationship.sql`. Each numbered upgrade from 002 onward is transactional and can be rerun. Use the current copy of 007: it now handles existing dependent constraints correctly. Migration 007 will reject existing cross-session category/option/prompt references; inspect and correct the offending data before retrying. **If you already applied 007 before 010 existed**, you'll have hit `PGRST` "more than one relationship was found for 'friction_pool' and 'session_categories'" on any admin/display feed load — 007 added a second foreign key alongside the original instead of replacing it. Run 010 to fix it; nothing else needed.
3. Migration 009 invalidates old markup/ranking editing credentials because they may already have been exposed. It **preserves submitted highlights, teams, orders, and voting data**, but students cannot resume editing those legacy rows. Refresh all student tabs and reset any reused sessions before collecting a new round. New credentials survive refresh and subsequent migration reruns.
4. Publish the updated pages together and refresh open admin/display/student tabs. Run the deployment checks below.

Do not run `001_baseline.sql` or `first_install.sql` on an existing database: they contain an administrator placeholder and initial policies. Numbered upgrades preserve your administrator configuration. The ignored legacy `friction_pool_schema.sql` is no longer an installation or upgrade source; use these versioned files.

## Access and voting model

- Unarchived sessions can be enumerated through the public API. Session codes are not passwords. Active text responses are public; vote/markup/ranking result reads are reveal-gated. Do not collect confidential material on that basis.
- Archiving blocks further student submissions and non-admin database/RPC reads, including ownership-restoration RPCs. It cannot erase data already downloaded or shown in an open browser. Reload student/display pages to verify archived sessions are unavailable. The administrator can still inspect and export archived results.
- Student markup/ranking edits use a private random browser credential, separate from the public voting identifier. The server stores only a hash bound to the session and mode, and RPCs hash the supplied credential before checking ownership. Neither exposed voting IDs nor returned credential hashes authorize edits. Raw markup inserts/updates bypassing the RPC are denied.
- One-vote mode rejects missing IDs and reserves each `(session, reset round, browser ID)` in a private table with a primary key. This prevents simultaneous duplicate inserts. Failed submissions roll back their reservation; reset clears reservations. Enabling one-vote mode also respects votes already made in the current round.
- Browser identifiers are not verified people. Clearing storage, using another browser, or deliberately choosing a new identifier permits another vote. There is no application-wide spam/rate limiter. This is intended for cooperative classroom participation, not authenticated elections.

## Deployment checks

- Sign in as the configured administrator; verify email delivery and the return to the admin console. Confirm a different authenticated email cannot create or change sessions.
- Create a text-response session. Join from a separate browser/device and open its display. Submit, park, and delete a response; verify the feeds update.
- Create a markup session. Submit highlights, refresh the student page, then edit and submit again. Verify restored ownership and aggregate updates. Reveal, export, and reset from admin.
- Create a one-vote quick-tap session. Submit once, reload, and confirm another vote from that browser is blocked. Reset and confirm a new vote is accepted.
- Create a Running Order session. Claim a team, submit an order, refresh, and verify the same browser can resume. Reveal its results.
- Archive the sessions. Reload student/display pages and confirm they are unavailable; check archived results still export from admin.
- If using Media Vote, test playback, pause/seek, voting, and the revealed timeline on the actual classroom browser/projector.
- Verify Realtime delivery on the deployed Supabase project. Local SQL/DOM checks do not simulate Supabase Realtime or email delivery.

## Maintaining the SQL

Numbered migrations are the upgrade source. After changing them, regenerate the first-install snapshot with:

```sh
python3 migrations/build_first_install.py
```

The generator needs only Python's standard library and is not used by the browser. Commit the snapshot together with its numbered sources and update its version header when releasing. Local development tests are intentionally not shipped with the template.
