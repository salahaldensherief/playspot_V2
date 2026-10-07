import {createFixtureDatabase} from './runtime/database.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = await createFixtureDatabase();
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const lounge = id(1), room = id(2), roomB = id(3), user = id(4), hold = id(5), extra = id(6), combo = id(7), rule = id(8);
let passed = 0;
async function source(file, name) {
  const sql = await readFile(new URL('../migrations/'+file, import.meta.url), 'utf8');
  const start = sql.indexOf('CREATE OR REPLACE FUNCTION '+name+'(');
  assert.ok(start >= 0, 'Missing canonical function '+name);
  const tail = sql.slice(start), delimiter = tail.match(/AS (\$[a-z_]*\$)/i)[1];
  return tail.slice(0, tail.indexOf(delimiter+';', tail.indexOf(delimiter)+delimiter.length)+delimiter.length+1);
}
async function check(name, body) {
  await db.exec('BEGIN');
  try {await body(); passed++; console.log('PASS '+name);} finally {await db.exec('ROLLBACK');}
}
async function scalar(sql, params = []) {return (await db.query(sql, params)).rows[0].r;}
async function seedHold(rooms = [room], start = '2026-10-12 18:00', end = '2026-10-12 20:00') {
  for (const r of rooms) await db.query(`INSERT INTO booking_holds(hold_token,user_id,lounge_id,room_id,start_at,end_at,expires_at)
    VALUES($1,$2,$3,$4,$5,$6,now()+interval '10 minutes')`, [hold,user,lounge,r,start,end]);
}
async function checkout(rooms = [{room_id:room}], extras = [], voucher = null) {
  return scalar('SELECT public.create_my_booking_checkout($1,$2::jsonb,$3::jsonb,$4) r', [hold,JSON.stringify(rooms),JSON.stringify(extras),voucher]);
}
async function voucher(value, type = 'discount_fixed') {
  await db.query(`INSERT INTO user_vouchers(user_id,code,reward_type,reward_value,expires_at)
    VALUES($1,'TEST',$2,$3,now()+interval '1 day')`, [user,type,value]);
}
async function price(start, end, date = '2026-10-12', mode = 'single') {
  return scalar('SELECT private.price_room_interval($1,$2,$3,$4,$5) r',[room,date,start,end,mode]);
}
async function order(booking, lines) {
  return scalar('SELECT public.place_canteen_order($1,$2::jsonb) r',[booking,JSON.stringify(lines)]);
}
async function booking() {await seedHold(); return (await checkout()).primary_booking_id;}
async function pricingRule(patch = {}) {
  const p = {lounge_id:lounge,room_id:room,name_ar:'Fixture',name_en:'Fixture',days_of_week:[1],start_time:'18:00',end_time:'20:00',adjustment_value:1.5,priority:100,...patch};
  await db.query('INSERT INTO pricing_rules SELECT (jsonb_populate_record(NULL::pricing_rules,$1::jsonb)).*',
    [JSON.stringify({id:id(20),rule_type:'peak',adjustment_type:'multiplier',is_active:true,created_at:new Date().toISOString(),updated_at:new Date().toISOString(),...p})]);
}

