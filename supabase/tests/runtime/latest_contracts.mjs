import {readFile} from 'node:fs/promises';

export async function installLatestFunctions(db, names) {
  const sql=await readFile(new URL('../../migrations/20261011133001_latest_commit_contract_hardening.sql',import.meta.url),'utf8');
  for (const name of names) {
    const prefix=`CREATE OR REPLACE FUNCTION ${name}`;
    const start=sql.indexOf(prefix+'(');
    if(start<0) throw new Error('Missing reviewed function '+name);
    const body=sql.slice(start);
    const opening=/\bAS\s+(\$[A-Za-z_]*\$)/i.exec(body);
    if(!opening) throw new Error('Missing function body '+name);
    const end=body.indexOf(opening[1],opening.index+opening[0].length);
    if(end<0) throw new Error('Missing function terminator '+name);
    await db.exec(body.slice(0,end+opening[1].length)+';');
  }
}
