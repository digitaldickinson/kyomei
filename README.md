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

## Backend

Data is stored in [Supabase](https://supabase.com) (via `@supabase/supabase-js`),
using tables such as `sessions`, `session_categories`, `friction_pool`,
`quick_tap_options`, `quick_tap_responses`, `text_markup_prompts`, and
`text_markup_responses`. Real-time updates are delivered through Supabase
channel subscriptions.

## Running locally

These are static HTML files with no build step — serve the directory with
any static file server and open `kyomei-admin.html` to create a session, or
`kyomei.html` / `kyomei-display.html` with a session ID to join one.
