// Only the explicitly selected new disposable loopback project is accepted.
import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const require=createRequire(new URL('../../supabase/tests/runtime/package.json',import.meta.url));
const {Client}=require('pg');
const [directory,report]=process.argv.slice(2);
const status=JSON.parse(await readFile(resolve(directory,'status.json'),'utf8'));
assert.equal(status.API_URL,'http://127.0.0.1:56821');
const url=new URL(status.DB_URL);assert.equal(url.hostname,'127.0.0.1');assert.equal(url.port,'56822');
const manifest=JSON.parse(await readFile(new URL('manifest.json',import.meta.url),'utf8'));
const hash=s=>createHash('sha256').update(s).digest('hex');
const normalized=async path=>(await readFile(path,'utf8')).replaceAll('\r\n','\n');
const baseline=await normalized(new URL(manifest.baseline.file,import.meta.url));
assert.equal(hash(baseline),manifest.baseline.normalizedSha256);
const stages=[{name:'managed',sql:await normalized(new URL('bootstrap-managed.sql',import.meta.url))},
 {name:'app-checkpoint',sql:baseline},
 {name:'local-marker',sql:await normalized(new URL('bootstrap-local-marker.sql',import.meta.url))}];
for(const m of manifest.migrations){
 const sql=await normalized(new URL('../../supabase/migrations/'+m.file,import.meta.url));
 assert.equal(hash(sql),m.normalizedSha256);stages.push({name:m.file,sql});
}
stages.push({name:'local-auth-bindings',sql:await normalized(new URL('bootstrap-auth.sql',import.meta.url))});
const c=new Client({connectionString:status.DB_URL,statement_timeout:120000});
await c.connect();const passed=[];
try {
 const fresh=(await c.query("SELECT to_regclass('public.profiles') IS NULL AS empty, (SELECT count(*) FROM auth.users)=0 AS no_users")).rows[0];
 assert.equal(fresh.empty,true,'Existing application preserved; never replay/reset');assert.equal(fresh.no_users,true);
 for(const stage of stages){
  await c.query('BEGIN');
  try{await c.query(stage.sql);await c.query('COMMIT');passed.push({stage:stage.name,sha256:hash(stage.sql)});console.log('Applied local stage: '+stage.name);}
  catch(error){await c.query('ROLLBACK');throw Object.assign(error,{stage:stage.name});}
 }
 const objects=(await c.query(`SELECT
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','private') AND c.relkind='r') tables,
   (SELECT count(*) FROM pg_policies WHERE schemaname IN ('public','private')) policies,
   (SELECT count(*) FROM cron.job WHERE active) active_jobs,
   to_regprocedure('private.log_audit_event(uuid,text,text,text,uuid,uuid,text,jsonb,timestamptz)') IS NOT NULL audit_logger`)).rows[0];
 assert.equal(Number(objects.active_jobs),0);assert.equal(objects.audit_logger,true);
 await writeFile(report,JSON.stringify({environment:status.API_URL,baseline:manifest.baseline,stages:passed,objects,
   result:'Fresh managed Auth/database plus versioned app checkpoint and dependency-ordered reviewed deltas applied',
   limitation:'No claim that all historical migrations replay from empty or any hosted database was changed'},null,2));
} catch(error){
 await writeFile(report,JSON.stringify({environment:status.API_URL,passed,failedStage:error.stage,code:error.code,message:error.message,result:'FAILED; fresh database retained for diagnosis; no reset'},null,2));
 console.error('Fresh local bootstrap failed at '+error.stage+': '+error.message);process.exitCode=1;
} finally{await c.end();}
