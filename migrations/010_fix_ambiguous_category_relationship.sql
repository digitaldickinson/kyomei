-- Kyomei 2.3.22: apply after 009_private_credentials_and_archive_guards.sql.
--
-- Bug in 007: it added a composite foreign key (session_id, category_id/
-- option_id/prompt_id) *alongside* the original single-column one, instead
-- of replacing it. With two separate FK constraints between the same pair
-- of tables, PostgREST's embedded-select relationship detection can no
-- longer pick one automatically — any query using the `table(columns)`
-- embed syntax between these pairs now fails with "Could not embed
-- because more than one relationship was found". Confirmed live: this
-- broke kyomei-admin.html's and kyomei-display.html's friction_pool feed
-- (`.select('*, session_categories(label)')`, 3 call sites) the moment
-- 007 was applied.
--
-- Fix: drop the original single-column FK for each pair — the composite
-- FK already implies it (a valid (session_id, id) match requires id to
-- exist in the referenced table at all) — so nothing is lost, just the
-- duplicate relationship. Recreated with the original's ON DELETE
-- behavior (007's composite FKs defaulted to NO ACTION, silently
-- changing friction_pool/quick_tap_responses/media_vote_responses/
-- text_markup_responses from their original RESTRICT/CASCADE).
--
-- No other table pair has this ambiguity — confirmed only friction_pool/
-- session_categories is ever used in an embedded select anywhere in the
-- three application pages, but quick_tap_responses/media_vote_responses/
-- text_markup_responses get the same fix regardless, since the
-- underlying duplicate-FK problem is identical and would bite the same
-- way the moment anyone adds an embedded select against them.

begin;

alter table public.friction_pool drop constraint if exists friction_pool_category_id_fkey;
alter table public.friction_pool drop constraint if exists friction_pool_category_session_fkey;
alter table public.friction_pool add constraint friction_pool_category_session_fkey
  foreign key (session_id, category_id) references public.session_categories (session_id, id) on delete restrict;

alter table public.quick_tap_responses drop constraint if exists quick_tap_responses_option_id_fkey;
alter table public.quick_tap_responses drop constraint if exists quick_tap_responses_option_session_fkey;
alter table public.quick_tap_responses add constraint quick_tap_responses_option_session_fkey
  foreign key (session_id, option_id) references public.quick_tap_options (session_id, id) on delete cascade;

alter table public.media_vote_responses drop constraint if exists media_vote_responses_option_id_fkey;
alter table public.media_vote_responses drop constraint if exists media_vote_responses_option_session_fkey;
alter table public.media_vote_responses add constraint media_vote_responses_option_session_fkey
  foreign key (session_id, option_id) references public.quick_tap_options (session_id, id) on delete cascade;

alter table public.text_markup_responses drop constraint if exists text_markup_responses_prompt_id_fkey;
alter table public.text_markup_responses drop constraint if exists text_markup_responses_prompt_session_fkey;
alter table public.text_markup_responses add constraint text_markup_responses_prompt_session_fkey
  foreign key (session_id, prompt_id) references public.text_markup_prompts (session_id, id) on delete cascade;

notify pgrst, 'reload schema';
commit;
