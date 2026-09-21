# Version history

Semantic versioning (`MAJOR.MINOR.PATCH`):

- **MAJOR** — a new session type, or a change that breaks compatibility with existing sessions/data.
- **MINOR** — a new feature within an existing session type (a new stage, a new control, a new broadcast field).
- **PATCH** — a bug fix, a copy/layout tweak, or a schema addition that only supports a fix above.

Update this file with each change that ships — bump the version, add an entry at the top of the log below. Database migrations are tracked under `migrations/`. The legacy local `friction_pool_schema.sql` remains ignored. Schema entries are flagged (**schema**) as a reminder to apply the matching migration in Supabase.

**Current version: 2.3.12**

---

## Log

### 2.3.12 — 2026-09-21 — **schema**
Security review fix: removed `text_markup_responses`' anon UPDATE policy (`using (true) with check
(true)`) — the one table in the schema with a genuinely unrestricted write policy, unlike every
other anon-writable table (insert-only, or RPC-gated with no raw grant at all, same as ranking).
The app's real write path (`submit_text_markup_response()`) is a security-definer upsert and was
never gated by this policy either way — removing it only closes a direct-REST-API bypass: any anon
client could previously overwrite any row for any `device_id` without going through the RPC or app
at all. New migration `migrations/004_text_markup_update_lockdown.sql`; `friction_pool_schema.sql`
updated to match, and its stale "trust model note" (which had described the wide-open policy as an
accepted trade-off) corrected.

### 2.3.11 — 2026-09-21
Each app page's `CONFIG` comment block (`kyomei-admin.html`, `kyomei.html`, `kyomei-display.html`)
now points a new deployer at `migrations/README.md` before they fill in `SUPABASE_URL`/
`SUPABASE_ANON_KEY` — the config block was the only thing a from-scratch deployer would definitely
see, but gave no hint the database needed setting up first. No functional change.

### 2.3.10 — 2026-09-21
Removed the "Wall view (press M to toggle)" pill from `kyomei-display.html`'s projected feed — a
room-facing hint to press a key only the admin operator can press wasn't useful there. The actual
layout toggle is untouched; `updateFeedMasonryIndicator()` still applies `.masonry-layout` to
`#feed-list`, it just no longer also shows/hides a pill. Admin's own equivalent pill and shortcuts
panel entry are unchanged.

### 2.3.9 — 2026-09-21
Wall view (M) now applies to guided text-response sessions too, not just plain — it's a layout
choice (how the currently-visible cards are arranged), unlike grouping (G), which stays plain-only
since guided already shows one category at a time. `kyomei-admin.html`'s gate condition, keydown
guard, and shortcuts panel updated; `kyomei-display.html`'s `initGuidedDisplay` and sessions
subscription now also read/sync `feed_masonry` (previously only `initPlainFeedDisplay` did). No
schema change — `feed_masonry` was already an unconstrained boolean.

### 2.3.8 — 2026-09-21
Admin session view now shows a **Keyboard shortcuts** panel in the session header — only the keys
that apply to the current session type (L/G/M/Space, per the existing per-key session-type gates),
each with its live current state (e.g. "M — Display feed — Wall view"). Recomputed by piggybacking
on the five existing state-change functions (`updateJoinInfoBadge`, `updateFeedViewModeIndicator`,
`updateFeedMasonryIndicator`, `applyChartTypeVisibility`, `applyTextMarkupChartTypeVisibility`, plus
`updateRevealUI` for Text Markup's reveal-gated Space row) rather than a new call site at every
place those toggles change. No schema change.

### 2.3.7 — 2026-09-18 — **schema**
Added a "wall view" masonry layout for the plain Text response feed on `kyomei-display.html` — a
CSS `columns: 3 360px` alternative to the normal single-column cascade, toggled from admin with the
new **M** key (same pattern as the existing **G** grouped-feed toggle: gated to plain, non-guided
text-response sessions, broadcast live via a new `sessions.feed_masonry` boolean). Admin's own live
feed stays single-column regardless — its Park/Delete buttons don't fit a narrow masonry column.
New migration `migrations/003_feed_masonry.sql`; `friction_pool_schema.sql` and
`OPERATORS_MANUAL.md`'s shortcut tables updated to match. Needs a manual migration run against
Supabase before the toggle will do anything in production.

### 2.3.6 — 2026-09-18
Twin-rings mark rolled out to the rest of the app: all six per-session-type screens in
`kyomei.html` (form, guided, text markup, quick-tap, media vote, running order) and the
`kyomei-admin.html` session-list top bar ("kyomei:Sessions"), each at the small 24px inline scale.
`kyomei-display.html` deliberately left untouched — that screen stays projector-clean, text only.

### 2.3.5 — 2026-09-18
`index.html`'s mark + wordmark moved into a full-width banner strip at the top (48px mark, 36px
heading, panel background, bottom border) instead of sitting inline at body-text scale. Same mark
added to `kyomei-admin.html`'s login screen, at the original small (24px) inline scale next to that
screen's own "kyomei" heading — not touched: the "kyomei:Sessions" heading inside the working app,
since that's a functional top bar, not a branding moment.

