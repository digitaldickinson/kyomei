-- Kyomei 3.0.0: Quiz session type. Apply after 011_student_controls.sql; safe to rerun.
-- Publish the updated pages after applying this migration.
begin;

alter table public.sessions add column if not exists quiz_enabled boolean not null default false;

-- Questions and options carry no secrets: students and the display read them
-- directly while the session is unarchived. The correct option lives in
-- quiz_answer_keys, which only the administrator can read; the room learns it
-- through get_quiz_results() once the tutor reveals the answer.
create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  prompt_text text not null check (length(trim(prompt_text)) > 0),
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (session_id, id)
);

create table if not exists public.quiz_options (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  question_id uuid not null,
  label text not null check (length(trim(label)) > 0),
  color text,
  sort_order int not null default 0,
  unique (question_id, id),
  unique (question_id, label),
  unique (question_id, sort_order),
  foreign key (session_id, question_id) references public.quiz_questions (session_id, id) on delete cascade
);

create table if not exists public.quiz_answer_keys (
  question_id uuid primary key,
  session_id uuid not null references public.sessions(id) on delete cascade,
  option_id uuid not null,
  foreign key (session_id, question_id) references public.quiz_questions (session_id, id) on delete cascade,
  foreign key (question_id, option_id) references public.quiz_options (question_id, id) on delete cascade
);

-- One answer per browser identifier per question per reset round. The unique
-- key is the database backstop for tap-and-lock; device_id is a public voting
-- identifier, as for quick-tap, not a private credential.
create table if not exists public.quiz_responses (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  question_id uuid not null,
  option_id uuid not null,
  device_id text not null check (length(trim(device_id)) between 1 and 200),
  response_epoch integer not null default 0,
  unique (session_id, response_epoch, question_id, device_id),
  foreign key (session_id, question_id) references public.quiz_questions (session_id, id) on delete cascade,
  foreign key (question_id, option_id) references public.quiz_options (question_id, id) on delete cascade
);
create index if not exists idx_quiz_responses_question on public.quiz_responses(question_id);

-- Broadcast state, same pattern as active_prompt_id: the tutor picks the
-- question; quiz_reveal drives only the projected display.
alter table public.sessions add column if not exists active_quiz_question_id uuid
  references public.quiz_questions(id) on delete set null;
alter table public.sessions add column if not exists quiz_reveal text
  check (quiz_reveal is null or quiz_reveal in ('tally', 'answer'));

alter table public.quiz_questions enable row level security;
alter table public.quiz_options enable row level security;
alter table public.quiz_answer_keys enable row level security;
alter table public.quiz_responses enable row level security;

drop policy if exists "anon can read quiz questions" on public.quiz_questions;
create policy "anon can read quiz questions" on public.quiz_questions
  for select using (
    exists (select 1 from public.sessions s where s.id = quiz_questions.session_id and s.archived = false)
  );
drop policy if exists "admin can manage quiz questions" on public.quiz_questions;
create policy "admin can manage quiz questions" on public.quiz_questions
  for all using (is_admin()) with check (is_admin());

drop policy if exists "anon can read quiz options" on public.quiz_options;
create policy "anon can read quiz options" on public.quiz_options
  for select using (
    exists (select 1 from public.sessions s where s.id = quiz_options.session_id and s.archived = false)
  );
drop policy if exists "admin can manage quiz options" on public.quiz_options;
create policy "admin can manage quiz options" on public.quiz_options
  for all using (is_admin()) with check (is_admin());

drop policy if exists "admin can manage quiz answer keys" on public.quiz_answer_keys;
create policy "admin can manage quiz answer keys" on public.quiz_answer_keys
  for all using (is_admin()) with check (is_admin());

-- No anon/non-admin SELECT policy: students cannot read answers back, and
-- Realtime therefore delivers response events only to the administrator.
drop policy if exists "anon can insert quiz responses" on public.quiz_responses;
create policy "anon can insert quiz responses" on public.quiz_responses
  for insert with check (true);
drop policy if exists "admin can read quiz responses" on public.quiz_responses;
create policy "admin can read quiz responses" on public.quiz_responses
  for select using (is_admin());
drop policy if exists "admin can delete quiz responses" on public.quiz_responses;
create policy "admin can delete quiz responses" on public.quiz_responses
  for delete using (is_admin());

