import assert from 'node:assert/strict';

export async function lockedRace(db, first, second, actor, firstAsAdmin=false) {
  const a=await db.connect(),b=await db.connect(),observer=await db.connect();
  let pending, settled;
  try {
    for (const peer of [a,b]) {
      await peer.query(`SELECT set_config('test.actor',$1,false)`,[actor]);
      await peer.query("SET ROLE authenticated;SET statement_timeout='10s'");
    }
    if(firstAsAdmin) await a.query('RESET ROLE');
    await a.query('BEGIN');
    const applied=await a.query(first.sql,first.args);
    const pid=(await b.query('SELECT pg_backend_pid() AS pid')).rows[0].pid;
    pending=b.query(second.sql,second.args).then(value=>({value}),error=>({error}));
    pending.then(result => {settled = result;});
    let blocked=false;
    const deadline=Date.now()+5000;
    while(Date.now()<deadline) {
      const activity=(await observer.query('SELECT wait_event_type FROM pg_stat_activity WHERE pid=$1',[pid])).rows[0];
      if(activity?.wait_event_type==='Lock') {blocked=true;break;}
      await new Promise(resolve=>setTimeout(resolve,10));
    }
    assert.equal(blocked,true,'Competing connection must demonstrably wait on a PostgreSQL lock; early result: '
      + JSON.stringify(settled?.error ? {code:settled.error.code,message:settled.error.message} : {completed:!!settled}));
    if (first.beforeCommit) await first.beforeCommit(a);
    await a.query('COMMIT');
    return [applied,await pending];
  } catch(error) {
    await a.query('ROLLBACK');
    if(pending) await pending;
    throw error;
  } finally {await a.end();await b.end();await observer.end();}
}