### 2.3.4 — 2026-09-18
`index.html` header now carries a small mark: two overlapping circles (inline SVG, no new
dependency) next to the "kyomei" wordmark — one full-opacity, one at 45%, standing for two things
in sympathetic resonance. Picked from four sketched directions; the kanji-seal and wave-sync
alternatives are parked, not built.

### 2.3.3 — 2026-09-18
Admin footer (`kyomei-admin.html`) now credits the name's origin: "kyomei 共鳴 — resonance,
sympathetic response, or shared feelings" ahead of the existing facilitation-software credit line.

### 2.3.2 — 2026-09-18
Fixed a stale-UI leak in `kyomei-admin.html`: `enterSession()`'s plain text-response/guided branch
never hid `textmarkup-count-display`, `textmarkup-compare-row`, or `mediavote-timeline-display`, so
a revealed Text Markup (or Media Vote) session's results panel stayed visible after switching to a
plain Text Response session, until a full page reload rebuilt the DOM from its initially-hidden
state. Reported: set up a Text Response session, opened a separate Text Markup session, deleted it,
and returned to the Text Response session — its admin view still showed the Text Markup heatmap and
"Compare with…" row on top of the live feed.

### 2.3.1 — 2026-09-18
Text response display feed (`kyomei-display.html`) no longer echoes the category label on each
card — just the response text now. The colored left border (still keyed to category) is untouched.
Admin's own live feed still shows the category label per card, since the tutor needs it for
moderation context.

### 2.3.0 — 2026-09-16 — **schema**
Added independent open/close collection controls, session duplication with fresh responses, and paginated CSV export. Student pages show connection/receipt status and preserve text, prompt highlights, and ranking drafts locally; reset rounds isolate stale drafts and vote locks. Running Order uses the explicit collection switch rather than reveal to freeze submissions.

Fixed display moderation invalidation, transactional Running Order reset, delayed text-markup restore races, and superseded-team aggregates. Creation (including Pulse Checks), duplication, and reset are now authorized database transactions. Inline lifecycle helpers consolidate session monitoring and cleanup; view request guards discard delayed results after navigation or selection changes. Pages remain self-contained with no new runtime dependencies.

Added a sanitised tracked baseline, ordered migration, deployment instructions, and calculation/DOM/database regression tests. Apply `migrations/002_reliability_and_workflows.sql` to existing installations before deploying the updated HTML pages. Production Supabase was not modified by this code change.

### 2.2.1 — 2026-08-18
Quick Tap — admin's own results view (buttons/bar/pie/traffic-light/sparkline) was wrongly gated
behind `resultsRevealed`, the same flag that controls whether the room's display screen shows the
tally. Underlying data was always live (the realtime tally subscription and chart-cycle spacebar
shortcut both updated regardless), but the admin console hid the whole `tally-grid` and blocked
chart cycling until "Reveal results" was clicked. Admin's tally view is now always visible and
cyclable; `resultsRevealed` continues to gate only what `kyomei-display.html` shows, unchanged.

### 2.2.0 — 2026-08-18
Text/Guided sessions — parking a response is no longer a one-way trip. Added a "Parked (N)" toggle
next to the live feed that opens a list of parked responses, each with an Unpark button (sets
`friction_pool.status` back to `active`, which flows straight back into the live feed via the
existing realtime subscription) alongside the same type-to-confirm Delete already used in the main
feed. No schema change — reuses the existing `active`/`parked`/`deleted` status column.

### 2.1.1 — 2026-08-17 — **schema**
Moved to a new Supabase installation (`wlpbromzijkegqlbytew.supabase.co`). Updated `SUPABASE_URL`
and `SUPABASE_ANON_KEY` in `kyomei-admin.html`, `kyomei.html`, and `kyomei-display.html`, and set
the admin login email in `is_admin()` in `friction_pool_schema.sql`. Schema needs a manual run
against the new project (it was never run there before, not just re-run).