grant select, insert, update, delete on public.quiz_questions, public.quiz_options, public.quiz_responses to anon, authenticated;
revoke all on public.quiz_answer_keys from public, anon;
grant select, insert, update, delete on public.quiz_answer_keys to authenticated;

drop trigger if exists check_submission_state on public.quiz_responses;
create trigger check_submission_state before insert on public.quiz_responses
for each row execute function public.check_submission_state();

-- Named to run after check_submission_state (triggers fire alphabetically), so
-- a closed, archived or reset session reports that state first.
create or replace function public.check_quiz_answer_question() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_active uuid;
begin
  select active_quiz_question_id into v_active from sessions where id = new.session_id for share;
  if v_active is distinct from new.question_id then raise exception 'QUESTION_NOT_ACTIVE'; end if;
  return new;
end;
$$;
revoke all on function public.check_quiz_answer_question() from public, anon, authenticated;
drop trigger if exists quiz_answer_targets_active_question on public.quiz_responses;
create trigger quiz_answer_targets_active_question before insert on public.quiz_responses
for each row execute function public.check_quiz_answer_question();

-- The display's only read of quiz results. Gated purely on session state, with
-- no administrator bypass: the projector often runs in the tutor's signed-in
-- browser, and must not show counts or the answer before the reveal.
create or replace function public.get_quiz_results(p_session_id uuid)
returns table(option_id uuid, answer_count bigint, is_correct boolean)
language sql stable security definer set search_path = public as $$
  select o.id,
    (select count(*) from quiz_responses r
      where r.session_id = s.id and r.question_id = o.question_id and r.option_id = o.id),
    case when s.quiz_reveal = 'answer'
      then exists (select 1 from quiz_answer_keys k where k.question_id = o.question_id and k.option_id = o.id)
      else null end
  from sessions s
  join quiz_options o on o.session_id = s.id and o.question_id = s.active_quiz_question_id
  where s.id = p_session_id and s.quiz_enabled and s.quiz_reveal is not null
    and (not s.archived or is_admin())
  order by o.sort_order;
$$;
revoke all on function public.get_quiz_results(uuid) from public;
grant execute on function public.get_quiz_results(uuid) to anon, authenticated;

-- Students follow the active question through the controls projection.
-- quiz_reveal is deliberately not projected: reveal steps send students nothing.
alter table public.student_controls add column if not exists active_quiz_question_id uuid;

create or replace function public.sync_student_controls() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.student_controls as c
    (id, submissions_open, response_epoch, active_category_id, active_prompt_id, one_vote_per_device, active_quiz_question_id)
  values (new.id, new.submissions_open, new.response_epoch,
    case when new.guided_categories then new.active_category_id else null end,
    case when new.text_markup_enabled then new.active_prompt_id else null end,
    coalesce(new.one_vote_per_device, false),
    case when new.quiz_enabled then new.active_quiz_question_id else null end)
  on conflict (id) do update set
    submissions_open = excluded.submissions_open,
    response_epoch = excluded.response_epoch,
    active_category_id = excluded.active_category_id,
    active_prompt_id = excluded.active_prompt_id,
    one_vote_per_device = excluded.one_vote_per_device,
    active_quiz_question_id = excluded.active_quiz_question_id
  where (c.submissions_open, c.response_epoch, c.active_category_id, c.active_prompt_id, c.one_vote_per_device, c.active_quiz_question_id)
    is distinct from (excluded.submissions_open, excluded.response_epoch,
      excluded.active_category_id, excluded.active_prompt_id, excluded.one_vote_per_device, excluded.active_quiz_question_id);
  return new;
end;
$$;
revoke all on function public.sync_student_controls() from public, anon, authenticated;

insert into public.student_controls as c
  (id, submissions_open, response_epoch, active_category_id, active_prompt_id, one_vote_per_device, active_quiz_question_id)
select id, submissions_open, response_epoch,
  case when guided_categories then active_category_id else null end,
  case when text_markup_enabled then active_prompt_id else null end,
  coalesce(one_vote_per_device, false),
  case when quiz_enabled then active_quiz_question_id else null end
