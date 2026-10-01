-- Kyomei 2.5.4: student-only Realtime controls; apply before publishing kyomei.html.
begin;

create table if not exists public.student_controls (
  id uuid primary key references public.sessions(id) on delete cascade,
  submissions_open boolean not null,
  response_epoch integer not null,
  active_category_id uuid,
  active_prompt_id uuid,
  one_vote_per_device boolean not null
);
alter table public.student_controls enable row level security;
revoke all on public.student_controls from public, anon, authenticated;
grant select on public.student_controls to anon, authenticated;
drop policy if exists "read available student controls" on public.student_controls;
create policy "read available student controls" on public.student_controls
  for select to anon, authenticated using (
    exists (select 1 from public.sessions s where s.id = student_controls.id
      and (s.archived = false or public.is_admin()))
  );

-- Only the database maintains this projection. The conditional upsert is essential:
-- a display-only session update must produce no student_controls UPDATE/WAL event.
create or replace function public.sync_student_controls() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.student_controls as c
    (id, submissions_open, response_epoch, active_category_id, active_prompt_id, one_vote_per_device)
  values (new.id, new.submissions_open, new.response_epoch,
    case when new.guided_categories then new.active_category_id else null end,
    case when new.text_markup_enabled then new.active_prompt_id else null end,
    coalesce(new.one_vote_per_device, false))
  on conflict (id) do update set
    submissions_open = excluded.submissions_open,
    response_epoch = excluded.response_epoch,
    active_category_id = excluded.active_category_id,
    active_prompt_id = excluded.active_prompt_id,
    one_vote_per_device = excluded.one_vote_per_device
  where (c.submissions_open, c.response_epoch, c.active_category_id, c.active_prompt_id, c.one_vote_per_device)
    is distinct from (excluded.submissions_open, excluded.response_epoch,
      excluded.active_category_id, excluded.active_prompt_id, excluded.one_vote_per_device);
  return new;
end;
$$;
revoke all on function public.sync_student_controls() from public, anon, authenticated;
drop trigger if exists sync_student_controls on public.sessions;
create trigger sync_student_controls after insert or update on public.sessions
  for each row execute function public.sync_student_controls();

-- Backfill existing sessions, also safe when rerunning this migration.
insert into public.student_controls as c
  (id, submissions_open, response_epoch, active_category_id, active_prompt_id, one_vote_per_device)
select id, submissions_open, response_epoch,
  case when guided_categories then active_category_id else null end,
  case when text_markup_enabled then active_prompt_id else null end,
  coalesce(one_vote_per_device, false)
from public.sessions
on conflict (id) do update set
  submissions_open = excluded.submissions_open, response_epoch = excluded.response_epoch,
  active_category_id = excluded.active_category_id, active_prompt_id = excluded.active_prompt_id,
  one_vote_per_device = excluded.one_vote_per_device
where (c.submissions_open, c.response_epoch, c.active_category_id, c.active_prompt_id, c.one_vote_per_device)
  is distinct from (excluded.submissions_open, excluded.response_epoch,
    excluded.active_category_id, excluded.active_prompt_id, excluded.one_vote_per_device);

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
    and schemaname = 'public' and tablename = 'student_controls') then
    alter publication supabase_realtime add table public.student_controls;
  end if;
end $$;
notify pgrst, 'reload schema';
commit;
