// Read-only source inventory. Patch equivalence is not a merge/release approval.
import {execFileSync} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
const [root,output]=process.argv.slice(2);
const git=(...args)=>execFileSync('git',['-C',root,...args],{encoding:'utf8'}).trim();
const refs=git('for-each-ref','--format=%(refname:short)','refs/heads','refs/remotes/origin').split('\n');
const branches=[];
for(const ref of refs){
 if(ref==='origin/HEAD')continue;
 const [behind,ahead]=git('rev-list','--left-right','--count','dev...'+ref).split(/\s+/).map(Number);
 const cherry=ahead?git('cherry','dev',ref).split('\n').filter(Boolean):[];
 branches.push({ref,head:git('rev-parse',ref),behind,ahead,
   uniquePatches:cherry.filter(x=>x.startsWith('+')).length,
   equivalentPatches:cherry.filter(x=>x.startsWith('-')).length,
   files:ahead?git('diff','--name-only','dev...'+ref).split('\n').filter(Boolean):[]});
}
await writeFile(output,JSON.stringify({base:git('rev-parse','dev'),
 remoteMain:git('rev-parse','origin/main'),branches,
 caveat:'Inventory only. Historical branches may include proposals, duplicates or obsolete contracts; review and tests determine integration.'},null,2));
console.log(JSON.stringify({base:git('rev-parse','dev'),branches:branches.length,
 uniqueBranches:branches.filter(x=>x.uniquePatches>0).length}));