### 2.1.0 — 2026-08-05 — **schema**
Text Markup — two new tutor-controlled heatmap toggles, broadcast to the display screen the same
way chart-type cycling and the compare picker already are. (1) A "Solo selections" divergence mode
that highlights words picked by only 1-2 respondents instead of consensus hotspots, for discussing
what one student noticed that the room missed. (2) A colorblind-friendly Viridis-style palette
(dark purple → teal → yellow) alongside the existing blue-to-red ramp, with per-word text-color
contrast handling since that ramp swings from very dark to very bright — the classic palette's
fixed dark text is untouched. Both toggles live in kyomei-admin.html next to the heatmap view and
sync to kyomei-display.html via two new `sessions` columns (`text_markup_heatmap_mode`,
`text_markup_palette`); both reset to their defaults whenever results are freshly revealed, same as
chart-type. Schema change, needs manual re-run against Supabase.

### 2.0.2 — 2026-08-05 — **schema**
Running Order bug fixes found during an evaluation pass, not a new build prompt. (1) A device whose
team claim had been superseded (another device reclaimed the name after 5 minutes idle) reopened
straight into the ranking form on resume, only discovering the reclaim after its first move/submit
silently failed — `get_own_ranking_team()`'s result is now checked client-side and routes straight
to the "superseded" screen. (2) `claim_ranking_team()` had no `results_revealed` check, so a late
joiner could name a team and fully reorder items after reveal, hitting a wall only at submit;
added the same reveal check the other two RPCs already had, plus client-side handling so a
post-reveal join attempt (or an in-progress team that gets revealed out from under it) shows the
closed status immediately instead of after a wasted submit. (3) The tutor's item-editing controls
stay live for the whole session, not just before teams join, so a team's client-held item snapshot
can go stale mid-session; `submit_ranking_order`'s `INCOMPLETE_ORDER`/`INVALID_ITEM_IN_ORDER`
rejection used to surface as a generic "check your connection" message — now it refetches the
current item list, preserves the team's order for items that still exist, and shows an accurate
message. Added a non-blocking admin-side warning near the item editor once teams exist, so this is
less likely to happen in the first place. (4) `record_ranking_move` didn't reject a move where the
moved and swapped-with item are the same id (schema change, needs manual re-run against Supabase).
Also added `aria-label`s to the up/down reorder buttons (previously bare arrow glyphs with no
accessible name).

### 2.0.1 — 2026-08-05 — **schema**
Text Markup bug fixes found during an evaluation pass, not a new build prompt. (1) The
delete-confirmation dialog's impact counts (`fetchDeleteImpactCounts()` in kyomei-admin.html) only
ever branched on `quick_tap_enabled`; every other mode fell through to a `friction_pool`/
`session_categories` count that's always zero for them, so deleting a Text Markup, Media Vote, or
Running Order session showed "0 responses, 0 [items]" regardless of real data. Added proper
branches for all four modes. (2) `text_markup_responses.spans` had no server-side shape validation
— added a check constraint requiring a jsonb array of `{start, end}` objects with numeric,
non-negative, ordered bounds (schema change, needs manual re-run against Supabase). (3) The
heatmap/community aggregate (`computeTextMarkupWordCounts()`, duplicated in kyomei-admin.html and
kyomei-display.html) summed +1 per span per response with no de-dup, so a participant submitting
two overlapping highlight drags got double-counted for the overlapping words; now de-duped per
response before counting. Also addressed as drive-by polish: larger tap-to-remove hit target on
`.tm-word` (padding + compensating negative margin, no layout shift), `-webkit-touch-callout: none`
on the passage to reduce iOS native-selection-menu interference, and baseline ARIA (`role="button"`/
`aria-pressed` on word spans, `aria-live` on the textmarkup status banners) — not a substitute for
real keyboard operability, which the passage still lacks.

### 2.0.0 — 2026-08-04 — **schema**
Running Order — sixth session type. A tutor authors story headlines (with optional synopses);
physical groups each claim a team name on one device (the "editor") and reorder the stories into
a running order via up/down buttons, no drag. The tutor reveals either one team's final order or
a room-wide aggregate (average final position, plus two equal-weight oscillation views — raw move
count per item and pairwise reversal count — both derived from an append-only move log). Pre-reveal,
the projected display shows nothing about team progress, not even a count; that live count is
admin-only. New tables: `ranking_items`, `ranking_teams` (with a `superseded` flag closing a
reclaim race — a backgrounded-then-resumed device can't write against a team name someone else has
since reclaimed), `ranking_moves`, `ranking_submissions`; three new `plpgsql` RPCs (a first for this
schema — every prior RPC was plain SQL) handling claim/move/submit with server-side validation of
ownership, reveal state, and full-coverage `final_order`. Jumps ahead of the previously-planned
Threaded Conversation build (now next up, v2.1.0). Deliberate scope cut from the original concept
brief: only the ranking mechanic and the oscillation diagnostic ship — no student-facing question
capture (second-swap prompts, closing questions, a question wall) at all in this pass.

