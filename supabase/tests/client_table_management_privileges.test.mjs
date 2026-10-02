import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const db=await createFixtureDatabase();let passed=0;
const privileges=['TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'];
async function check(name,body) {await body();passed++;console.log('PASS '+name);}
try {
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
 CREATE SCHEMA fixture_private;
 CREATE TABLE public.fixture_records(id int PRIMARY KEY);
 CREATE TABLE public.fixture_permissions(id int PRIMARY KEY);
 INSERT INTO public.fixture_records VALUES(1);INSERT INTO public.fixture_permissions VALUES(2);
 GRANT ALL ON public.fixture_records,public.fixture_permissions TO anon,authenticated,service_role;
 GRANT USAGE ON SCHEMA public TO anon,authenticated;
 ALTER TABLE public.fixture_records ENABLE ROW LEVEL SECURITY;
 CREATE POLICY fixture_scoped_dml ON public.fixture_records FOR ALL USING(id>=100) WITH CHECK(id>=100);
 ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO anon,authenticated,service_role;
 ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon,authenticated,service_role;`);
 await check('fixture reproduces broad truncate grant despite RLS',async()=>{
  assert.equal((await db.query("SELECT has_table_privilege('anon','public.fixture_records','TRUNCATE') AS allowed")).rows[0].allowed,true);
 });
 await db.exec(await readFile(new URL('../repairs/client_table_management_privileges.sql',import.meta.url),'utf8'));
 await db.exec(`CREATE TABLE public.fixture_future(id int);
 CREATE TABLE fixture_private.fixture_future(id int);`);
 const tables=['public.fixture_records','public.fixture_permissions','public.fixture_future','fixture_private.fixture_future'];
 for(const role of ['anon','authenticated']) {
  for(const table of tables) for(const privilege of privileges) await check(`${role} lacks ${privilege} on ${table}`,async()=>{
   assert.equal((await db.query('SELECT has_table_privilege($1,$2,$3) AS allowed',[role,table,privilege])).rows[0].allowed,false);
  });
  await db.exec(`SET ROLE ${role};`);
  for(const table of tables.filter(t=>t.startsWith('public.'))) await check(`${role} actual truncate denied on ${table}`,async()=>{
   await assert.rejects(db.query(`TRUNCATE ${table}`),e=>e.code==='42501');
  });
  await db.exec('RESET ROLE');
 }
 await check('existing data remains intact',async()=>{
  assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.fixture_records')).rows[0].n),1);
  assert.equal(Number((await db.query('SELECT count(*) AS n FROM public.fixture_permissions')).rows[0].n),1);
 });
 await check('trusted service-role maintenance privileges retained',async()=>{
  for(const privilege of privileges) assert.equal((await db.query('SELECT has_table_privilege($1,$2,$3) AS allowed',
   ['service_role','public.fixture_records',privilege])).rows[0].allowed,true);
 });
 await check('authenticated scoped SELECT INSERT UPDATE DELETE still work',async()=>{
  await db.exec('SET ROLE authenticated;INSERT INTO public.fixture_records VALUES(100);UPDATE public.fixture_records SET id=101 WHERE id=100;');
  assert.deepEqual((await db.query('SELECT id FROM public.fixture_records')).rows,[{id:101}]);
  await db.exec('DELETE FROM public.fixture_records WHERE id=101;RESET ROLE;');
 });
 await check('future ordinary DML grants retained',async()=>{
  for(const privilege of ['SELECT','INSERT','UPDATE','DELETE']) assert.equal((await db.query('SELECT has_table_privilege($1,$2,$3) AS allowed',
   ['authenticated','public.fixture_future',privilege])).rows[0].allowed,true);
 });
 console.log(JSON.stringify({passed,limitations:['PostgreSQL 17 MAINTAIN privilege','Only current executor default privileges are changed','Other owner defaults and inherited grants require deployment audit','No production write or destructive live probe']}));
} finally {await db.close();}
