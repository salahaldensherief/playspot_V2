-- Read-only effective catalog inventory for the NEW disposable environment.
-- Run through the verified dedicated daemon/container, never a database URL.
SELECT jsonb_build_object(
 'database',current_database(), 'version',current_setting('server_version'),
 'extensions',(SELECT jsonb_agg(jsonb_build_object('name',extname,'version',extversion)) FROM pg_extension),
 'roles',(SELECT jsonb_agg(rolname) FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','supabase_auth_admin')),
 'functions',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,
   'arguments',pg_get_function_identity_arguments(p.oid),'result',pg_get_function_result(p.oid),
   'definer',p.prosecdef,'config',p.proconfig,'acl',p.proacl::text,'definition_hash',md5(pg_get_functiondef(p.oid))))
   FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname IN ('public','private') AND p.prokind='f'),
 'tables',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,'acl',c.relacl::text))
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','private') AND c.relkind IN ('r','p')),
 'triggers',(SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'name',t.tgname,'enabled',t.tgenabled,'definition_hash',md5(pg_get_triggerdef(t.oid))))
   FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND n.nspname IN ('public','private','auth')),
 'policies',(SELECT jsonb_agg(jsonb_build_object('schema',schemaname,'table',tablename,'name',policyname,'roles',roles,'command',cmd,'qual_hash',md5(coalesce(qual,'')),'check_hash',md5(coalesce(with_check,''))))
   FROM pg_policies WHERE schemaname IN ('public','private','auth'))
);
