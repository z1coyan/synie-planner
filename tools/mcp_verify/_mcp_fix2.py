import json, urllib.request, time, sys
URL='http://127.0.0.1:8000/mcp'
SID=None

def parse(raw):
    datas=[]
    for line in raw.splitlines():
        if line.startswith('data:'):
            datas.append(line[5:].lstrip())
    if not datas:
        try: return json.loads(raw)
        except: return {'raw': raw[:2000]}
    try: return json.loads('\n'.join(datas))
    except: return {'raw': '\n'.join(datas)[:2000]}

def rpc(method, params=None, req_id=1, notify=False):
    global SID
    body={'jsonrpc':'2.0','method':method}
    if not notify: body['id']=req_id
    if params is not None: body['params']=params
    data=json.dumps(body).encode()
    headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'}
    if SID: headers['Mcp-Session-Id']=SID
    req=urllib.request.Request(URL,data=data,headers=headers,method='POST')
    with urllib.request.urlopen(req,timeout=180) as resp:
        sid=resp.headers.get('Mcp-Session-Id')
        if sid: SID=sid
        raw=resp.read().decode('utf-8',errors='replace')
        if notify: return {'ok':True}
        return parse(raw)

def tool(name, arguments, req_id=1):
    return rpc('tools/call', {'name':name,'arguments':arguments}, req_id=req_id)

def show(tag, obj):
    s=json.dumps(obj,ensure_ascii=False)
    if len(s)>4000: s=s[:4000]+'...'
    sys.stdout.buffer.write(('=== %s ===\n%s\n' % (tag, s)).encode('utf-8',errors='replace'))

def unwrap(resp):
    r=resp.get('result') or {}
    sc=r.get('structuredContent')
    if sc is not None:
        return sc
    for c in r.get('content') or []:
        if c.get('type')=='text':
            t=c.get('text','')
            try: return json.loads(t)
            except: return {'text': t}
    return r

init=rpc('initialize',{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'fix2','version':'1'}},1)
show('INIT', {'sid':SID,'server':(init.get('result') or {}).get('serverInfo')})
rpc('notifications/initialized',{},notify=True)

show('STOP', unwrap(tool('project_manage', {'op':'stop','params':{}}, 2)))
show('SCAN', unwrap(tool('filesystem_manage', {'op':'scan','params':{}}, 3)))
show('LOGS_CLEAR', unwrap(tool('editor_manage', {'op':'logs_clear','params':{}}, 4)))
time.sleep(1.0)
run=unwrap(tool('project_run', {'mode':'main'}, 5))
show('RUN', run)

final=None
for i in range(15):
    time.sleep(1.0)
    sc=unwrap(tool('editor_state', {}, 10+i))
    helper=sc.get('helper_live') if isinstance(sc, dict) else None
    gs=sc.get('game_status') if isinstance(sc, dict) else None
    status=gs.get('status') if isinstance(gs, dict) else None
    ready=gs.get('ready') if isinstance(gs, dict) else None
    errs=sc.get('current_run_errors') if isinstance(sc, dict) else None
    if errs is None and isinstance(run, dict):
        errs=run.get('current_run_errors')
    msg='poll %d: helper_live=%s ready=%s status=%s' % (i, helper, ready, status)
    sys.stdout.buffer.write((msg+'\n').encode('utf-8'))
    if helper is True:
        final=sc
        show('OK_STATE', sc)
        break
    if status == 'break':
        # also fetch project_run style errors via logs
        logs=unwrap(tool('logs_read', {'source':'editor','include_details':True}, 40+i))
        show('BREAK_STATE', sc)
        show('EDITOR_LOGS', logs)
        final=sc
        break
else:
    final=sc
    show('TIMEOUT_STATE', sc)

show('STOP2', unwrap(tool('project_manage', {'op':'stop','params':{}}, 60)))

# summary
hl = None
cre = None
if isinstance(final, dict):
    hl=final.get('helper_live')
    cre=final.get('current_run_errors')
if cre is None and isinstance(run, dict):
    cre=run.get('current_run_errors')
    if hl is None:
        hl=run.get('helper_live')
show('SUMMARY', {'helper_live': hl, 'current_run_errors': cre})
print('DONE')
