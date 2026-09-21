-- Kyomei 2.3.12: apply after 003_feed_masonry.sql.
begin;

-- Security review finding: this table's anon UPDATE policy was
-- `using (true) with check (true)` — completely unrestricted, unlike
-- every other anon-writable table in this schema (quick_tap_responses
-- and media_vote_responses only ever INSERT; ranking writes go
-- exclusively through security-definer RPCs with no raw table grant at
-- all). The app's real write path, submit_text_markup_response(), is a
-- pure upsert via ON CONFLICT and runs as a security-definer function,
-- so it was never affected by this policy either way. Removing it only
-- closes a separate hole: without it, any anon client could call the
-- REST API directly and overwrite any row in this table for any
-- device_id, bypassing the app (and the RPC's parameter shape) entirely.
drop policy if exists "anon can update text markup responses" on public.text_markup_responses;

notify pgrst, 'reload schema';
commit;
