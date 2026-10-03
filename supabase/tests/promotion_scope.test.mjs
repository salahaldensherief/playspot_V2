import {createFixtureDatabase} from './runtime/database.mjs';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const db=await createFixtureDatabase();
const admin='00000000-0000-0000-0000-000000000001';
const owner='00000000-0000-0000-0000-000000000002';
const lounge='10000000-0000-0000-0000-000000000001';
const globalPromo='20000000-0000-0000-0000-000000000001';
const localPromo='20000000-0000-0000-0000-000000000002';
let passed=0;
try {
 await db.exec(`CREATE ROLE authenticated; CREATE ROLE anon; CREATE SCHEMA auth; CREATE SCHEMA private;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('test.actor',true),'')::uuid$$;
 CREATE TABLE auth.users(id uuid primary key);
 CREATE TABLE public.profiles(id uuid primary key,role text,is_active boolean,is_banned boolean);
 CREATE TABLE public.platform_super_admins(user_id uuid primary key);
 CREATE TABLE public.rooms(id uuid primary key,lounge_id uuid);
 CREATE TABLE public.promotions(id uuid primary key default gen_random_uuid(),lounge_id uuid,room_id uuid,title text,title_ar text,title_en text,
 tag text,tag_ar text,tag_en text,colors text[],icon_key text,image_url text,deep_link text,expires_at timestamptz,
 is_room_specific boolean,target_audience text,discount_type text,discount_value numeric,is_active boolean);
 CREATE FUNCTION public.has_lounge_permission(uuid,text) RETURNS boolean LANGUAGE sql AS $$SELECT auth.uid()='${owner}'::uuid AND $1='${lounge}'::uuid$$;
 INSERT INTO auth.users VALUES('${admin}'),('${owner}');
 INSERT INTO public.profiles VALUES('${admin}','user',true,false),('${owner}','owner',true,false);
 INSERT INTO public.platform_super_admins VALUES('${admin}');
 INSERT INTO public.promotions(id,lounge_id) VALUES('${globalPromo}',NULL),('${localPromo}','${lounge}');
 GRANT USAGE ON SCHEMA auth,public TO authenticated,anon;
 `);
 await db.exec(await readFile(new URL('../repairs/active_super_admin_boundary.sql',import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../migrations/20261003111319_promotion_delete_scope.sql',import.meta.url),'utf8'));
 async function actor(id){await db.exec(`RESET ROLE; SET test.actor='${id}'; SET ROLE authenticated;`);}
 async function deny(name,sql,code){await assert.rejects(db.query(sql),e=>e.code===code);passed++;console.log('PASS '+name);}
 const remove=id=>`SELECT public.delete_promotion('${id}') AS result`;
 const create=(venue='NULL')=>`SELECT public.create_promotion(${venue},NULL,'عرض','Offer','','','percentage',10,NULL,ARRAY['#000000','#ffffff'],'local_offer') AS result`;
 const update=id=>`SELECT public.update_promotion('${id}',NULL,'معدل','Updated','','','percentage',20,NULL,ARRAY['#000000','#ffffff'],'local_offer') AS result`;
 await actor(owner);await deny('owner cannot delete global promotion',remove(globalPromo),'42501');
 await deny('owner cannot create global promotion',create(),'42501');
 await deny('owner cannot edit global promotion',update(globalPromo),'42501');
 assert.equal((await db.query(remove(localPromo))).rows[0].result.success,true);passed++;
 await actor(admin);
 assert.equal((await db.query(update(globalPromo))).rows[0].result.success,true);passed++;
 assert.equal((await db.query(remove(globalPromo))).rows[0].result.success,true);passed++;
 await deny('missing promotion uses actual not found error',remove(globalPromo),'P0002');
 const created=(await db.query(create())).rows[0].result;assert.equal(created.success,true);passed++;
 await db.exec(`RESET ROLE; UPDATE public.profiles SET is_banned=true WHERE id='${admin}'; SET ROLE authenticated;`);
 await deny('banned administrator cannot delete',remove(created.promo_id),'42501');
 await deny('banned administrator cannot create',create(),'42501');
 await db.exec(`RESET ROLE; UPDATE public.profiles SET is_banned=false,is_active=false WHERE id='${admin}'; SET ROLE authenticated;`);
 await deny('disabled administrator cannot edit',update(created.promo_id),'42501');
 console.log(JSON.stringify({passed,liveMutations:false,fixtureSchema:true}));
} finally {await db.close();}
