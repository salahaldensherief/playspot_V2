import pathlib,re,json,collections,subprocess,csv
W=pathlib.Path(__file__).parent
fs=json.loads((W/'prod_functions.json').read_text()); demo=json.loads((W/'demo_functions.json').read_text()); tables=json.loads((W/'prod_tables.json').read_text())
by=collections.defaultdict(list)
for f in fs: by[f['name']].append(f)
def callend(s,start):
    depth=1; quote=None; escape=False
    for i in range(start,len(s)):
        c=s[i]
        if quote:
            if escape: escape=False
            elif c=='\\': escape=True
            elif c==quote: quote=None
        elif c in "\"'": quote=c
        elif c=='(': depth+=1
        elif c==')':
            depth-=1
            if not depth:return i+1
    return min(start+2000,len(s))
allcalls=[]
for repo in ['mobile-dev','dashboard-current']:
    root=W/repo
    for p in (root/'lib').rglob('*.dart'):
        s=p.read_text(encoding='utf-8');rel=p.relative_to(root).as_posix()
        for m in re.finditer(r'\.(rpc|from|invoke)\s*\(\s*([\'\"])([^\'\"]+)\2',s):
            kind,name=m.group(1),m.group(3)
            if kind=='from' and (name.startswith('p_') or name=='json'):continue
            end=callend(s,s.index('(',m.start())+1); snippet=s[m.start():end]
            params=sorted(set(re.findall(r"['\"](p_\w+)['\"]\s*:",snippet)))
            defs=by.get(name,[]) if kind=='rpc' else []
            argsets=[set(re.findall(r'(?:^|,\s*)(\w+)\s+',f['args'])) for f in defs]
            exists=bool(defs) if kind=='rpc' else any(t['relname']==name for t in tables) if kind=='from' else None
            status='TARGET EXISTS; semantics unverified' if exists else 'TARGET NOT FOUND' if exists is False else 'EDGE/SPECIAL TARGET; inspect'
            if kind=='rpc' and defs and params and not any(set(params)<=a for a in argsets):status='PARAMETER CANDIDATE MISMATCH'
            allcalls.append(dict(repo=repo,file=rel,line=s.count('\n',0,m.start())+1,kind=kind,target=name,params=params,status=status,signatures=[f['args'] for f in defs],returns=[f['result'] for f in defs],snippet=snippet,context=s[max(0,m.start()-170):min(len(s),end+300)]))
    # nonliteral calls and auth/realtime requests are a separate, explicitly unresolved register
    for p in (root/'lib').rglob('*.dart'):
        for n,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
            if re.search(r'\.rpc\(\s*$|\.rpc\(\s*[a-zA-Z_]|\.auth\.|\.storage\.|onPostgresChanges|\.channel\(|\.stream\(',line):
                pass
(W/'calls.json').write_text(json.dumps(allcalls,indent=2),encoding='utf-8')
for repo in ['mobile-dev','dashboard-current']:
    calls=[c for c in allcalls if c['repo']==repo]
    print(repo,len(calls),collections.Counter(c['kind'] for c in calls),collections.Counter(c['status'] for c in calls))
    for c in calls:
        if c['status'] in ['TARGET NOT FOUND','PARAMETER CANDIDATE MISMATCH']: print(c['status'],c['target'],c['file'],c['line'],c['params'],c['signatures'])
print('functions',len(fs),'demo',len(demo),'tables',len(tables))
print('constraints',*[c for c in json.loads((W/'prod_constraints.json').read_text()) if c['definition'].startswith('EXCLUDE')],sep='\n')
