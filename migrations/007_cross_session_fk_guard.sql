-- Kyomei 2.3.16: apply after 006_archive_anon_read_gate.sql.
--
-- Security review finding: "Response tables reference sessions and
-- options/categories independently, without enforcing that they belong
-- together." Confirmed: friction_pool.category_id, quick_tap_responses.
-- option_id, text_markup_responses.prompt_id, and media_vote_responses.
-- option_id are each a plain FK to the *global* id of a session-scoped
-- table, with no check that the referenced row's own session_id matches
-- the response's session_id. An anon client (these four tables all have
-- direct, non-RPC anon INSERT policies) could submit a response tagged
-- with session A's session_id but session B's category/option/prompt id
-- — both individually valid, just belonging to different sessions —
-- landing a response that reads as A's but renders with B's label, or
-- worse, corrupts A's aggregates with a prompt/option that was never
-- actually offered there.
--
-- The ranking tables (moves/submissions) do NOT have this gap: both
-- write exclusively through security-definer RPCs (record_ranking_move,
-- submit_ranking_order) which already explicitly check
-- "... where id = p_item_id and session_id = p_session_id" before
-- writing — confirmed by reading both functions. No change needed there.
--
-- Fix: composite foreign keys, the standard Postgres pattern for
-- "this child row's parent reference must also agree on tenant/session."
-- Each needs a supporting unique constraint on the referenced table's
-- (session_id, id) pair first — trivially satisfiable since id alone is
-- already the primary key.
--
-- CAUTION: if any existing row in your database already has a
-- mismatched category/option/prompt id (from a bug, manual edit, or a
-- prior exploit of this exact gap), this migration will fail to apply
-- with a constraint-violation error naming the offending row. Find and
-- fix (or delete) it before re-running.

begin;

-- Drop dependent child constraints before recreating their parent keys.
alter table public.friction_pool drop constraint if exists friction_pool_category_session_fkey;
alter table public.quick_tap_responses drop constraint if exists quick_tap_responses_option_session_fkey;
alter table public.media_vote_responses drop constraint if exists media_vote_responses_option_session_fkey;
alter table public.text_markup_responses drop constraint if exists text_markup_responses_prompt_session_fkey;

alter table public.session_categories drop constraint if exists session_categories_session_id_id_key;
alter table public.session_categories add constraint session_categories_session_id_id_key unique (session_id, id);
alter table public.friction_pool add constraint friction_pool_category_session_fkey
  foreign key (session_id, category_id) references public.session_categories (session_id, id);

alter table public.quick_tap_options drop constraint if exists quick_tap_options_session_id_id_key;
alter table public.quick_tap_options add constraint quick_tap_options_session_id_id_key unique (session_id, id);
alter table public.quick_tap_responses add constraint quick_tap_responses_option_session_fkey
  foreign key (session_id, option_id) references public.quick_tap_options (session_id, id);
alter table public.media_vote_responses add constraint media_vote_responses_option_session_fkey
  foreign key (session_id, option_id) references public.quick_tap_options (session_id, id);

alter table public.text_markup_prompts drop constraint if exists text_markup_prompts_session_id_id_key;
alter table public.text_markup_prompts add constraint text_markup_prompts_session_id_id_key unique (session_id, id);
alter table public.text_markup_responses add constraint text_markup_responses_prompt_session_fkey
  foreign key (session_id, prompt_id) references public.text_markup_prompts (session_id, id);

notify pgrst, 'reload schema';
commit;
