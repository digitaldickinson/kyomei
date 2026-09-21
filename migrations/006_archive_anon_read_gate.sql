-- Kyomei 2.3.15: apply after 005_text_markup_device_id_lockdown.sql.
begin;

-- Security review finding: every anon-facing read policy in this schema
-- is scoped by session_id at best, never by whether that session is
-- still active — meaning any anonymous client can enumerate every
-- session (and its categories/responses/results) ever created in this
-- project, forever, with no session code required at all. Full
-- enforcement of "you must know the code" isn't achievable without
-- moving reads behind RPCs, which breaks Realtime delivery for anon
-- clients (display/student pages) unless redesigned alongside it — out
-- of scope here. What this migration does instead: bound exposure to
-- currently-active sessions only, by adding "and the parent session
-- isn't archived" to every anon read policy. Once a tutor archives a
-- session, anon access to it (and everything under it) stops entirely.
-- Admin (is_admin()) access is unaffected throughout — every policy
-- below is additive alongside an existing admin policy, SELECT policies
-- are OR'd together.

drop policy if exists "anon can read sessions" on public.sessions;
create policy "anon can read sessions" on public.sessions
  for select using (archived = false);

drop policy if exists "anon can read categories" on public.session_categories;
create policy "anon can read categories" on public.session_categories
  for select using (
    exists (select 1 from public.sessions s where s.id = session_categories.session_id and s.archived = false)
  );

drop policy if exists "anon can read active scenarios" on public.friction_pool;
create policy "anon can read active scenarios" on public.friction_pool
  for select using (
    (status = 'active' and exists (select 1 from public.sessions s where s.id = friction_pool.session_id and s.archived = false))
    or is_admin()
  );

drop policy if exists "anon can read quick tap options" on public.quick_tap_options;
create policy "anon can read quick tap options" on public.quick_tap_options
  for select using (
    exists (select 1 from public.sessions s where s.id = quick_tap_options.session_id and s.archived = false)
  );

drop policy if exists "anon can read revealed quick tap responses" on public.quick_tap_responses;
create policy "anon can read revealed quick tap responses" on public.quick_tap_responses
  for select using (
    exists (
      select 1 from public.sessions s
      where s.id = quick_tap_responses.session_id
      and s.results_revealed = true
      and s.archived = false
    )
  );

drop policy if exists "anon can read text markup prompts" on public.text_markup_prompts;
create policy "anon can read text markup prompts" on public.text_markup_prompts
  for select using (
    exists (select 1 from public.sessions s where s.id = text_markup_prompts.session_id and s.archived = false)
  );

drop policy if exists "anon can read revealed text markup responses" on public.text_markup_responses;
create policy "anon can read revealed text markup responses" on public.text_markup_responses
  for select using (
    exists (
      select 1 from public.sessions s
      where s.id = text_markup_responses.session_id
      and s.results_revealed = true
      and s.archived = false
    )
  );

drop policy if exists "anon can read revealed media vote responses" on public.media_vote_responses;
create policy "anon can read revealed media vote responses" on public.media_vote_responses
  for select using (
    exists (
      select 1 from public.sessions s
      where s.id = media_vote_responses.session_id
      and s.results_revealed = true
      and s.archived = false
    )
  );

drop policy if exists "anon can read revealed media transport events" on public.media_transport_events;
create policy "anon can read revealed media transport events" on public.media_transport_events
  for select using (
    exists (
      select 1 from public.sessions s
      where s.id = media_transport_events.session_id
      and s.results_revealed = true
      and s.archived = false
    )
  );

drop policy if exists "anon can read ranking items" on public.ranking_items;
create policy "anon can read ranking items" on public.ranking_items
  for select using (
    exists (select 1 from public.sessions s where s.id = ranking_items.session_id and s.archived = false)
  );

drop policy if exists "anon can read revealed ranking submissions" on public.ranking_submissions;
create policy "anon can read revealed ranking submissions" on public.ranking_submissions
  for select using (
    exists (
      select 1 from public.sessions s
      where s.id = ranking_submissions.session_id
      and s.results_revealed = true
      and s.archived = false
    )
  );

notify pgrst, 'reload schema';
commit;
