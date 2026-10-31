// Read-only literal call catalogue, not a substitute for executing each flow.
import {readFile,readdir,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {resolve,relative} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const require=createRequire(new URL('../../supabase/tests/runtime/package.json',import.meta.url));
const {Client}=require('pg');
const [directory,dashboardRoot,report]=process.argv.slice(2);
const mobileRoot=fileURLToPath(new URL('../..',import.meta.url));
const status=JSON.parse(await readFile(resolve(directory,'status.json'),'utf8'));
assert.equal(status.API_URL,'http://127.0.0.1:56821');
const url=new URL(status.DB_URL);assert.equal(url.hostname,'127.0.0.1');assert.equal(url.port,'56822');
async function walk(root){const files=[];for(const entry of await readdir(root,{withFileTypes:true})){const path=resolve(root,entry.name);if(entry.isDirectory())files.push(...await walk(path));else if(entry.name.endsWith('.dart'))files.push(path);}return files;}
const c=new Client({connectionString:status.DB_URL});await c.connect();
try{
 await c.query('BEGIN READ ONLY');
 const functions=(await c.query(`SELECT p.proname name,pg_get_function_identity_arguments(p.oid) signature,
  p.proargnames parameters,has_function_privilege('authenticated',p.oid,'EXECUTE') authenticated_execute
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'`)).rows;
 const tables=(await c.query("SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','v','m','p','f')")).rows.map(r=>r.relname);
 const clients=[];
 for(const [client,root] of [['Mobile',mobileRoot],['Dashboard',resolve(dashboardRoot)]]){
  const calls=[];
  for(const file of await walk(resolve(root,'lib'))){const source=await readFile(file,'utf8');
   for(const match of source.matchAll(/\.(rpc|from)\(\s*['"]([A-Za-z_][A-Za-z_0-9]*)['"]/g)){
    const kind=match[1],name=match[2];const candidates=functions.filter(f=>f.name===name);
    calls.push({file:relative(root,file).replaceAll('\\','/'),kind,name,
     line:source.slice(0,match.index).split('\n').length,
     present:kind==='rpc'?candidates.length>0:tables.includes(name),
     ...(kind==='rpc'?{candidates}:{}),
    });
   }
  }
  clients.push({client,literalCalls:calls.length,missing:calls.filter(c=>!c.present),calls});
 }
 await c.query('COMMIT');
 await writeFile(report,JSON.stringify({environment:status.API_URL,clients,
  limitation:'Literal call/name availability only; dynamic calls, views, payload/response semantics, permissions and complete UI execution require separate verification.'},null,2));
 console.log(JSON.stringify(clients.map(({client,literalCalls,missing})=>({client,literalCalls,missing:missing.length}))));
}finally{await c.end();}