### 1.7.3 — 2026-07-31
Added `OPERATORS_MANUAL.md` — a tutor-facing operator's manual covering login, session creation
per mode (including Pulse Check), running a session (join info, guided/prompt reveal, feed
moderation, reveal/chart-cycling, Media Vote transport), reset/archive/delete, and the L/G/Space
keyboard shortcuts.

### 1.7.2 — 2026-07-13
Fixed a Text Markup display bug: revealing results then hiding them again left the previously-rendered heatmap/community view visible underneath the "Collecting responses…" status, because `applyTextMarkupChartTypeVisibility()` in kyomei-display.html only gated visibility on the selected chart type, not on `resultsRevealed`. Admin didn't have this bug — its equivalent containers sit inside a parent that's hidden directly on toggle.

### 1.7.1 — 2026-07-13 — **schema**
Fixed a 401 on every Text Markup submit. The client-side `upsert()` (on_conflict + merge-duplicates) requires anon to have SELECT visibility into the row it might conflict with, but the only anon SELECT policy on `text_markup_responses` is gated by `results_revealed` — so submits 401'd (42501) throughout normal collection, before any reveal. Replaced with a `submit_text_markup_response` security-definer RPC (same pattern as `get_own_text_markup_response`) that does the upsert server-side, bypassing the anon SELECT restriction without widening it.

### 1.7.0 — 2026-07-13 — **schema**
Text Markup: two independent aggregate-view improvements. (1) Non-linear (square-root) heatmap intensity scaling, applied identically in admin and display, so a single runaway-popular phrase no longer flattens every other word's relative intensity — secondary structure among more modest highlights stays visible. (2) Cross-prompt comparison view — a broadcast "Compare with…" control in admin (reveal-gated, like every other aggregate view) shows two prompts' heatmaps side by side on the display, reusing the exact same heatmap render function called twice rather than a second implementation. Scoped to heatmap only — community-highlight's ranked list is unaffected, still sorted by raw peak count.

### 1.6.0 — 2026-07-13 — **schema**
Text Markup: language and poetry support. Replaced whitespace-split tokenization with locale-aware `Intl.Segmenter` across all three files — the tokenizer function itself is byte-identical in all three, verified via diff, so word index `N` still refers to the same word everywhere. Fixes three real gaps: stanza/blank-line breaks were silently collapsed, whitespace-delimited splitting completely failed for languages with no spaces between words (Chinese, Japanese, Thai, Lao, Khmer, Myanmar), and there was no right-to-left support. New `passage_locale` field (admin form: dropdown of common presets + free-text override) drives both segmentation and automatic `dir="rtl"`/`"ltr"`.

**Known caveat, found while testing against the project's own English passage:** `Intl.Segmenter` tokenizes English differently than the old whitespace split — punctuation and hyphenated compounds (e.g. "mid-air", "plane.") now split into separate segments, changing the word count. Any pre-existing text-markup session that already has submitted student highlights should be **reset** after this deploys, or its heatmap will misalign against the old word indices. Brand-new sessions are unaffected.

### 1.5.2 — 2026-07-13
README: added a "JS libraries" section (`@supabase/supabase-js`, `qrcodejs`, Kaltura Player).

### 1.5.1 — 2026-07-13
Increased the margin below `.feed-category-label` — it was crowding the results/feed content directly beneath it.

### 1.5.0 — 2026-07-13 — **schema**
Quick-tap (buttons/bar/pie/sparkline) and text-markup (heatmap/community) chart-type cycling is now synced to the display, the same way group-by-category already was: admin's spacebar broadcasts via `sessions.quick_tap_chart_type` / `text_markup_chart_type`; display's own spacebar listener is removed entirely. Pulse Check sessions (traffic light/confidence) are unaffected. Also fixed two related gaps: display's session init previously hardcoded the starting chart type instead of resuming from any already-broadcast value, and a stale chart-type value could otherwise undo text-markup's "land on heatmap first on reveal" behaviour.

### 1.4.2 — 2026-07-13
Fixed "Display: waiting for video to load" showing stale on session reopen — `enterSession()` now does one fresh targeted fetch of `media_player_ready` right after the subscription starts, closing the gap where display had already become ready before admin opened the session.

### 1.4.1 — 2026-07-13
Fixed the same status getting stuck on a *reconnect* (not just first open) — the subscription now refetches the current value every time it reaches `SUBSCRIBED`, since Realtime only pushes changes that happen while a channel is live and never replays anything missed.

