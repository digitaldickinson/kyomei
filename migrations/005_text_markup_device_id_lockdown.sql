-- Kyomei 2.3.14: apply after 004_text_markup_update_lockdown.sql.
begin;

-- Security review finding: once a session's results are revealed, the
-- existing SELECT policy exposes every column to any anon client,
-- including device_id — a crypto-random UUID that's otherwise never
-- shared with anyone but its own device. Once it leaks (any anon client
-- can just request it via the REST API, regardless of what the app's own
-- UI selects), it can be used to impersonate that device against
-- submit_text_markup_response(), which trusts whatever device_id it's
-- given. The app itself never needs device_id here — kyomei-display.html
-- only ever selects spans, and the Realtime payload handler only reads
-- session_id/prompt_id — so this locks anon's column access down to
-- exactly what's actually used, via Postgres column-level privileges
-- layered on top of the existing row-level policy (RLS still applies).
revoke select on public.text_markup_responses from anon;
grant select (id, session_id, prompt_id, spans, updated_at) on public.text_markup_responses to anon;

notify pgrst, 'reload schema';
commit;
