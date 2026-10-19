-- The checklist must flag each misconfiguration of 03-bad.sql and none of the baseline objects.
\set QUIET on
do $$ declare r record; begin
  for r in select tablename, rowsecurity from pg_tables where schemaname = 'public' order by 1 loop
    raise notice '% 21 RLS flag: % = %', case when r.rowsecurity = (r.tablename not in ('leaky', 'pitfall')) or (r.tablename = 'pitfall' and r.rowsecurity) then 'PASS' else 'FAIL' end, r.tablename, r.rowsecurity;
  end loop;
end $$;
do $$ declare n int; begin
  select count(*) into n from pg_policies where schemaname = 'public' and cmd = 'UPDATE' and with_check = 'true';
  raise notice '% 22 update policies with "with check (true)" found: % (expected 1, loose_update)', case when n = 1 then 'PASS' else 'FAIL' end, n;
end $$;
do $$ declare n int; begin
  select count(*) into n from information_schema.column_privileges
   where table_schema = 'public' and table_name = 'profiles' and column_name = 'role' and privilege_type = 'UPDATE' and grantee in ('anon', 'authenticated');
  raise notice '% 23 UPDATE on profiles.role for API roles: % grants', case when n = 0 then 'PASS' else 'FAIL' end, n;
  select count(*) into n from information_schema.column_privileges
   where table_schema = 'public' and table_name = 'pitfall' and column_name = 'role' and privilege_type = 'UPDATE' and grantee = 'authenticated';
  raise notice '% 24 the column query shows the pitfall (UPDATE on pitfall.role still granted): % grants', case when n = 1 then 'PASS' else 'FAIL' end, n;
end $$;
do $$ declare r record; begin
  for r in select p.proname, p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prosecdef order by 1 loop
    raise notice '% 25 security definer % has search_path: %', case when (r.proconfig is null) = (r.proname = 'unsafe_fn') then 'PASS' else 'FAIL' end, r.proname, coalesce(array_to_string(r.proconfig, ','), 'none');
  end loop;
end $$;
do $$ declare n int; begin
  select count(*) into n from information_schema.routine_privileges where routine_name = 'unsafe_fn' and grantee in ('PUBLIC', 'anon') and privilege_type = 'EXECUTE';
  raise notice '% 26 unsafe_fn executable by PUBLIC or anon: % grants', case when n > 0 then 'PASS' else 'FAIL' end, n;
  select count(*) into n from information_schema.routine_privileges where routine_name = 'my_note_count' and grantee in ('PUBLIC', 'anon') and privilege_type = 'EXECUTE';
  raise notice '% 27 my_note_count executable by PUBLIC or anon: % grants', case when n = 0 then 'PASS' else 'FAIL' end, n;
end $$;
do $$ declare r record; begin
  for r in select c.relname, c.reloptions from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'v' order by 1 loop
    raise notice '% 28 view %: %', case when (coalesce(array_to_string(r.reloptions, ','), '') like '%security_invoker=true%') = (r.relname = 'my_notes') then 'PASS' else 'FAIL' end, r.relname, coalesce(array_to_string(r.reloptions, ','), 'no options');
  end loop;
end $$;
