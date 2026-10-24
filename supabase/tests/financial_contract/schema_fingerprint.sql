-- Read-only schema inventory. Run with psql -XAt -v ON_ERROR_STOP=1 -f.
-- This never selects application rows. It is a comparison gate, not a schema dump.
WITH schema_names AS (
  SELECT oid, nspname, nspacl FROM pg_namespace WHERE nspname IN ('public', 'private')
), objects AS (
  SELECT 'schema/' || nspname AS key,
    md5(jsonb_build_object('acl', COALESCE((SELECT jsonb_agg(x::text ORDER BY x::text) FROM unnest(nspacl) x), '[]'::jsonb))::text) AS hash
  FROM schema_names

  UNION ALL
  SELECT 'relation/' || n.nspname || '/' || c.relname,
    md5(jsonb_build_object('kind', c.relkind, 'rls', c.relrowsecurity, 'force_rls', c.relforcerowsecurity,
      'acl', COALESCE((SELECT jsonb_agg(x::text ORDER BY x::text) FROM unnest(c.relacl) x), '[]'::jsonb),
      'view', CASE WHEN c.relkind IN ('v', 'm') THEN pg_get_viewdef(c.oid, true) ELSE NULL END)::text)
  FROM pg_class c JOIN schema_names n ON n.oid = c.relnamespace
  WHERE c.relkind IN ('r', 'p', 'v', 'm', 'S')

  UNION ALL
  SELECT 'column/' || n.nspname || '/' || c.relname || '/' || a.attname,
    md5(jsonb_build_object('type', format_type(a.atttypid, a.atttypmod), 'not_null', a.attnotnull,
      'identity', a.attidentity, 'generated', a.attgenerated, 'collation', a.attcollation::regcollation::text,
      'default', pg_get_expr(d.adbin, d.adrelid),
      'acl', COALESCE((SELECT jsonb_agg(x::text ORDER BY x::text) FROM unnest(a.attacl) x), '[]'::jsonb))::text)
  FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
    JOIN schema_names n ON n.oid = c.relnamespace
    LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
  WHERE a.attnum > 0 AND NOT a.attisdropped AND c.relkind IN ('r', 'p', 'v', 'm')

  UNION ALL
  SELECT 'constraint/' || n.nspname || '/' || c.relname || '/' || x.conname,
    md5(jsonb_build_object('definition', pg_get_constraintdef(x.oid, true), 'validated', x.convalidated,
      'deferrable', x.condeferrable, 'deferred', x.condeferred)::text)
  FROM pg_constraint x JOIN pg_class c ON c.oid = x.conrelid JOIN schema_names n ON n.oid = c.relnamespace

  UNION ALL
  SELECT 'index/' || n.nspname || '/' || i.relname,
    md5(jsonb_build_object('definition', pg_get_indexdef(i.oid), 'valid', x.indisvalid, 'ready', x.indisready)::text)
  FROM pg_index x JOIN pg_class i ON i.oid = x.indexrelid
    JOIN pg_class c ON c.oid = x.indrelid JOIN schema_names n ON n.oid = c.relnamespace

  UNION ALL
  SELECT 'trigger/' || n.nspname || '/' || c.relname || '/' || t.tgname,
    md5(jsonb_build_object('definition', pg_get_triggerdef(t.oid, true), 'enabled', t.tgenabled)::text)
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid JOIN schema_names n ON n.oid = c.relnamespace
  WHERE NOT t.tgisinternal

  UNION ALL
  SELECT 'policy/' || n.nspname || '/' || c.relname || '/' || p.polname,
    md5(jsonb_build_object('command', p.polcmd, 'permissive', p.polpermissive,
      'roles', (SELECT jsonb_agg(r.rolname ORDER BY r.rolname) FROM pg_roles r WHERE r.oid = ANY(p.polroles)),
      'using', pg_get_expr(p.polqual, p.polrelid), 'check', pg_get_expr(p.polwithcheck, p.polrelid))::text)
  FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid JOIN schema_names n ON n.oid = c.relnamespace

  UNION ALL
  SELECT 'function/' || n.nspname || '/' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
    md5(jsonb_build_object('definition', pg_get_functiondef(p.oid),
      'acl', COALESCE((SELECT jsonb_agg(x::text ORDER BY x::text) FROM unnest(p.proacl) x), '[]'::jsonb))::text)
  FROM pg_proc p JOIN schema_names n ON n.oid = p.pronamespace
  WHERE p.prokind IN ('f', 'p')

  UNION ALL
  SELECT 'type/' || n.nspname || '/' || t.typname,
    md5(jsonb_build_object('kind', t.typtype, 'definition', format_type(t.oid, NULL),
      'enum', (SELECT jsonb_agg(e.enumlabel ORDER BY e.enumsortorder) FROM pg_enum e WHERE e.enumtypid = t.oid),
      'domain_base', CASE WHEN t.typtype = 'd' THEN format_type(t.typbasetype, t.typtypmod) ELSE NULL END,
      'domain_default', t.typdefault, 'domain_not_null', t.typnotnull,
      'domain_constraints', (SELECT jsonb_agg(jsonb_build_object('name', c.conname,
        'definition', pg_get_constraintdef(c.oid, true), 'validated', c.convalidated) ORDER BY c.conname)
        FROM pg_constraint c WHERE c.contypid = t.oid),
      'acl', COALESCE((SELECT jsonb_agg(x::text ORDER BY x::text) FROM unnest(t.typacl) x), '[]'::jsonb))::text)
  FROM pg_type t JOIN schema_names n ON n.oid = t.typnamespace
  WHERE t.typtype IN ('e', 'd')

  UNION ALL
  SELECT 'extension/' || e.extname,
    md5(jsonb_build_object('version', e.extversion, 'schema', n.nspname)::text)
  FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
)
SELECT jsonb_build_object('format', 1,
  'server_major', current_setting('server_version_num')::integer / 10000,
  'objects', (SELECT jsonb_object_agg(key, hash ORDER BY key) FROM objects))::text;