try {
  await db.exec(await readFile(new URL('./runtime/checkout_canteen_schema.sql', import.meta.url),'utf8'));
  // Run production function bodies, never a reimplementation of the pricing rule.
  for (const [file,name] of [
    ['20261007000015_pricing_engine_contract_v2.sql','private.price_room_interval'],
    ['20261007000016_checkout_pricing_rule_integration.sql','private.build_my_booking_checkout_quote'],
    ['20260927000011_server_authoritative_booking_checkout.sql','public.quote_my_booking_checkout'],
  ]) await db.exec(await source(file,name));
  for (const file of ['20261007103018_checkout_voucher_allocation_and_price_stability.sql','20261007103019_canteen_combo_order_integrity.sql','20261007103029_pricing_weekly_conflict_integrity.sql'])
    await db.exec(await readFile(new URL('../migrations/'+file,import.meta.url),'utf8'));
  await db.exec(`CREATE TRIGGER clamp BEFORE INSERT OR UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION fn_validate_and_clamp_booking_price();
    CREATE TRIGGER normalize BEFORE INSERT OR UPDATE OF items ON canteen_orders FOR EACH ROW EXECUTE FUNCTION normalize_canteen_order_items();
    ALTER TABLE canteen_order_items ADD FOREIGN KEY(order_id) REFERENCES canteen_orders(id);
    ALTER TABLE canteen_order_items ADD FOREIGN KEY(extra_id) REFERENCES extras(id);
    ALTER TABLE booking_items ADD FOREIGN KEY(extra_id) REFERENCES extras(id);
    INSERT INTO lounges(id,name,status) VALUES('${lounge}','Fixture','active');
    INSERT INTO rooms(id,lounge_id,name,hourly_rate_single,hourly_rate_multi,extra_controller_price)
      VALUES('${room}','${lounge}','Room A',80,120,10),('${roomB}','${lounge}','Room B',70,110,10);
    INSERT INTO profiles(id,role) VALUES('${user}','user');
    INSERT INTO extras(id,lounge_id,name,name_ar,name_en,price,category,stock_quantity)
      VALUES('${extra}','${lounge}','Drink','Drink','Drink',40,'drink',20);
    INSERT INTO canteen_combos(id,lounge_id,name_ar,name_en,price) VALUES('${combo}','${lounge}','Combo','Combo',60);
    INSERT INTO canteen_combo_items VALUES('${combo}','${extra}',2);
    SET request.jwt.claim.sub='${user}';`);

  await check('fixed voucher spans both rooms without losing the excess',async () => {
    await seedHold([room,roomB]); await voucher(200);
    const r = await checkout([{room_id:room},{room_id:roomB}],[],'TEST');
    assert.equal(r.quote.final_total,100);
    assert.equal(Number(await scalar('SELECT sum(total_price) r FROM bookings')),100);
    assert.equal(await scalar("SELECT status r FROM user_vouchers WHERE code='TEST'"),'used');
    assert.equal(Number(await scalar('SELECT count(*) r FROM booking_holds WHERE released_at IS NULL')),0);
  });
  await check('fixed voucher can cover extras after covering the room',async () => {
    await seedHold(); await voucher(180);
    const r=await checkout([{room_id:room}],[{extra_id:extra,quantity:1}],'TEST');
    assert.equal(r.quote.final_total,20);
    assert.equal(Number(await scalar('SELECT sum(total_price) r FROM bookings')),20);
    assert.equal(Number(await scalar('SELECT stock_quantity r FROM extras')),19);
  });
  await check('promotion, multi mode, controllers and free-hour voucher agree with stored total',async () => {
    await pricingRule(); await seedHold(); await voucher(1,'free_hour');
    await db.query(`INSERT INTO promotions(title,room_id,lounge_id,discount_type,discount_value) VALUES('Fixture',$1,$2,'percentage',20)`,[room,lounge]);
    const r=await checkout([{room_id:room,play_mode:'multi',extra_controllers:2}],[],'TEST');
    assert.equal(r.quote.original_rooms_total,400);
    assert.equal(r.quote.promo_discount_total,72);
    assert.equal(r.quote.voucher_discount,144);
    assert.equal(r.quote.final_total,184);
    assert.equal(Number(await scalar('SELECT sum(total_price) r FROM bookings')),184);
  });
  await check('overnight rule applies to its starting day and date range',async () => {
    await pricingRule({start_time:'22:00',end_time:'02:00',start_date:'2026-10-12',end_date:'2026-10-12'});
    assert.equal((await price('21:00','03:00')).room_subtotal,640);
    assert.equal((await price('00:00','03:00','2026-10-13')).room_subtotal,320);
    assert.equal((await price('00:00','03:00','2026-10-14')).room_subtotal,240);
  });
  await check('scope specificity wins a priority tie; higher priority wins otherwise',async () => {
    await pricingRule({room_id:null});
    await pricingRule({id:id(21),adjustment_value:2});
    assert.equal((await price('18:00','20:00')).room_subtotal,320);
    await db.query('UPDATE pricing_rules SET priority=101 WHERE room_id IS NULL');
    assert.equal((await price('18:00','20:00')).room_subtotal,240);
  });
  await check('tariff changes do not reprice payment, status or canteen updates',async () => {
    const b=await booking(); await pricingRule({adjustment_value:2});
    await db.query("UPDATE bookings SET status='upcoming',payment_status='paid' WHERE id=$1",[b]);
    assert.equal(Number(await scalar('SELECT room_price r FROM bookings')),160);
    await order(b,[{extra_id:extra,quantity:1}]);
    assert.equal(Number(await scalar('SELECT total_price r FROM bookings')),200);
    assert.ok(await scalar("SELECT pricing_snapshot->>'room_subtotal' r FROM bookings"));
  });
  await check('occupied room can be quoted for a future hold',async () => {
    await db.query("UPDATE rooms SET status='occupied' WHERE id=$1",[room]);
    const b=await booking(); assert.ok(b);
  });
  await check('expired hold is rejected without booking writes',async () => {
    await seedHold(); await db.exec("UPDATE booking_holds SET expires_at=now()-interval '1 minute'");
    await assert.rejects(checkout(),e=>e.message==='BOOKING_HOLD_EXPIRED');
  });
  await check('minute-duration controllers and fractional voucher values use cents consistently',async () => {
    await seedHold([room],'2026-10-12 18:00','2026-10-12 19:01'); await voucher(20.123);
    const r=await checkout([{room_id:room,extra_controllers:2}],[],'TEST');
    assert.equal(r.quote.final_total,81.54);
    assert.equal(Number(await scalar('SELECT sum(total_price) r FROM bookings')),81.54);
  });
  await check('duplicate held-room payload is rejected',async () => {
    await seedHold([room,roomB]);
    await assert.rejects(checkout([{room_id:room},{room_id:room}]),e=>e.code==='22023');
  });
  await check('overnight conflicts include next weekday and exclude disjoint date ranges',async () => {
    await pricingRule({start_time:'22:00',end_time:'02:00',start_date:'2026-10-12',end_date:'2026-10-12'});
    await db.exec('CREATE OR REPLACE FUNCTION public.is_super_admin() RETURNS boolean LANGUAGE sql AS $$ SELECT true $$');
    const query = 'SELECT count(*) r FROM check_pricing_rule_conflicts_v2($1,$2,$3,$4,null,$5,null,$6,$7)';
    assert.equal(Number(await scalar(query,[lounge,'01:00','03:00',[2],room,'2026-10-13','2026-10-13'])),1);
    assert.equal(Number(await scalar(query,[lounge,'02:00','03:00',[2],room,'2026-10-13','2026-10-13'])),0);
    assert.equal(Number(await scalar(query,[lounge,'01:00','03:00',[2],room,'2026-10-20','2026-10-20'])),0);
  });
  await check('shared combo component and standalone item use aggregate stock',async () => {
    const b=await booking();
    const r=await order(b,[{combo_id:combo,quantity:2},{extra_id:extra,quantity:3,price:0}]);
    assert.equal(r.total_price,240);
    assert.equal(Number(await scalar('SELECT stock_quantity r FROM extras')),13);
    assert.equal(Number(await scalar('SELECT sum(total_price) r FROM canteen_order_items')),240);
    assert.equal(Number(await scalar("SELECT count(*) r FROM canteen_order_items WHERE line_kind='combo_component'")),1);
    assert.equal(Number(await scalar('SELECT sum(total_price) r FROM booking_items')),240);
    const mirror=await scalar('SELECT items r FROM canteen_orders');
    assert.equal(mirror[0].combo_id,combo); assert.equal(mirror[0].unit_price,60); assert.equal(mirror[0].total_price,120);
  });
  await check('one shortage rolls back every component, order and ledger',async () => {
    const b=await booking(); await db.exec('UPDATE extras SET stock_quantity=3');
    await db.exec('SAVEPOINT failed_order');
    await assert.rejects(order(b,[{extra_id:extra,quantity:2},{combo_id:combo,quantity:1}]),e=>e.message==='OUT_OF_STOCK'&&JSON.parse(e.detail).unavailable_items[0].requested===4);
    await db.exec('ROLLBACK TO SAVEPOINT failed_order');
    assert.equal(Number(await scalar('SELECT stock_quantity r FROM extras')),3);
    assert.equal(Number(await scalar('SELECT count(*) r FROM canteen_orders')),0);
    assert.equal(Number(await scalar('SELECT addons_price r FROM bookings')),0);
  });
  await check('empty combo and unavailable components are rejected',async () => {
    const b=await booking(); await db.exec('DELETE FROM canteen_combo_items');
    await assert.rejects(order(b,[{combo_id:combo,quantity:1}]),e=>e.code==='23514');
  });
  await check('out-of-window combo cannot be bought',async () => {
    const b=await booking(); await db.exec("UPDATE canteen_combos SET valid_to='2000-01-01'");
    await assert.rejects(order(b,[{combo_id:combo,quantity:1}]),e=>e.code==='23514');
  });
  await check('upsell discount and conversion come only from a successful order',async () => {
    const b=await booking(); await db.query("UPDATE bookings SET status='in_progress',actual_start_time=now()-interval '5 minutes' WHERE id=$1",[b]);
    await db.query(`INSERT INTO upsell_rules(id,lounge_id,trigger_type,suggest_combo_id,discount_percent)
      VALUES($1,$2,'session_start',$3,10)`,[rule,lounge,combo]);
    const suggestions=await scalar('SELECT get_upsell_suggestions($1) r',[b]);
    assert.equal(suggestions[0].final_price,54);
    const r=await order(b,[{combo_id:combo,quantity:1,upsell_rule_id:rule,price:1}]);
    assert.equal(r.total_price,54);
    assert.equal(Number(await scalar('SELECT revenue_generated r FROM canteen_upsell_events')),54);
    assert.equal((await scalar('SELECT items r FROM canteen_orders'))[0].unit_price,54);
    await scalar("SELECT record_upsell_event($1,$2,'conversion',$3,999999) r",[rule,b,r.order_id]);
    assert.equal(Number(await scalar('SELECT count(*) r FROM canteen_upsell_events')),1);
    assert.equal(Number(await scalar('SELECT revenue_generated r FROM canteen_upsell_events')),54);
    assert.deepEqual(await scalar('SELECT get_upsell_suggestions($1) r',[b]),[]);
  });
  await check('acceptance without a purchase cannot invent revenue',async () => {
    const b=await booking();
    await db.query(`INSERT INTO upsell_rules(id,lounge_id,trigger_type,suggest_extra_id) VALUES($1,$2,'session_start',$3)`,[rule,lounge,extra]);
    await assert.rejects(scalar("SELECT record_upsell_event($1,$2,'accepted',null,999) r",[rule,b]),e=>e.message==='UPSELL_PURCHASE_REQUIRED');
  });
  await check('customer cannot order against another customer booking',async () => {
    const b=await booking(); await db.exec(`SET request.jwt.claim.sub='${id(90)}'`);
    await assert.rejects(order(b,[{extra_id:extra,quantity:1}]),e=>e.code==='42501');
  });
  if (db.connect) {
    // Separate bookings ensure the shared inventory lock, rather than the
    // booking lock, serializes competing customers' carts on native Postgres.
    const aBooking = await booking();
    await seedHold([roomB]);
    const bBooking = (await checkout([{room_id:roomB}])).primary_booking_id;
    await db.exec('UPDATE extras SET stock_quantity=2');
    const a = await db.connect(), b = await db.connect(), observer = await db.connect();
    let pending;
    try {
      for (const peer of [a,b]) {
        await peer.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[user]);
        await peer.query("SET statement_timeout='10s'");
      }
      await a.query('BEGIN');
      await a.query('SELECT place_canteen_order($1,$2::jsonb)',[aBooking,JSON.stringify([{combo_id:combo,quantity:1}])]);
      const pid = (await b.query('SELECT pg_backend_pid() pid')).rows[0].pid;
      pending = b.query('SELECT place_canteen_order($1,$2::jsonb)',[bBooking,JSON.stringify([{extra_id:extra,quantity:1}])])
        .then(value=>({value}),error=>({error}));
      let blocked = false;
      const deadline = Date.now()+5000;
      while (Date.now()<deadline) {
        const activity=(await observer.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[pid])).rows[0];
        if (activity?.wait_event_type==='Lock') {blocked=true;break;}
        await new Promise(resolve=>setTimeout(resolve,10));
      }
      assert.equal(blocked,true,'Second cart must wait on the inventory lock');
      await a.query('COMMIT');
      const loser=await pending;
      assert.equal(loser.error?.message,'OUT_OF_STOCK');
      assert.equal(Number(await scalar('SELECT stock_quantity r FROM extras')),0);
      assert.equal(Number(await scalar('SELECT count(*) r FROM canteen_orders')),1);
      passed++; console.log('PASS concurrent combo and item orders cannot oversell shared inventory');
    } finally {
      await a.query('ROLLBACK');
      if (pending) await pending;
      await a.end(); await b.end(); await observer.end();
    }
  }
  console.log(JSON.stringify({passed,liveMutations:false,productionFunctions:true}));
} finally {await db.close();}
