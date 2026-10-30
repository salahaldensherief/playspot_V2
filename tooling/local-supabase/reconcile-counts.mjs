import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
const [logs,output]=process.argv.slice(2);
if(!logs||!output)throw new Error('Usage: reconcile-counts.mjs OUTPUT_LOG_DIRECTORY REPORT');
const results=[];
for(const [name,expected] of [
 ['verification-payout-refund_aware_payout_reconciliation.log',32],
 ['restack-refund_aware_payout_reconciliation.log',32],
 ['rc-backend-refund_aware_payout_reconciliation.log',35],
 ['refinement-backend-refund_aware_payout_reconciliation.log',35],
]){
 const b=await readFile(resolve(logs,name)),text=b.toString('utf8');
 const summaries=text.split(/\r?\n/).filter(l=>l.startsWith('{"passed":'));
 if(summaries.length!==1)throw new Error('Ambiguous summary '+name);
 const summary=JSON.parse(summaries[0]), printedPasses=text.split(/\r?\n/).filter(l=>l.startsWith('PASS ')).length;
 if(summary.passed!==expected||printedPasses!==expected)throw new Error('Summary/check lines disagree '+name);
 results.push({name,sha256:createHash('sha256').update(b).digest('hex'),passed:summary.passed,printedPasses,environment:summary.environment,
  serializationChecks:text.split(/\r?\n/).filter(l=>l.startsWith('PASS refund initiation versus payout creation:')||l.startsWith('PASS payout waiting for refund execution'))});
}
await writeFile(output,JSON.stringify({note:'Historical log reconciliation, not a new database test run',addedByCommit:'aa8628f4262f198e79f158399fae20d1b9221c7b',delta:3,results},null,2)+'\n');
console.log('Four historical logs verified against their PASS lines: 32,32,35,35; +3 serialization tests, not a changed counting target.');
