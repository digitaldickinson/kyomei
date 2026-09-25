# kyomei

A lightweight app for classroom interaction. Students submit responses from
their own devices; teachers run and monitor sessions from an admin console;
a display view projects live results for the room.

## Pages

- **`index.html`** — holding page for the site root.
- **`kyomei.html`** — student view. Submits responses to a session in any of
  the session types below: free-text response (optionally guided), quick-tap
  buttons, passage highlighting (text markup), Media Vote, or Running Order.
- **`kyomei-admin.html`** — teacher console. Create and manage sessions,
  configure categories and prompts, and watch responses come in live.
- **`kyomei-display.html`** — read-only display view for projecting live
  session results.
- **`kyomei-presenter.html`** — presentation display. Switches the projector
  between a published Google Slides deck and the selected activity (shown
  through `kyomei-display.html`), controlled from Admin's Presentation panel
  in the same browser. Opened from Admin, not directly.

## Session types

Every session is exactly one of these, set at creation:

- **Text response** — students submit free-text scenarios against
  tutor-defined categories. Optionally **guided**, where the tutor reveals
  one category at a time instead of all at once.
- **Quick-tap buttons** — students tap one of up to 10 tutor-defined
  buttons; instant-submit, optionally limited to one vote per device.
  Includes two one-click "Pulse Check" launcher variants (traffic light,
  confidence) with their own dedicated single-view displays.
- **Text markup** — students highlight word ranges in a fixed passage in
  response to tutor-set prompts; aggregate views show a heatmap and
  community highlights across the room's highlights.
- **Media Vote** — a clip (a local file, or an embedded mmutube video)
  plays on the display, driven by Play/Pause/Seek/Restart transport
  controls in admin; students vote on a fixed button set as it plays,
  retapping freely. A reveal-gated timeline reconstructs how the room's
  vote evolved across the clip, bucketed at a tutor-adjustable interval.
- **Running Order** — a tutor authors story headlines; physical groups each
  claim a team name on one device and reorder the stories via up/down
  buttons. The tutor reveals one team's final order, or a room-wide
  aggregate — average final position, plus two oscillation views (move
  count and pairwise reversals) showing which stories caused the most
  back-and-forth.

## JS libraries

Loaded via CDN `<script>` tags, no build step or package manager:

- **[`@supabase/supabase-js`](https://github.com/supabase/supabase-js) v2.116.0** — `kyomei.html`, `kyomei-admin.html` and `kyomei-display.html`. Database reads/writes and Realtime channel subscriptions.
- **[`qrcodejs`](https://github.com/davidshimjs/qrcodejs) v1.0.0** — `kyomei-display.html` only. Renders the join QR code.
- **Kaltura Player (PlayKit JS)** — `kyomei-display.html` only, loaded dynamically at runtime (not a static `<script>` tag) the first time a Media Vote session's video source is `mmutube`. Uses the Dynamic Embed pattern (`KalturaPlayer.setup()`), not the non-programmable iframe embed.

`kyomei-presenter.html` loads no libraries.

## Backend

Data is stored in [Supabase](https://supabase.com) (via `@supabase/supabase-js`),
with one `sessions` table and per-type tables for each session type's
configuration and responses (for example `friction_pool` for text responses,
`quick_tap_responses`, `text_markup_responses`, `media_vote_responses`, and the
`ranking_*` tables for Running Order). The full schema is in
[`migrations/`](migrations/README.md). Real-time updates are delivered through
Supabase channel subscriptions.

## Running locally

These are static HTML files with no build step. Serve all five HTML pages together over HTTPS using GitHub Pages, Netlify, or another static host. For local development, use a localhost HTTP server rather than opening the files directly.

## Deploying your own copy

`main` is a public template — `SUPABASE_URL`/`SUPABASE_ANON_KEY` are placeholders, and each page
refuses to start (with a clear message) until they're filled in. See [migrations/README.md](migrations/README.md)
for the complete setup guide and [first-install SQL](migrations/first_install.sql), then edit the `CONFIG` block near the top of each page's `<script>`. (`kyomei-presenter.html` has no `CONFIG` block — it never talks to Supabase.)

This project's own live deployment keeps its real credentials on a separate `live` branch rather
than on `main`, since GitHub Pages serves whatever branch it's pointed at directly — that's what
lets `main` stay safe to clone. If you're doing the same, point Pages at your own equivalent
branch, not `main`.

Media Vote's `mmutube` source is similarly account-specific — `KALTURA_PARTNER_ID`/
`KALTURA_UICONF_ID` near the top of `kyomei-display.html`'s Media Vote section are placeholders on
`main` too, and only need filling in if you actually use `mmutube` (a local video file works with
no Kaltura account at all). Everything else works unaffected either way.

## Reliability and session workflows (2.3.0)

Each page remains self-contained, with no new runtime assets or build step.

- Admin can open/close submissions independently of revealing results, duplicate a session with fresh responses, and export results as CSV.
- Student pages show connection and submission status and retain unfinished text, highlights, and ranking order locally. Drafts and the one-vote lock belong to a particular reset round.
- Session creation, duplication, and reset run as database transactions.

Apply the [database migration](migrations/README.md) before publishing these pages. The database baseline and ordered migrations are now tracked in `migrations/`; the original local schema file remains ignored.

Development tests are kept locally and are not included in this deployment template. Follow the deployment checks in [the setup guide](migrations/README.md) before using a new instance.

This is a single-admin classroom tool. Unarchived sessions and their permitted results are publicly readable through the API; session codes are join conveniences, not passwords. Editing credentials are separate from public vote identifiers. One-vote mode limits a browser identifier, not a person: clearing storage or changing browsers permits another vote. See the setup guide for the full access model.

## Licence

[MIT](LICENSE).
