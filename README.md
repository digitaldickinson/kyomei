# kyomei

A lightweight app for classroom interaction. Students submit responses from
their own devices; teachers run and monitor sessions from an admin console;
a display view projects live results for the room.

## Pages

- **`kyomei.html`** — student view. Submits responses to a session in one of
  several modes: free-text response, guided scenario, passage highlighting
  (text markup), or quick-tap multiple choice.
- **`kyomei-admin.html`** — teacher console. Create and manage sessions,
  configure categories and prompts, and watch responses come in live.
- **`kyomei-display.html`** — read-only display view for projecting live
  session results.

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

## JS libraries

Loaded via CDN `<script>` tags, no build step or package manager:

- **[`@supabase/supabase-js`](https://github.com/supabase/supabase-js) v2** — all three pages. Database reads/writes and Realtime channel subscriptions.
- **[`qrcodejs`](https://github.com/davidshimjs/qrcodejs) v1.0.0** — `kyomei-display.html` only. Renders the join QR code.
- **Kaltura Player (PlayKit JS)** — `kyomei-display.html` only, loaded dynamically at runtime (not a static `<script>` tag) the first time a Media Vote session's video source is `mmutube`. Uses the Dynamic Embed pattern (`KalturaPlayer.setup()`), not the non-programmable iframe embed.

## Backend

Data is stored in [Supabase](https://supabase.com) (via `@supabase/supabase-js`),
using tables such as `sessions`, `session_categories`, `friction_pool`,
`quick_tap_options`, `quick_tap_responses`, `text_markup_prompts`, and
`text_markup_responses`. Real-time updates are delivered through Supabase
channel subscriptions.

## Running locally

These are static HTML files with no build step. But you will need to run them from a sever that everyone can access. For example, use GitHub Pages or Netify drop -  https://app.netlify.com/drop 
