-- Kyomei 2.3.17: apply after 007_cross_session_fk_guard.sql.
--
-- Security review finding: one_vote_per_device was enforced entirely
-- client-side (a localStorage check in kyomei.html) — trivially bypassed
-- by clearing storage, an incognito window, or a different browser.
-- Explicit decision, not a silent gap: this project promises a real
-- database backstop, closing the "just clear storage" bypass while still
-- allowing a genuinely fresh device (or a deliberately reset one) to
-- vote once — device_id itself is unauthenticated, so this raises the
-- bar from trivial to deliberate, it doesn't claim to be unbeatable.
--
-- Separate trigger rather than extending the existing shared
-- check_submission_state() — that function is deliberately uniform
-- across seven tables; this check only ever applies to one.

begin;

create or replace function public.check_one_vote_per_device() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_one_vote_per_device boolean;
begin
  select one_vote_per_device into v_one_vote_per_device from sessions where id = new.session_id;
  if coalesce(v_one_vote_per_device, false) and new.device_id is not null and exists (
    select 1 from quick_tap_responses
    where session_id = new.session_id and device_id = new.device_id
  ) then
    raise exception 'ALREADY_VOTED' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists check_one_vote_per_device on public.quick_tap_responses;
create trigger check_one_vote_per_device before insert on public.quick_tap_responses
for each row execute function public.check_one_vote_per_device();

notify pgrst, 'reload schema';
commit;
