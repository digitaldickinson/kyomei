-- Kyomei 2.3.0: apply after 001_baseline.sql (existing projects: this file only).
begin;
alter table public.sessions add column if not exists submissions_open boolean not null default true;
alter table public.sessions add column if not exists response_epoch integer not null default 0;
alter table public.sessions add column if not exists feed_revision bigint not null default 0;

-- Publish only an invalidation counter, never moderated response contents.
create or replace function public.invalidate_session_feed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'DELETE' then
    update sessions set feed_revision = feed_revision + 1 where id = old.session_id;
    return old;
  end if;
  update sessions set feed_revision = feed_revision + 1 where id = new.session_id;
  return new;
end;
$$;
drop trigger if exists invalidate_session_feed on public.friction_pool;
create trigger invalidate_session_feed after update or delete on public.friction_pool
for each row execute function public.invalidate_session_feed();

-- A shared row lock serialises submission with close/reset operations.
create or replace function public.check_submission_state() returns trigger
language plpgsql security definer set search_path = public as $$
declare s sessions;
begin
  select * into s from sessions where id = new.session_id for share;
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  if not s.submissions_open then raise exception 'SUBMISSIONS_CLOSED'; end if;
  if new.response_epoch is distinct from s.response_epoch then raise exception 'SESSION_RESET'; end if;
  return new;
end;
$$;
alter table public.friction_pool add column if not exists response_epoch integer not null default 0;
drop trigger if exists check_submission_state on public.friction_pool;
create trigger check_submission_state before insert on public.friction_pool
for each row execute function public.check_submission_state();
alter table public.quick_tap_responses add column if not exists response_epoch integer not null default 0;
drop trigger if exists check_submission_state on public.quick_tap_responses;
create trigger check_submission_state before insert on public.quick_tap_responses
for each row execute function public.check_submission_state();
alter table public.text_markup_responses add column if not exists response_epoch integer not null default 0;
drop trigger if exists check_submission_state on public.text_markup_responses;
create trigger check_submission_state before insert on public.text_markup_responses
for each row execute function public.check_submission_state();
alter table public.media_vote_responses add column if not exists response_epoch integer not null default 0;
drop trigger if exists check_submission_state on public.media_vote_responses;
create trigger check_submission_state before insert on public.media_vote_responses
for each row execute function public.check_submission_state();
alter table public.ranking_teams add column if not exists response_epoch integer not null default 0;
drop trigger if exists check_submission_state on public.ranking_teams;
create trigger check_submission_state before insert on public.ranking_teams
for each row execute function public.check_submission_state();
alter table public.ranking_moves add column if not exists response_epoch integer not null default 0;
drop trigger if exists check_submission_state on public.ranking_moves;
create trigger check_submission_state before insert on public.ranking_moves
for each row execute function public.check_submission_state();
alter table public.ranking_submissions add column if not exists response_epoch integer not null default 0;
drop trigger if exists check_submission_state on public.ranking_submissions;
create trigger check_submission_state before insert on public.ranking_submissions
for each row execute function public.check_submission_state();
drop trigger if exists check_markup_update on public.text_markup_responses;
create trigger check_markup_update before update on public.text_markup_responses
for each row execute function public.check_submission_state();

drop function if exists submit_text_markup_response(uuid, uuid, text, jsonb);
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
  values (p_session_id, p_prompt_id, p_device_id, p_spans, now(), p_response_epoch)
  on conflict (session_id, prompt_id, device_id)
  do update set spans = excluded.spans, updated_at = excluded.updated_at, response_epoch = excluded.response_epoch;
$$;
revoke all on function submit_text_markup_response(uuid, uuid, text, jsonb, integer) from public;
grant execute on function submit_text_markup_response(uuid, uuid, text, jsonb, integer) to anon, authenticated;

drop function if exists claim_ranking_team(uuid, text, text);
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
  values (p_session_id, trim(p_team_name), p_device_id, now(), p_response_epoch)
  returning * into v_new;

  return v_new;
end;
$$;
revoke all on function claim_ranking_team(uuid, text, text, integer) from public;
grant execute on function claim_ranking_team(uuid, text, text, integer) to anon, authenticated;

drop function if exists record_ranking_move(uuid, uuid, text, uuid, uuid);
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
  if not exists (select 1 from sessions where id = p_session_id and response_epoch = p_response_epoch) then
    raise exception 'SESSION_RESET';
  end if;
  select (editor_device_id = p_device_id), superseded
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
revoke all on function record_ranking_move(uuid, uuid, text, uuid, uuid, integer) from public;
grant execute on function record_ranking_move(uuid, uuid, text, uuid, uuid, integer) to anon, authenticated;

drop function if exists submit_ranking_order(uuid, uuid, text, jsonb);
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
  if not exists (select 1 from sessions where id = p_session_id and response_epoch = p_response_epoch) then
    raise exception 'SESSION_RESET';
  end if;
  select (editor_device_id = p_device_id), superseded
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
revoke all on function submit_ranking_order(uuid, uuid, text, jsonb, integer) from public;
grant execute on function submit_ranking_order(uuid, uuid, text, jsonb, integer) to anon, authenticated;

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
      where s.id = p_session_id and s.results_revealed = true
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
      where s.id = p_session_id and s.results_revealed = true
    )
  group by least(m.moved_item_id, m.swapped_with_item_id), greatest(m.moved_item_id, m.swapped_with_item_id)
  order by reversal_count desc;
$$;