from public.sessions
on conflict (id) do update set
  submissions_open = excluded.submissions_open, response_epoch = excluded.response_epoch,
  active_category_id = excluded.active_category_id, active_prompt_id = excluded.active_prompt_id,
  one_vote_per_device = excluded.one_vote_per_device, active_quiz_question_id = excluded.active_quiz_question_id
where (c.submissions_open, c.response_epoch, c.active_category_id, c.active_prompt_id, c.one_vote_per_device, c.active_quiz_question_id)
  is distinct from (excluded.submissions_open, excluded.response_epoch,
    excluded.active_category_id, excluded.active_prompt_id, excluded.one_vote_per_device, excluded.active_quiz_question_id);

-- Session-list badge counts gain a quiz answer count (return type change).
drop function if exists public.session_counts();
create function public.session_counts()
returns table(session_id uuid, active_count bigint, tap_count bigint, quiz_count bigint)
language sql stable
as $$
  select s.id,
    coalesce(fp.cnt, 0) as active_count,
    coalesce(qt.cnt, 0) as tap_count,
    coalesce(qz.cnt, 0) as quiz_count
  from sessions s
  left join (select session_id, count(*) cnt from friction_pool where status = 'active' group by session_id) fp
    on fp.session_id = s.id
  left join (select session_id, count(*) cnt from quick_tap_responses group by session_id) qt
    on qt.session_id = s.id
  left join (select session_id, count(*) cnt from quiz_responses group by session_id) qz
    on qz.session_id = s.id;
$$;
revoke execute on function public.session_counts() from public;
grant execute on function public.session_counts() to authenticated;

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
  delete from quiz_responses where session_id = p_session_id;
  update sessions set results_revealed = false, response_epoch = response_epoch + 1,
    active_category_id = null, active_prompt_id = null, text_markup_compare_prompt_id = null,
    active_ranking_team_id = null, ranking_view_mode = null,
    media_transport_action = null, media_transport_position_ms = null,
    media_transport_issued_at = null, media_transport_seq = 0,
    active_quiz_question_id = null, quiz_reveal = null
  where id = p_session_id returning * into result;
  return result;
end;
$$;
revoke all on function public.reset_session_responses(uuid) from public;
grant execute on function public.reset_session_responses(uuid) to authenticated;

-- A fifth argument carries quiz questions. Drop the four-argument signature so
-- named-argument calls cannot match two overloads.
drop function if exists public.create_classroom_session(jsonb, jsonb, jsonb, jsonb);
create or replace function public.create_classroom_session(
  p_config jsonb, p_categories jsonb default '[]', p_options jsonb default '[]', p_prompts jsonb default '[]',
  p_quiz jsonb default '[]'
) returns sessions language plpgsql security definer set search_path = public as $$
declare
  result sessions;
  v_question jsonb;
  v_index bigint;
  v_question_id uuid;
  v_option_count int;
  v_correct int;
