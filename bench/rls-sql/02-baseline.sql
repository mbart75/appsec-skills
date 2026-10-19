-- The "Supabase RLS, safe baseline" of appsec-harden, applied to a generic schema.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  role text not null default 'member' check (role in ('member', 'staff'))
);
create table public.notes (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id),
  body text not null,
  data jsonb not null default '{}',
  constraint notes_data_size check (octet_length(data::text) <= 10000),
  constraint notes_data_shape check (jsonb_typeof(data) = 'object')
);
create table public.links (
  id bigint generated always as identity primary key,
  owner_id uuid not null default auth.uid() references auth.users (id),
  grantee_id uuid not null references auth.users (id),
  status text not null default 'pending' check (status in ('pending', 'active'))
);

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.notes enable row level security;
alter table public.notes force row level security;
alter table public.links enable row level security;
alter table public.links force row level security;

-- Profiles: created by the server, readable and editable by their owner, role out of reach.
create policy profiles_select on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_update on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name) on public.profiles to authenticated;

create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = ''
  as $$ begin insert into public.profiles (id) values (new.id); return new; end $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Notes: owner, or a grantee through a link the owner activated.
create policy notes_select on public.notes for select to authenticated using (
  (select auth.uid()) = user_id
  or exists (select 1 from public.links l
             where l.owner_id = notes.user_id and l.grantee_id = (select auth.uid()) and l.status = 'active'));
create policy notes_insert on public.notes for insert to authenticated with check ((select auth.uid()) = user_id);
create policy notes_update on public.notes for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy notes_delete on public.notes for delete to authenticated using ((select auth.uid()) = user_id);

-- Links: created and activated only by the data owner; either side may read; either side may end it.
create policy links_select on public.links for select to authenticated
  using ((select auth.uid()) in (owner_id, grantee_id));
create policy links_insert on public.links for insert to authenticated with check (owner_id = (select auth.uid()));
create policy links_update on public.links for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy links_delete on public.links for delete to authenticated
  using ((select auth.uid()) in (owner_id, grantee_id));

-- Second factor for the sensitive role on the table it reaches through links.
create policy notes_staff_aal2 on public.notes as restrictive for select to authenticated using (
  (select auth.jwt() ->> 'aal') = 'aal2'
  or not exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'staff'));

-- A hardened security definer function and a security invoker view.
create function public.my_note_count() returns bigint language sql stable security definer set search_path = ''
  as $$ select count(*) from public.notes where user_id = (select auth.uid()) $$;
revoke execute on function public.my_note_count() from public, anon;
grant execute on function public.my_note_count() to authenticated;
create view public.my_notes with (security_invoker = true) as select id, body from public.notes;
