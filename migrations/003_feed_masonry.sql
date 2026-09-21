-- Kyomei 2.3.7: apply after 002_reliability_and_workflows.sql.
begin;

-- Wall view (masonry) toggle for the plain text-response feed — same
-- pattern as feed_grouped, drives kyomei-display.html's feed layout only.
alter table public.sessions add column if not exists feed_masonry boolean not null default false;

notify pgrst, 'reload schema';
commit;
