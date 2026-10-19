-- Deliberate misconfigurations the checklist queries must flag (no data is involved).
create table public.leaky (id int primary key, note text);                 -- item 1: no RLS
create table public.loose (id int primary key, owner uuid);
alter table public.loose enable row level security;
create policy loose_update on public.loose for update to authenticated
  using ((select auth.uid()) = owner) with check (true);                  -- item 3: with check (true)
create function public.unsafe_fn() returns bigint language sql security definer
  as $$ select count(*) from public.notes $$;                             -- item 9: no search_path, executable by all
create view public.all_notes as select id, body from public.notes;        -- item 10: no security_invoker
