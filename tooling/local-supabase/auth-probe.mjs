// Local-only Auth probe. Service key stays in this Node test process, never Flutter.
import {readFile,writeFile} from 'node:fs/promises';
import {randomBytes,randomUUID} from 'node:crypto';
const [statusPath,accountPath,reportPath]=process.argv.slice(2);
if(!statusPath||!accountPath||!reportPath)throw new Error('Usage: auth-probe.mjs PRIVATE_STATUS PRIVATE_ACCOUNTS REPORT');
const status=JSON.parse(await readFile(statusPath,'utf8'));
const base='http://127.0.0.1:56621';
if(status.API_URL!==base)throw new Error('Isolated local API identity mismatch');
if(!status.ANON_KEY||!status.SERVICE_ROLE_KEY)throw new Error('Local public/server keys missing');
async function request(path,key,body){
 const response=await fetch(base+path,{method:'POST',redirect:'error',headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
 if(!response.ok)throw new Error('Local Auth operation failed; HTTP '+response.status);
 return response.json();
}
let accounts;
try {accounts=JSON.parse(await readFile(accountPath,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
if(!accounts){
 accounts=[];
 for(const persona of ['owner','cashier','customer']){
  const email=`${persona}-${randomUUID()}@playspot.invalid`,password=randomBytes(32).toString('base64url');
  const created=await request('/auth/v1/admin/users',status.SERVICE_ROLE_KEY,{email,password,email_confirm:true});
  accounts.push({persona,id:created.id,email,password});
  // Persist after each creation to preserve retry credentials without printing them.
  await writeFile(accountPath,JSON.stringify(accounts,null,2),{mode:0o600});
 }
}
if(accounts.length!==3)throw new Error('Incomplete synthetic account file; review before retry');
const results=[];
for(const account of accounts){
 const receipt=await request('/auth/v1/token?grant_type=password',status.ANON_KEY,{email:account.email,password:account.password});
 if(receipt.user?.id!==account.id||!receipt.access_token)throw new Error('Local login receipt mismatch');
 results.push({persona:account.persona,authenticated:true,businessRoleAssigned:false});
}
await writeFile(reportPath,JSON.stringify({environment:base,realLocalAuth:true,results,authorization:'NOT TESTED; application baseline/roles not yet seeded',verticalJourney:'NOT EXECUTED'},null,2));
console.log('Three synthetic local Auth logins passed; application authorization and financial journey NOT verified.');
