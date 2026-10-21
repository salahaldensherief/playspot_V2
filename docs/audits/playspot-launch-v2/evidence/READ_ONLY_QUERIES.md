# Catalog capture method

Captured on 21 October 2026 through the connected Supabase MCP using SELECT only on the production and demo catalogs. No business rows or vault values were read. Function definitions were parsed as untrusted source, never executed against the hosted projects.

Representative exact discovery queries:

```sql
select n.nspname schema,p.proname name,
 pg_get_function_identity_arguments(p.oid) identity_args,
 pg_get_function_arguments(p.oid) args,pg_get_function_result(p.oid) result,
 p.prosecdef security_definer,p.proconfig config,p.proacl::text acl,
 pg_get_functiondef(p.oid) definition
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prokind='f';

select schemaname,tablename,policyname,roles,cmd,qual,with_check
from pg_policies where schemaname in ('public','storage');

select c.relname table_name,k.conname,pg_get_constraintdef(k.oid) definition,
 k.convalidated
from pg_constraint k join pg_class c on c.oid=k.conrelid
join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','private')
and (c.relname ~ 'booking|payment|shift|cash|order|room|review|permission'
 or k.contype='x');

select p.proname name,pg_get_function_arguments(p.oid) args,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute,
 p.proconfig config
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef
and not exists(select 1 from pg_depend d where d.objid=p.oid and d.deptype='e');

select c.relname name,c.reloptions,
 has_table_privilege('anon',c.oid,'SELECT') anon_select,
 has_table_privilege('authenticated',c.oid,'SELECT') authenticated_select,
 pg_get_viewdef(c.oid,true) definition
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='v';
```

Also captured table column/type/ACL metadata, relevant triggers and column grants, bucket privacy/type/size metadata, migration ledger, security advisors, deployed Edge version list and the deployed announcement source. No RPC from these definitions was invoked on hosted infrastructure. Catalog presence does not verify PostgREST exposure, response correctness or authorized user execution.

Test cluster: freshly initialized PostgreSQL 17.11 under this task's work/audit-pgdata, bound to 127.0.0.1:55439. Each native suite used its own random synthetic database. Before shutdown, a catalog query returned no remaining playspot_fixture_% databases; pg_ctl stop completed successfully. No other PostgreSQL cluster was stopped or changed.
