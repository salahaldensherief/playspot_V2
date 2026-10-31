// Fixture-only public display metadata. Authorization remains in server tables.
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const [directory]=process.argv.slice(2);
const status=JSON.parse(await readFile(directory+'/status.json','utf8'));
const accounts=JSON.parse(await readFile(directory+'/accounts.json','utf8'));
const base='http://127.0.0.1:56621';assert.equal(status.API_URL,base);
for(const [index,a] of accounts.entries()){
 assert.match(a.email,/@playspot\.invalid$/);assert.match(a.id,/^[\da-f-]{36}$/);
 const r=await fetch(base+'/auth/v1/admin/users/'+a.id,{method:'PUT',redirect:'error',headers:{apikey:status.SERVICE_ROLE_KEY,Authorization:'Bearer '+status.SERVICE_ROLE_KEY,'Content-Type':'application/json'},body:JSON.stringify({user_metadata:{full_name:'LOCAL SYNTHETIC '+a.persona.toUpperCase(),phone:'0100000900'+(index+1)}}),signal:AbortSignal.timeout(15000)});
 assert.equal(r.status,200);
}
console.log('Three synthetic Auth display profiles populated; no authorization metadata changed.');