begin
  if not coalesce(is_admin(), false) then raise exception 'ADMIN_REQUIRED' using errcode = '42501'; end if;
  if coalesce(trim(p_config->>'name'), '') = '' or coalesce(p_config->>'session_code', '') !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'INVALID_SESSION_NAME_OR_CODE';
  end if;
  insert into sessions (name, session_code, quick_tap_enabled, one_vote_per_device,
    guided_categories, quick_tap_heading, quick_tap_style, text_markup_enabled, passage_text,
    passage_locale, media_vote_enabled, media_source_type, media_entry_id, running_order_enabled, quiz_enabled)
  values (p_config->>'name', p_config->>'session_code', coalesce((p_config->>'quick_tap_enabled')::boolean,false),
    coalesce((p_config->>'one_vote_per_device')::boolean,false), coalesce((p_config->>'guided_categories')::boolean,false),
    p_config->>'quick_tap_heading', p_config->>'quick_tap_style', coalesce((p_config->>'text_markup_enabled')::boolean,false),
    p_config->>'passage_text', coalesce(p_config->>'passage_locale','en'), coalesce((p_config->>'media_vote_enabled')::boolean,false),
    p_config->>'media_source_type', p_config->>'media_entry_id', coalesce((p_config->>'running_order_enabled')::boolean,false),
    coalesce((p_config->>'quiz_enabled')::boolean,false))
  returning * into result;
  insert into session_categories (session_id,label,sort_order)
    select result.id, value, ordinality - 1 from jsonb_array_elements_text(p_categories) with ordinality;
  insert into quick_tap_options (session_id,label,color,sort_order)
    select result.id, value->>'label', value->>'color', ordinality - 1 from jsonb_array_elements(p_options) with ordinality;
  insert into text_markup_prompts (session_id,prompt_text,sort_order)
    select result.id, value, ordinality - 1 from jsonb_array_elements_text(p_prompts) with ordinality;
  if result.quiz_enabled then
    if jsonb_typeof(p_quiz) is distinct from 'array' or jsonb_array_length(p_quiz) = 0 then
      raise exception 'QUIZ_NEEDS_QUESTIONS';
    end if;
    for v_question, v_index in select value, ordinality - 1 from jsonb_array_elements(p_quiz) with ordinality loop
      if jsonb_typeof(v_question->'options') is distinct from 'array' then raise exception 'INVALID_QUIZ_QUESTION'; end if;
      v_option_count := jsonb_array_length(v_question->'options');
      v_correct := (v_question->>'correct')::int;
      if v_option_count not between 2 and 6 or v_correct is null or v_correct not between 0 and v_option_count - 1 then
        raise exception 'INVALID_QUIZ_QUESTION';
      end if;
      insert into quiz_questions (session_id, prompt_text, sort_order)
        values (result.id, trim(v_question->>'prompt'), v_index) returning id into v_question_id;
      insert into quiz_options (session_id, question_id, label, color, sort_order)
        select result.id, v_question_id, trim(value->>'label'), value->>'color', ordinality - 1
        from jsonb_array_elements(v_question->'options') with ordinality;
      insert into quiz_answer_keys (question_id, session_id, option_id)
        select v_question_id, result.id, id from quiz_options where question_id = v_question_id and sort_order = v_correct;
    end loop;
  end if;
  return result;
end;
$$;
revoke all on function public.create_classroom_session(jsonb,jsonb,jsonb,jsonb,jsonb) from public;
grant execute on function public.create_classroom_session(jsonb,jsonb,jsonb,jsonb,jsonb) to authenticated;

create or replace function public.duplicate_classroom_session(p_session_id uuid, p_name text, p_code text)
returns sessions language plpgsql security definer set search_path = public as $$
declare original sessions; result sessions; v_old_question quiz_questions; v_question_id uuid;
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
    'media_transport_issued_at',null,'media_transport_seq',0,
    'active_quiz_question_id',null,'quiz_reveal',null))).* returning * into result;
  insert into session_categories(session_id,label,sort_order) select result.id,label,sort_order from session_categories where session_id = original.id;
  insert into quick_tap_options(session_id,label,color,sort_order) select result.id,label,color,sort_order from quick_tap_options where session_id = original.id;
  insert into text_markup_prompts(session_id,prompt_text,sort_order) select result.id,prompt_text,sort_order from text_markup_prompts where session_id = original.id;
  insert into ranking_items(session_id,label,synopsis,sort_order) select result.id,label,synopsis,sort_order from ranking_items where session_id = original.id;
  for v_old_question in select * from quiz_questions where session_id = original.id order by sort_order loop
    insert into quiz_questions (session_id, prompt_text, sort_order)
      values (result.id, v_old_question.prompt_text, v_old_question.sort_order) returning id into v_question_id;
    insert into quiz_options (session_id, question_id, label, color, sort_order)
      select result.id, v_question_id, label, color, sort_order from quiz_options where question_id = v_old_question.id;
    insert into quiz_answer_keys (question_id, session_id, option_id)
      select v_question_id, result.id, copied.id
      from quiz_answer_keys k
      join quiz_options src on src.id = k.option_id
      join quiz_options copied on copied.question_id = v_question_id and copied.sort_order = src.sort_order
      where k.question_id = v_old_question.id;
  end loop;
  return result;
end;
$$;
revoke all on function public.duplicate_classroom_session(uuid,text,text) from public;
grant execute on function public.duplicate_classroom_session(uuid,text,text) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'quiz_responses'
  ) then
    alter publication supabase_realtime add table public.quiz_responses;
  end if;
end $$;

notify pgrst, 'reload schema';
commit;
