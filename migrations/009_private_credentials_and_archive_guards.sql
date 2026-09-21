-- Kyomei 2.3.21: apply after 008; safe to rerun. Apply between classes.
-- Legacy editing credentials may already have leaked. Invalidate them without
-- deleting results. Refresh student tabs and reset reused sessions before class.
begin;

-- Private credentials are never stored or returned in plaintext. The domain and
-- session binding prevent a voting identifier or another mode's token being used
-- as an editing credential. This helper is callable only by the owning RPCs.
create or replace function public.private_device_key(p_kind text, p_session_id uuid, p_secret text)
returns text language plpgsql immutable set search_path = public as $$
begin
  if p_secret is null or length(trim(p_secret)) < 32 or length(p_secret) > 256 then
    raise exception 'INVALID_DEVICE_CREDENTIAL';
  end if;
  return 'sha256:' || encode(sha256(convert_to(p_kind || ':' || p_session_id::text || ':' || p_secret, 'UTF8')), 'hex');
end;
$$;
revoke all on function public.private_device_key(text, uuid, text) from public, anon, authenticated;

-- Old values were browser IDs, potentially already public. Randomise only legacy
-- rows; reruns preserve hashes created by the new RPCs. Results remain readable.
-- Disable just the submission gate while rekeying closed/archived legacy rows.
alter table public.text_markup_responses disable trigger check_markup_update;
update public.text_markup_responses
set device_id = 'sha256:' || encode(sha256(convert_to(gen_random_uuid()::text, 'UTF8')), 'hex')
where device_id not like 'sha256:%';
alter table public.text_markup_responses enable trigger check_markup_update;
update public.ranking_teams
set editor_device_id = 'sha256:' || encode(sha256(convert_to(gen_random_uuid()::text, 'UTF8')), 'hex')
where editor_device_id not like 'sha256:%';

-- All markup writes must pass through the hashing RPC. Authenticated non-admin
-- users get exactly the same safe column projection as anonymous users.
drop policy if exists "anon can insert text markup responses" on public.text_markup_responses;
drop policy if exists "anon can update text markup responses" on public.text_markup_responses;
revoke select on public.text_markup_responses from anon, authenticated;
grant select (id, session_id, prompt_id, spans, updated_at, response_epoch) on public.text_markup_responses to anon, authenticated;


create or replace function public.check_submission_state() returns trigger
language plpgsql security definer set search_path = public as $$
declare s sessions;
begin
  select * into s from sessions where id = new.session_id for share;
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  if s.archived then raise exception 'SESSION_ARCHIVED'; end if;
  if not s.submissions_open then raise exception 'SUBMISSIONS_CLOSED'; end if;
  if new.response_epoch is distinct from s.response_epoch then raise exception 'SESSION_RESET'; end if;
  return new;
end;
$$;

