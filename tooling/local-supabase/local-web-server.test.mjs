import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,symlink} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {once} from 'node:events';
import {localWebServer} from './local-web-server.mjs';
test('local acceptance server scopes files and blocks hosted subresources by policy',async()=>{
 const temporary=await mkdtemp(join(tmpdir(),'playspot-web-')),root=join(temporary,'build','web');
 await mkdir(root,{recursive:true});await writeFile(join(root,'index.html'),'fixture index');await writeFile(join(temporary,'private.txt'),'synthetic secret');
 const server=await localWebServer(root);server.listen(0,'127.0.0.1');await once(server,'listening');
 try {
  assert.equal(server.address().address,'127.0.0.1');const base='http://127.0.0.1:'+server.address().port;
  const page=await fetch(base+'/bookings');assert.equal(page.status,200);assert.equal(await page.text(),'fixture index');
  const policy=page.headers.get('content-security-policy');assert.match(policy,/connect-src 'self' http:\/\/127\.0\.0\.1:56621 ws:\/\/127\.0\.0\.1:56621;/);assert.ok(!policy.includes('https:'));
  assert.equal((await fetch(base+'/.env')).status,403);
  assert.equal((await fetch(base+'/%2e%2e%2fprivate.txt')).status,403);
  assert.equal((await fetch(base+'/missing.js')).status,404);
  assert.equal((await fetch(base+'/',{method:'POST'})).status,405);
 }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
});
