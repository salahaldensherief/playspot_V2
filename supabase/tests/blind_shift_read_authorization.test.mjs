import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile,readdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await createFixtureDatabase();let passed=0;
const actor='11111111-1111-1111-1111-111111111111',manager='22222222-2222-2222-2222-222222222222',lounge='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',other='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',shift='cccccccc-cccc-cccc-cccc-cccccccccccc';
const migrations=new URL('../migrations/',import.meta.url);
try {
 await db.exec(await readFile(new URL('fixtures/shift_close_authorization_fixture.sql',import.meta.url),'utf8'));
 await db.exec(`ALTER TABLE public.profiles ADD COLUMN full_name text;
 CREATE TABLE public.lounges(id uuid PRIMARY KEY,name text,name_en text,name_ar text,is_active boolean DEFAULT true);
 CREATE TABLE public.bookings(id uuid,shift_id uuid);
 ALTER TABLE public.shifts ADD COLUMN start_time timestamptz DEFAULT now(),ADD COLUMN is_approved boolean DEFAULT false,ADD COLUMN approved_by uuid,ADD COLUMN approved_at timestamptz,ADD COLUMN manager_notes text,ADD COLUMN total_cash_drops numeric;
 CREATE FUNCTION public._playspot_has_lounge_access(l uuid) RETURNS boolean LANGUAGE sql SECURITY DEFINER AS $$SELECT private.can_operate_playspot_lounge(l)$$;
 CREATE FUNCTION private.current_user_role() RETURNS text LANGUAGE sql AS $$SELECT role FROM public.profiles WHERE id=auth.uid()$$;
 CREATE FUNCTION private.is_lounge_member(l uuid) RETURNS boolean LANGUAGE sql AS $$SELECT private.can_operate_playspot_lounge(l)$$;
 CREATE FUNCTION public.is_lounge_member_or_admin(l uuid) RETURNS boolean LANGUAGE sql AS $$SELECT private.can_operate_playspot_lounge(l)$$;
 CREATE OR REPLACE FUNCTION public.has_lounge_permission(lounge uuid,key text) RETURNS boolean LANGUAGE sql AS $$SELECT private.can_operate_playspot_lounge(lounge) AND (key='shifts_blind_close' OR (key='shifts_view_blind_cash' AND private.can_manage_playspot_lounge(lounge)))$$;
 INSERT INTO public.profiles(id,role,lounge_id) VALUES('${actor}','cashier','${lounge}'),('${manager}','owner','${lounge}');
 INSERT INTO public.lounges(id,name) VALUES('${lounge}','Synthetic'),('${other}','Other');
 INSERT INTO public.shifts(id,lounge_id,cashier_id,staff_user_id,starting_cash,expected_cash,actual_cash_counted,difference,total_cash_sales,total_digital_sales,total_expenses) VALUES('${shift}','${lounge}','${actor}','${actor}',100,140,130,-10,50,20,10);
 INSERT INTO public.shift_payments VALUES('${shift}','cash',50);
 INSERT INTO public.shift_expenses VALUES('${shift}','expense',10);
 ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
 CREATE POLICY fixture_scope ON public.shifts FOR SELECT TO authenticated USING(public._playspot_has_lounge_access(lounge_id));
 ALTER TABLE public.shift_audit_logs ENABLE ROW LEVEL SECURITY;
 CREATE POLICY fixture_audit_scope ON public.shift_audit_logs FOR SELECT TO authenticated USING(public._playspot_has_lounge_access(lounge_id));
 GRANT USAGE ON SCHEMA public,auth,private TO authenticated,anon;
 GRANT SELECT ON public.shifts,public.shift_audit_logs TO authenticated,anon;
 `);
 await db.exec(await readFile(new URL('fixtures/blind_shift_read_deployed_definitions.sql',import.meta.url),'utf8'));
 const migration=(await readdir(migrations)).find(x=>x.endsWith('_blind_shift_read_boundary.sql'));
 if (!process.env.PLAYSPOT_BLIND_BASELINE) await db.exec(await readFile(new URL(migration,migrations),'utf8'));
 await db.exec(`SET test.actor='${actor}';SET ROLE authenticated;`);
 await assert.rejects(db.query('SELECT expected_cash FROM public.shifts'),e=>e.code==='42501');passed++;console.log('PASS direct expected-cash projection denied');
 await assert.rejects(db.query('SELECT * FROM public.shifts'),e=>e.code==='42501');passed++;
 assert.equal((await db.query('SELECT id,status FROM public.shifts')).rows.length,1);passed++;
 const get=async()=> (await db.query('SELECT public.get_visible_shifts($1) data',[lounge])).rows[0].data;
 let data=await get();for(const k of ['starting_cash','expected_cash','difference','total_cash_sales','total_expenses'])assert.equal(data[k],null);
 assert.equal(data.financials_visible,false);assert.equal(data.actual_cash_counted,130);passed++;console.log('PASS cashier receives explicit masked values and own count');
 await assert.rejects(db.query('SELECT public.get_visible_shifts($1)',[other]),e=>e.code==='42501');passed++;
 await assert.rejects(db.query('SELECT public.get_visible_shifts($1,NULL,false,201)',[lounge]),e=>e.code==='22023');passed++;
 for(const rpc of ['get_shift_report','get_cashier_performance']) {await assert.rejects(db.query('SELECT * FROM public.'+rpc+'($1)',[lounge]),e=>e.code==='42501');passed++;}
 await assert.rejects(db.query('SELECT public.close_shift($1,130)',[shift]),e=>e.code==='42501');passed++;
 await assert.rejects(db.query('SELECT public.close_shift_and_calculate_z_report($1,130)',[shift]),e=>e.code==='42501');passed++;
 assert.equal((await db.query('SELECT status FROM public.shifts')).rows[0].status,'open');passed++;
 for(const rpc of ['get_current_shift','get_lounge_live_shift_overview']){const d=(await db.query('SELECT public.'+rpc+'($1) data',[lounge])).rows[0].data;assert.equal(d.financials_visible,false);assert.equal(d.expected_cash,null);assert.equal(d.current_cash_sales,null);passed++;}
 const opened=(await db.query('SELECT (public.open_lounge_shift($1)).expected_cash masked',[lounge])).rows[0];assert.equal(opened.masked,null);passed++;
 const closed=(await db.query('SELECT public.blind_close_shift($1,$2,130,NULL) data',[shift,actor])).rows[0].data;assert.equal(closed.expected_cash,null);assert.equal(closed.difference,null);assert.equal(closed.financials_visible,false);passed++;
 assert.equal((await db.query('SELECT * FROM public.shift_audit_logs')).rows.length,0);passed++;console.log('PASS blind closure persists without audit read leakage');
 await db.exec(`RESET ROLE;SET test.actor='${manager}';SET ROLE authenticated;`);
 data=await get();assert.equal(data.expected_cash,140);assert.equal(data.difference,-10);assert.equal(data.financials_visible,true);passed++;
 await assert.rejects(db.query('SELECT * FROM public.get_lounge_comparison()'),e=>e.code==='42501');passed++;
 await db.exec(`RESET ROLE;UPDATE public.profiles SET is_banned=true WHERE id='${manager}';SET ROLE authenticated;`);
 await assert.rejects(get(),e=>e.code==='42501');passed++;
 await db.exec(`RESET ROLE;UPDATE public.profiles SET is_active=false WHERE id='${actor}';SET test.actor='${actor}';SET ROLE authenticated;`);
 await assert.rejects(get(),e=>e.code==='42501');passed++;
 console.log(JSON.stringify({passed,liveSupabase:false}));
}finally{await db.close();}

