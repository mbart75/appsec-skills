-- Behaviour of the baseline, played as each account. Every block prints PASS or FAIL.
\set QUIET on
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'b@example.test'),
  ('33333333-3333-3333-3333-333333333333', 's@example.test');
update public.profiles set role = 'staff' where id = '33333333-3333-3333-3333-333333333333';
insert into public.notes (user_id, body) values ('11111111-1111-1111-1111-111111111111', 'note of A');

create function pg_temp.as_user(uid text, aal text default 'aal1') returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid, true);
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'aal', aal)::text, true);
  execute 'set local role authenticated';
end $$;

do $$ declare n int; begin
  perform set_config('request.jwt.claim.sub', '', true); execute 'set local role anon';
  select count(*) into n from public.notes;
  raise notice '% 01 public key reads notes: % rows', case when n = 0 then 'PASS' else 'FAIL' end, n;
end $$;

do $$ declare n int; begin
  perform pg_temp.as_user('22222222-2222-2222-2222-222222222222');
  select count(*) into n from public.notes where user_id = '11111111-1111-1111-1111-111111111111';
  raise notice '% 02 unrelated account reads the owner''s notes: % rows', case when n = 0 then 'PASS' else 'FAIL' end, n;
  select count(*) into n from public.my_notes;
  raise notice '% 03 security_invoker view keeps RLS: % rows', case when n = 0 then 'PASS' else 'FAIL' end, n;
end $$;

do $$ begin
  perform pg_temp.as_user('22222222-2222-2222-2222-222222222222');
  insert into public.links (owner_id, grantee_id, status)
    values ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'active');
  raise notice 'FAIL 04 grantee creates its own active link';
exception when insufficient_privilege then raise notice 'PASS 04 grantee creates its own active link: refused (42501)';
end $$;

do $$ begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.links (owner_id, grantee_id) values ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');
end $$;

do $$ declare n int; begin
  perform pg_temp.as_user('22222222-2222-2222-2222-222222222222');
  update public.links set status = 'active' where grantee_id = '22222222-2222-2222-2222-222222222222';
  get diagnostics n = row_count;
  raise notice '% 05 grantee activates a pending link: % rows changed', case when n = 0 then 'PASS' else 'FAIL' end, n;
  select count(*) into n from public.notes where user_id = '11111111-1111-1111-1111-111111111111';
  raise notice '% 06 grantee reads before activation: % rows', case when n = 0 then 'PASS' else 'FAIL' end, n;
end $$;

do $$ begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  update public.links set status = 'active' where owner_id = '11111111-1111-1111-1111-111111111111';
end $$;

do $$ declare n int; begin
  perform pg_temp.as_user('22222222-2222-2222-2222-222222222222');
  select count(*) into n from public.notes where user_id = '11111111-1111-1111-1111-111111111111';
  raise notice '% 07 grantee reads after the owner activates: % rows', case when n = 1 then 'PASS' else 'FAIL' end, n;
end $$;

do $$ begin
  perform pg_temp.as_user('22222222-2222-2222-2222-222222222222');
  insert into public.notes (user_id, body) values ('11111111-1111-1111-1111-111111111111', 'forged');
  raise notice 'FAIL 08 insert a row owned by someone else';
exception when insufficient_privilege then raise notice 'PASS 08 insert a row owned by someone else: refused (42501)';
end $$;

do $$ begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  update public.notes set user_id = '22222222-2222-2222-2222-222222222222' where user_id = '11111111-1111-1111-1111-111111111111';
  raise notice 'FAIL 09 move an own row to another owner';
exception when insufficient_privilege then raise notice 'PASS 09 move an own row to another owner: refused (42501)';
end $$;

do $$ begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  update public.profiles set role = 'staff' where id = '11111111-1111-1111-1111-111111111111';
  raise notice 'FAIL 10 change own role';
exception when insufficient_privilege then raise notice 'PASS 10 change own role: refused explicitly (42501)';
end $$;

do $$ declare n int; begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  update public.profiles set display_name = 'A' where id = '11111111-1111-1111-1111-111111111111';
  get diagnostics n = row_count;
  raise notice '% 11 change own display name: % rows', case when n = 1 then 'PASS' else 'FAIL' end, n;
end $$;

-- The pitfall the baseline warns about: revoking one column does not override a table-wide grant.
create table public.pitfall (id uuid primary key, role text);
alter table public.pitfall enable row level security;
create policy pitfall_update on public.pitfall for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy pitfall_select on public.pitfall for select to authenticated using ((select auth.uid()) = id);
revoke update (role) on public.pitfall from authenticated;
insert into public.pitfall values ('11111111-1111-1111-1111-111111111111', 'member');
do $$ declare n int; begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  update public.pitfall set role = 'staff' where id = '11111111-1111-1111-1111-111111111111';
  get diagnostics n = row_count;
  raise notice '% 12 column revoke alone, table-wide grant kept: role still writable (% rows)', case when n = 1 then 'PASS' else 'FAIL' end, n;
exception when insufficient_privilege then raise notice 'FAIL 12 column revoke alone blocked the update: the baseline warning is wrong';
end $$;

do $$ begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.notes (body, data) values ('big', jsonb_build_object('x', repeat('a', 20000)));
  raise notice 'FAIL 13 oversized JSON';
exception when check_violation then raise notice 'PASS 13 oversized JSON: refused (23514)';
end $$;

do $$ begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.notes (body, data) values ('array', '[1, 2]');
  raise notice 'FAIL 14 JSON of the wrong shape';
exception when check_violation then raise notice 'PASS 14 JSON of the wrong shape: refused (23514)';
end $$;

do $$ begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.links (owner_id, grantee_id, status) values ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'active');
end $$;

do $$ declare n int; begin
  perform pg_temp.as_user('33333333-3333-3333-3333-333333333333', 'aal1');
  select count(*) into n from public.notes where user_id = '11111111-1111-1111-1111-111111111111';
  raise notice '% 15 staff without second factor reads a linked account: % rows', case when n = 0 then 'PASS' else 'FAIL' end, n;
end $$;

do $$ declare n int; begin
  perform pg_temp.as_user('33333333-3333-3333-3333-333333333333', 'aal2');
  select count(*) into n from public.notes where user_id = '11111111-1111-1111-1111-111111111111';
  raise notice '% 16 staff with second factor reads a linked account: % rows', case when n = 1 then 'PASS' else 'FAIL' end, n;
end $$;

do $$ declare n bigint; begin
  perform set_config('request.jwt.claim.sub', '', true); execute 'set local role anon';
  select public.my_note_count() into n;
  raise notice 'FAIL 17 public key executes a restricted function';
exception when insufficient_privilege then raise notice 'PASS 17 public key executes a restricted function: refused (42501)';
end $$;

do $$ declare n bigint; begin
  perform pg_temp.as_user('11111111-1111-1111-1111-111111111111');
  select public.my_note_count() into n;
  raise notice '% 18 security definer function returns only the caller''s count: %', case when n = 1 then 'PASS' else 'FAIL' end, n;
end $$;

-- What the misconfigured objects of 03-bad.sql allow, as the public key.
do $$ declare n int; begin
  perform set_config('request.jwt.claim.sub', '', true); execute 'set local role anon';
  select count(*) into n from public.all_notes;
  raise notice '% 19 view without security_invoker leaks to the public key: % rows', case when n > 0 then 'PASS' else 'FAIL' end, n;
  insert into public.leaky values (1, 'written by anyone');
  raise notice 'PASS 20 table without RLS is writable with the public key';
end $$;
