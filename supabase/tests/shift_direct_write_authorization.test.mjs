import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile,readdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();let passed=0;
const migrations=new URL('../migrations/',import.meta.url);
const file=(await readdir(migrations)).find(p=>p.endsWith('_shift_rpc_write_boundary.sql'));
if(!file)throw Error('shift write migration missing');
try{
 await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;
 CREATE TABLE public.shifts(id integer PRIMARY KEY,cashier_id text,status text,is_approved boolean,expected_cash numeric);
 INSERT INTO public.shifts VALUES(1,'synthetic-cashier','open',false,100);
 ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
 CREATE POLICY shifts_staff_insert_policy ON public.shifts FOR INSERT TO authenticated WITH CHECK(true);
 CREATE POLICY shifts_staff_update_policy ON public.shifts FOR UPDATE TO authenticated USING(true) WITH CHECK(true);
 CREATE POLICY shifts_authenticated_select_scoped ON public.shifts FOR SELECT TO authenticated USING(true);
 GRANT USAGE ON SCHEMA public TO anon,authenticated;GRANT SELECT,INSERT,UPDATE,DELETE ON public.shifts TO anon,authenticated;
 CREATE FUNCTION public.fixture_authorized_close() RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$UPDATE public.shifts SET status='closed' WHERE id=1$$;
 CREATE FUNCTION public.fixture_authorized_approve() RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$UPDATE public.shifts SET is_approved=true WHERE id=1 AND status='closed'$$;`);
 if(!process.env.PLAYSPOT_SHIFT_WRITES_BASELINE)await db.exec(await readFile(new URL(file,migrations),'utf8'));
 await db.exec('SET ROLE authenticated');
 for(const [name,sql] of [
  ['forged approval','UPDATE public.shifts SET is_approved=true WHERE id=1'],
  ['forged expected cash','UPDATE public.shifts SET expected_cash=0 WHERE id=1'],
  ['foreign cashier insertion',"INSERT INTO public.shifts VALUES(2,'other-actor','closed',true,0)"],
  ['direct financial deletion','DELETE FROM public.shifts WHERE id=1']]){
   await assert.rejects(db.query(sql),e=>e.code==='42501');passed++;console.log('PASS '+name+' denied');
 }
 assert.equal((await db.query('SELECT * FROM public.shifts')).rows.length,1);passed++;console.log('PASS existing shift read contract retained');
 await db.exec('SELECT public.fixture_authorized_close();SELECT public.fixture_authorized_approve()');
 const row=(await db.query('SELECT * FROM public.shifts')).rows[0];assert.equal(row.status,'closed');assert.equal(row.is_approved,true);assert.equal(row.expected_cash,'100');passed++;console.log('PASS authorized SECURITY DEFINER transitions retain owner write ability');
 for(const role of ['anon','authenticated']){
  await db.exec('RESET ROLE');for(const privilege of ['INSERT','UPDATE','DELETE'])assert.equal((await db.query("SELECT has_table_privilege($1,'public.shifts',$2) allowed",[role,privilege])).rows[0].allowed,false);
  passed++;console.log('PASS '+role+' lacks direct write grants');
 }
 console.log(JSON.stringify({passed,limitations:['Synthetic privilege test; operational RPC authorization is covered separately, not by fixture functions']}));
}finally{await db.close();}