### 1.4.0 — 2026-07-13 — **schema**
Added a display-readiness signal (`media_player_ready`, `set_media_player_ready()` RPC) — the first reverse-direction broadcast in the app (display telling admin something, not the other way round). Admin shows a live "Display: ready" / "Display: waiting for video to load" status above the transport controls.

### 1.3.2 — 2026-07-13
Fixed the mmutube video autoplaying uncontrolled — `player.loadMedia()` was racing the play()/pause() autoplay-unlock pair; added `await player.ready()` first.

### 1.3.1 — 2026-07-13
Corrected Media Vote's reveal behaviour: revealing the timeline no longer replaces the video — it now sits visibly above the timeline strip at all times. Added a live playhead line (accurate on display via the real player's position; estimated on admin, reusing the position-readout formula) and made admin's timeline strip click-to-seek. Display's timeline remains non-interactive.

### 1.3.0 — 2026-07-13 — **schema**
Media Vote Stage 2: an aggregated, reveal-gated timeline reconstructing how the room's vote evolved across the clip, from the permanent transport-event log joined against vote timestamps. Broadcast bucket-size control (1/5/10/15/30s). Added an admin-only "Est. position" readout as a related diagnostic.

### 1.2.2 — 2026-07-13
Fixed the mmutube video playing muted — a remote "play" isn't a user gesture, so display now shows a "Load mmutube video" prompt and waits for a local click before setting up the player, matching the local-file picker's existing pattern.

### 1.2.1 — 2026-07-13
Superseded the tab-refocus fix in 1.0.1 — Supabase can report a tab-visibility session recovery as `SIGNED_IN`, not just `TOKEN_REFRESHED`, so event-name matching wasn't reliable. Replaced with a local `hasSeenSession` flag.

### 1.2.0 — 2026-07-13 — **schema**
Media Vote Stage 1.5: mmutube (Kaltura) embedded video as a second source alongside the local file picker, using Kaltura's Dynamic Embed pattern (not the non-programmable iframe embed).

### 1.1.2 — 2026-07-13
Fixed Pause snapping the clip back to a stale position — it was sending whatever position Play last started from instead of an estimate of where playback actually is.

### 1.1.1 — 2026-07-13
Colour-coded the Media Vote play/pause button by state (green = Play, yellow = Pause).

### 1.1.0 — 2026-07-13 — **schema**
Media Vote Stage 1: a fourth session type. A clip plays on the display, driven by Play/Pause/Seek/Restart transport controls in admin; students vote on a fixed button set as it plays. Transport commands are logged permanently for later reconstruction; votes record only a timestamp, never a client-side clip position.

### 1.0.3 — 2026-07-10
Added an "Open display ↗" button to the admin session view, and a subtle footer credit.

### 1.0.2 — 2026-07-10
Fixed the connection banner getting stuck on "Reconnecting to live feed…" after a normal, intentional teardown, and a follow-on fix for it false-hiding mid-genuine-reconnect.

### 1.0.1 — 2026-07-10
Fixed admin reverting to the session list on tab refocus — a backgrounded tab's token refresh was misread as a fresh sign-in.

### 1.0.0 — 2026-07-10
First deploy to GitHub (`digitaldickinson/kyomei`), excluding `CLAUDE.md` and the schema file. Added a README, a launcher page (`index.html`) linking to the staff/display/student pages.

---

## Foundation (pre-GitHub)

Everything below was already built before this project was deployed to GitHub — reconstructed from the schema file's own history comments, undated:

- **Friction Pool Stage 1** — the original text-response session type: `sessions`, `session_categories`, `friction_pool`, admin console, live feed.
- **Quick-tap mode** — instant-submit button polling, separate from the text-response flow.
- Session-list badge counts, one-vote-per-device soft lock, tally reveal gate.
- **Guided category mode** — tutor reveals one category at a time.
- **Onscreen display** (`kyomei-display.html`) — public read path for quick-tap results.
- Quick-tap heading (the question the buttons are answering).
- Session archive (soft delete).
- Confidence sparkline support (`device_id`-based last-observation-carried-forward).
- **Pulse Check quick-launch** — one-click traffic-light / confidence session types.
- Join-info overlay (admin-triggered, "L" key).
- Reset session responses (clear collected data, keep configuration).
- Group-by-category feed view, synced to the display ("G" key).
- **Interactive text markup** — the third session type: students highlight passage spans against tutor prompts.
- Own-row read RPC for text markup (so a student can see their own prior highlights pre-reveal).
- Reset extended to cover text markup.
