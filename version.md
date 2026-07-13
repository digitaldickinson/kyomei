# Version history

Semantic versioning (`MAJOR.MINOR.PATCH`):

- **MAJOR** — a new session type, or a change that breaks compatibility with existing sessions/data.
- **MINOR** — a new feature within an existing session type (a new stage, a new control, a new broadcast field).
- **PATCH** — a bug fix, a copy/layout tweak, or a schema addition that only supports a fix above.

Update this file with each change that ships — bump the version, add an entry at the top of the log below. `friction_pool_schema.sql` is not tracked in git, so any entry that changed the schema is flagged (**schema**) as a reminder to re-run it against Supabase.

**Current version: 1.5.2**

---

## Log

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