-- A narrow projection avoids exposing team editor device IDs to the display.
create or replace function public.get_current_ranking_submissions(p_session_id uuid)
returns setof ranking_submissions language sql stable security definer set search_path = public as $$
  select sub.* from ranking_submissions sub join ranking_teams t on t.id = sub.team_id
  where sub.session_id = p_session_id and not t.superseded
    and (is_admin() or exists (select 1 from sessions where id = p_session_id and results_revealed));
$$;
revoke all on function public.get_current_ranking_submissions(uuid) from public;
grant execute on function public.get_current_ranking_submissions(uuid) to anon, authenticated;

create or replace function public.get_own_ranking_submission(p_session_id uuid, p_device_id text)
returns setof ranking_submissions language sql stable security definer set search_path = public as $$
  select sub.* from ranking_submissions sub join ranking_teams t on t.id = sub.team_id
  where sub.session_id = p_session_id and t.editor_device_id = p_device_id and not t.superseded;
$$;
revoke all on function public.get_own_ranking_submission(uuid, text) from public;
grant execute on function public.get_own_ranking_submission(uuid, text) to anon, authenticated;

create or replace function public.reset_session_responses(p_session_id uuid)
returns sessions language plpgsql security definer set search_path = public as $$
declare result sessions;
begin
  if not coalesce(is_admin(), false) then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  perform 1 from sessions where id = p_session_id for update;
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  delete from friction_pool where session_id = p_session_id;
  delete from quick_tap_responses where session_id = p_session_id;
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
revoke all on function public.reset_session_responses(uuid) from public;
grant execute on function public.reset_session_responses(uuid) to authenticated;

create or replace function public.create_classroom_session(
  p_config jsonb, p_categories jsonb default '[]', p_options jsonb default '[]', p_prompts jsonb default '[]'
) returns sessions language plpgsql security definer set search_path = public as $$
declare result sessions;
begin
  if not coalesce(is_admin(), false) then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  if coalesce(trim(p_config->>'name'), '') = '' or coalesce(p_config->>'session_code', '') !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'INVALID_SESSION_NAME_OR_CODE';
  end if;
  insert into sessions (name, session_code, quick_tap_enabled, one_vote_per_device,
    guided_categories, quick_tap_heading, quick_tap_style, text_markup_enabled, passage_text,
    passage_locale, media_vote_enabled, media_source_type, media_entry_id, running_order_enabled)
  values (p_config->>'name', p_config->>'session_code', coalesce((p_config->>'quick_tap_enabled')::boolean,false),
    coalesce((p_config->>'one_vote_per_device')::boolean,false), coalesce((p_config->>'guided_categories')::boolean,false),
    p_config->>'quick_tap_heading', p_config->>'quick_tap_style', coalesce((p_config->>'text_markup_enabled')::boolean,false),
    p_config->>'passage_text', coalesce(p_config->>'passage_locale','en'), coalesce((p_config->>'media_vote_enabled')::boolean,false),
    p_config->>'media_source_type', p_config->>'media_entry_id', coalesce((p_config->>'running_order_enabled')::boolean,false))
  returning * into result;
  insert into session_categories (session_id,label,sort_order)
    select result.id, value, ordinality - 1 from jsonb_array_elements_text(p_categories) with ordinality;
  insert into quick_tap_options (session_id,label,color,sort_order)
    select result.id, value->>'label', value->>'color', ordinality - 1 from jsonb_array_elements(p_options) with ordinality;
  insert into text_markup_prompts (session_id,prompt_text,sort_order)
    select result.id, value, ordinality - 1 from jsonb_array_elements_text(p_prompts) with ordinality;
  return result;
end;
$$;
revoke all on function public.create_classroom_session(jsonb,jsonb,jsonb,jsonb) from public;
grant execute on function public.create_classroom_session(jsonb,jsonb,jsonb,jsonb) to authenticated;

create or replace function public.duplicate_classroom_session(p_session_id uuid, p_name text, p_code text)
returns sessions language plpgsql security definer set search_path = public as $$
declare original sessions; result sessions;
begin
  if not coalesce(is_admin(),false) then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  if coalesce(trim(p_name),'') = '' or coalesce(p_code,'') !~ '^[A-Za-z0-9_-]+$' then raise exception 'INVALID_SESSION_NAME_OR_CODE'; end if;
  select * into original from sessions where id = p_session_id for share;
  if not found then raise exception 'SESSION_NOT_FOUND'; end if;
  insert into sessions select (jsonb_populate_record(null::sessions, to_jsonb(original) || jsonb_build_object(
    'id',gen_random_uuid(),'name',trim(p_name),'session_code',p_code,'created_at',now(),
    'archived',false,'results_revealed',false,'submissions_open',true,'response_epoch',0,'feed_revision',0,
    'active_category_id',null,'active_prompt_id',null,'text_markup_compare_prompt_id',null,
    'active_ranking_team_id',null,'ranking_view_mode',null,'show_join_info',false,
    'media_player_ready',false,'media_transport_action',null,'media_transport_position_ms',null,
    'media_transport_issued_at',null,'media_transport_seq',0))).* returning * into result;
  insert into session_categories(session_id,label,sort_order) select result.id,label,sort_order from session_categories where session_id = original.id;
  insert into quick_tap_options(session_id,label,color,sort_order) select result.id,label,color,sort_order from quick_tap_options where session_id = original.id;
  insert into text_markup_prompts(session_id,prompt_text,sort_order) select result.id,prompt_text,sort_order from text_markup_prompts where session_id = original.id;
  insert into ranking_items(session_id,label,synopsis,sort_order) select result.id,label,synopsis,sort_order from ranking_items where session_id = original.id;
  return result;
end;
$$;
revoke all on function public.duplicate_classroom_session(uuid,text,text) from public;
grant execute on function public.duplicate_classroom_session(uuid,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
