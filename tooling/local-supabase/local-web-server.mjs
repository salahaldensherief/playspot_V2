import {createServer} from 'node:http';
import {readFile,realpath,stat} from 'node:fs/promises';
import {extname,resolve,sep,basename} from 'node:path';
import {pathToFileURL} from 'node:url';
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.ttf':'font/ttf','.otf':'font/otf','.css':'text/css','.mp3':'audio/mpeg'};
export async function localWebServer(root){
 const base=await realpath(root);
 if(basename(base)!=='web'||basename(resolve(base,'..'))!=='build')throw new Error('Serve only a Flutter build/web directory');
 const csp="default-src 'none'; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self' http://127.0.0.1:56621 ws://127.0.0.1:56621; img-src 'self' data: blob: http://127.0.0.1:56621; font-src 'self' data:; worker-src 'self' blob:; media-src 'self' blob: http://127.0.0.1:56621; manifest-src 'self'; frame-src 'none'; object-src 'none'; base-uri 'self'; form-action 'self'";
 return createServer(async(req,res)=>{
  res.setHeader('Content-Security-Policy',csp);res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405).end();return;}
  try{
   const path=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);
   if(path.includes('\0')||path.split('/').some(p=>p.startsWith('.'))){res.writeHead(403).end();return;}
   let target=resolve(base,'.'+path);
   if(target!==base&&!target.startsWith(base+sep)){res.writeHead(403).end();return;}
   if(target===base)target=resolve(base,'index.html');
   try {if(!(await stat(target)).isFile())throw new Error('not a file');}
   catch{if(extname(path)){res.writeHead(404).end();return;}target=resolve(base,'index.html');}
   target=await realpath(target);
   if(!target.startsWith(base+sep)){res.writeHead(403).end();return;}
   const body=await readFile(target);res.setHeader('Content-Type',types[extname(target)]??'application/octet-stream');res.setHeader('Content-Length',body.length);res.writeHead(200);res.end(req.method==='HEAD'?undefined:body);
  }catch{res.writeHead(400).end('Local asset unavailable');}
 });
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 const [root,mode]=process.argv.slice(2),ports={dashboard:51651,mobile:51652};
 if(!root||!ports[mode])throw new Error('Usage: local-web-server.mjs BUILD_WEB dashboard|mobile');
 const server=await localWebServer(root);server.listen(ports[mode],'127.0.0.1',()=>console.log('Local-only Flutter build server on 127.0.0.1:'+ports[mode]));
}