create or replace function submit_text_markup_response(
  p_session_id uuid,
  p_prompt_id uuid,
  p_device_id text,
  p_spans jsonb,
  p_response_epoch integer default 0
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into text_markup_responses (session_id, prompt_id, device_id, spans, updated_at, response_epoch)
  values (p_session_id, p_prompt_id, private_device_key('markup', p_session_id, p_device_id), p_spans, now(), p_response_epoch)
  on conflict (session_id, prompt_id, device_id)
  do update set spans = excluded.spans, updated_at = excluded.updated_at, response_epoch = excluded.response_epoch;
$$;

create or replace function claim_ranking_team(
  p_session_id uuid,
  p_team_name text,
  p_device_id text,
  p_response_epoch integer default 0
)
returns ranking_teams
language plpgsql
security definer
set search_path = public
as $$
declare
  v_normalised text := lower(trim(p_team_name));
  v_existing ranking_teams;
  v_new ranking_teams;
begin
  perform 1 from sessions where id = p_session_id for share;
  if exists (select 1 from sessions where id = p_session_id and archived) then
    raise exception 'SESSION_ARCHIVED';
  end if;
  if not exists (select 1 from sessions where id = p_session_id and response_epoch = p_response_epoch) then
    raise exception 'SESSION_RESET';
  end if;
  if v_normalised = '' then
    raise exception 'EMPTY_TEAM_NAME' using errcode = 'P0001';
  end if;

  -- Collection is controlled by submissions_open, independently of reveal.
  -- The check_submission_state trigger enforces this under the session lock.

  perform pg_advisory_xact_lock(hashtext(p_session_id::text || ':' || v_normalised));

  select * into v_existing
  from ranking_teams
  where session_id = p_session_id
    and lower(trim(team_name)) = v_normalised
    and superseded = false
    and last_activity_at > now() - interval '5 minutes'
  limit 1;

  if found then
    raise exception 'TEAM_NAME_TAKEN' using errcode = 'P0001';
  end if;

  update ranking_teams
  set superseded = true
  where session_id = p_session_id
    and lower(trim(team_name)) = v_normalised
    and superseded = false;

  insert into ranking_teams (session_id, team_name, editor_device_id, last_activity_at, response_epoch)
  values (p_session_id, trim(p_team_name), private_device_key('ranking', p_session_id, p_device_id), now(), p_response_epoch)
  returning * into v_new;

  return v_new;
end;
$$;

create or replace function record_ranking_move(
  p_session_id uuid,
  p_team_id uuid,
  p_device_id text,
  p_moved_item_id uuid,
  p_swapped_with_item_id uuid,
  p_response_epoch integer default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owns boolean;
  v_superseded boolean;
begin
  perform 1 from sessions where id = p_session_id for share;
  if exists (select 1 from sessions where id = p_session_id and archived) then
    raise exception 'SESSION_ARCHIVED';
  end if;
  if not exists (select 1 from sessions where id = p_session_id and response_epoch = p_response_epoch) then
    raise exception 'SESSION_RESET';
  end if;
  select (editor_device_id = private_device_key('ranking', p_session_id, p_device_id)), superseded
    into v_owns, v_superseded
  from ranking_teams
  where id = p_team_id and session_id = p_session_id;

  if not coalesce(v_owns, false) then
    raise exception 'NOT_TEAM_EDITOR' using errcode = 'P0001';
  end if;

  if coalesce(v_superseded, false) then
    raise exception 'TEAM_SUPERSEDED' using errcode = 'P0001';
  end if;

  -- Collection is controlled by submissions_open, independently of reveal.
  -- The check_submission_state trigger enforces this under the session lock.

  if p_moved_item_id = p_swapped_with_item_id then
    raise exception 'INVALID_MOVE' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from ranking_items where id = p_moved_item_id and session_id = p_session_id
  ) or not exists (
    select 1 from ranking_items where id = p_swapped_with_item_id and session_id = p_session_id
  ) then
    raise exception 'ITEM_NOT_IN_SESSION' using errcode = 'P0001';
  end if;

  insert into ranking_moves (session_id, team_id, moved_item_id, swapped_with_item_id, response_epoch)
  values (p_session_id, p_team_id, p_moved_item_id, p_swapped_with_item_id, p_response_epoch);

  update ranking_teams set last_activity_at = now() where id = p_team_id;
end;
$$;

create or replace function submit_ranking_order(
  p_session_id uuid,
  p_team_id uuid,
  p_device_id text,
  p_final_order jsonb,
  p_response_epoch integer default 0
)
returns ranking_submissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owns boolean;
  v_superseded boolean;
  v_expected_count int;
  v_provided_count int;
  v_matching_count int;
  v_result ranking_submissions;
begin
  perform 1 from sessions where id = p_session_id for share;
  if exists (select 1 from sessions where id = p_session_id and archived) then
    raise exception 'SESSION_ARCHIVED';
  end if;
  if not exists (select 1 from sessions where id = p_session_id and response_epoch = p_response_epoch) then
    raise exception 'SESSION_RESET';
  end if;
  select (editor_device_id = private_device_key('ranking', p_session_id, p_device_id)), superseded
    into v_owns, v_superseded
  from ranking_teams
  where id = p_team_id and session_id = p_session_id;

  if not coalesce(v_owns, false) then
    raise exception 'NOT_TEAM_EDITOR' using errcode = 'P0001';
  end if;

  if coalesce(v_superseded, false) then
    raise exception 'TEAM_SUPERSEDED' using errcode = 'P0001';
  end if;

  -- Collection is controlled by submissions_open, independently of reveal.
  -- The check_submission_state trigger enforces this under the session lock.

  select count(*) into v_expected_count from ranking_items where session_id = p_session_id;
  select jsonb_array_length(p_final_order) into v_provided_count;

  if v_provided_count is distinct from v_expected_count then
    raise exception 'INCOMPLETE_ORDER' using errcode = 'P0001';
  end if;

  select count(*) into v_matching_count
  from ranking_items ri
  where ri.session_id = p_session_id
    and ri.id::text in (select jsonb_array_elements_text(p_final_order));

  if v_matching_count is distinct from v_expected_count then
    raise exception 'INVALID_ITEM_IN_ORDER' using errcode = 'P0001';
  end if;

  insert into ranking_submissions (session_id, team_id, final_order, submitted_at, response_epoch)
  values (p_session_id, p_team_id, p_final_order, now(), p_response_epoch)
  on conflict (team_id) do update
    set final_order = excluded.final_order, submitted_at = excluded.submitted_at
  returning * into v_result;

  update ranking_teams set last_activity_at = now() where id = p_team_id;

  return v_result;
end;
$$;

create or replace function get_own_text_markup_response(
  p_session_id uuid,
  p_prompt_id uuid,
  p_device_id text
)
returns setof text_markup_responses
language sql
security definer
set search_path = public
as $$
  select * from text_markup_responses
  where session_id = p_session_id
    and exists (select 1 from sessions where id = p_session_id and (not archived or is_admin()))
    and prompt_id = p_prompt_id
    and device_id = private_device_key('markup', p_session_id, p_device_id);
$$;

create or replace function get_own_ranking_team(
  p_session_id uuid,
  p_device_id text
)
returns setof ranking_teams
language sql
security definer
set search_path = public
as $$
  select * from ranking_teams
  where session_id = p_session_id
    and exists (select 1 from sessions where id = p_session_id and (not archived or is_admin()))
    and editor_device_id = private_device_key('ranking', p_session_id, p_device_id)
  order by created_at desc
  limit 1;
$$;

create or replace function public.get_own_ranking_submission(p_session_id uuid, p_device_id text)
returns setof ranking_submissions language sql stable security definer set search_path = public as $$
  select sub.* from ranking_submissions sub join ranking_teams t on t.id = sub.team_id
  where sub.session_id = p_session_id and t.editor_device_id = private_device_key('ranking', p_session_id, p_device_id) and not t.superseded
    and exists (select 1 from sessions where id = p_session_id and (not archived or is_admin()));
$$;

create or replace function get_ranking_item_move_counts(p_session_id uuid)
returns table(item_id uuid, move_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select m.moved_item_id as item_id, count(*) as move_count
  from ranking_moves m
  join ranking_submissions sub on sub.team_id = m.team_id
  join ranking_teams t on t.id = m.team_id and not t.superseded
  where m.session_id = p_session_id
    and exists (
      select 1 from sessions s
      where s.id = p_session_id and s.results_revealed = true and (not s.archived or is_admin())
    )
  group by m.moved_item_id;
$$;

create or replace function get_ranking_pair_reversals(p_session_id uuid)
returns table(item_a_id uuid, item_b_id uuid, reversal_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select
    least(m.moved_item_id, m.swapped_with_item_id) as item_a_id,
    greatest(m.moved_item_id, m.swapped_with_item_id) as item_b_id,
    count(*) as reversal_count
  from ranking_moves m
  join ranking_submissions sub on sub.team_id = m.team_id
  join ranking_teams t on t.id = m.team_id and not t.superseded
  where m.session_id = p_session_id
    and exists (
      select 1 from sessions s
      where s.id = p_session_id and s.results_revealed = true and (not s.archived or is_admin())
    )
  group by least(m.moved_item_id, m.swapped_with_item_id), greatest(m.moved_item_id, m.swapped_with_item_id)
  order by reversal_count desc;
$$;

create or replace function public.get_current_ranking_submissions(p_session_id uuid)
returns setof ranking_submissions language sql stable security definer set search_path = public as $$
  select sub.* from ranking_submissions sub join ranking_teams t on t.id = sub.team_id
  where sub.session_id = p_session_id and not t.superseded
    and (is_admin() or exists (select 1 from sessions where id = p_session_id and results_revealed and not archived));
$$;

create or replace function set_media_player_ready(p_session_id uuid, p_ready boolean)
returns void
language sql
security definer
set search_path = public
as $$
  update sessions set media_player_ready = p_ready where id = p_session_id and not archived;
$$;

-- A unique registry serialises conflicting votes even across concurrent DB
-- transactions. Track all non-empty device IDs so switching one-vote on respects
-- earlier votes. No client can read or write this table directly.
create table if not exists public.quick_tap_vote_claims (
  session_id uuid not null references public.sessions(id) on delete cascade,
  response_epoch integer not null,
  device_id text not null,
  primary key (session_id, response_epoch, device_id)
);
alter table public.quick_tap_vote_claims enable row level security;
revoke all on public.quick_tap_vote_claims from public, anon, authenticated;
insert into public.quick_tap_vote_claims (session_id, response_epoch, device_id)
select distinct session_id, response_epoch, device_id from public.quick_tap_responses
where device_id is not null and trim(device_id) <> ''
on conflict do nothing;

create or replace function public.check_one_vote_per_device() returns trigger
language plpgsql security definer set search_path = public as $$
declare limited boolean; claimed boolean;
begin
  -- Match the submission gate's lock order; reset/close cannot pass this write.
  select one_vote_per_device into limited from sessions where id = new.session_id for share;
  if new.device_id is null or trim(new.device_id) = '' then
    if limited then raise exception 'DEVICE_ID_REQUIRED'; end if;
    return new;
  end if;
  insert into quick_tap_vote_claims (session_id, response_epoch, device_id)
  values (new.session_id, new.response_epoch, new.device_id)
  on conflict do nothing;
  claimed := found;
  if limited and not claimed then raise exception 'ALREADY_VOTED'; end if;
  return new;
end;
$$;


create or replace function public.reset_session_responses(p_session_id uuid)
returns sessions language plpgsql security definer set search_path = public as $$
declare result sessions;
begin
  if not coalesce(is_admin(), false) then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  perform 1 from sessions where id = p_session_id for update;
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  delete from friction_pool where session_id = p_session_id;
  delete from quick_tap_responses where session_id = p_session_id;
  delete from quick_tap_vote_claims where session_id = p_session_id;
  delete from text_markup_responses where session_id = p_session_id;
  delete from media_vote_responses where session_id = p_session_id;
  delete from media_transport_events where session_id = p_session_id;
  delete from ranking_teams where session_id = p_session_id; -- cascades moves/submissions
  update sessions set results_revealed = false, response_epoch = response_epoch + 1,
    active_category_id = null, active_prompt_id = null, text_markup_compare_prompt_id = null,
    active_ranking_team_id = null, ranking_view_mode = null,
    media_transport_action = null, media_transport_position_ms = null,
    media_transport_issued_at = null, media_transport_seq = 0
  where id = p_session_id returning * into result;
  return result;
end;
$$;

notify pgrst, 'reload schema';
commit;
