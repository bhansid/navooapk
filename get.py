import urllib.request, os, hashlib
H={'User-Agent':'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
os.makedirs('full',exist_ok=True)
for l in open('get.txt'):
    if not l.strip(): continue
    n,u=l.split()
    try:
        b=urllib.request.urlopen(urllib.request.Request(u,headers=H),timeout=60).read(); open(f'full/{n}.jpg','wb').write(b); print('OK',n,len(b))
    except Exception as e: print('ERR',n,e)
rep=[]
for u in ['https://navoo.ai/api/images/config','https://land.navoo.ai/api/images/config']:
    try: rep.append(u+'\n'+urllib.request.urlopen(urllib.request.Request(u,headers=H),timeout=30).read().decode()[:3000])
    except Exception as e: rep.append(u+' ERR '+str(e))
for site in ['https://navoo.ai','https://land.navoo.ai']:
    for s in ['hero','coach','og','struggle','couple','heroCouple','hero-couple']:
        try:
            r=urllib.request.urlopen(urllib.request.Request(site+'/img/'+s,headers=H),timeout=30); b=r.read(); rep.append(f'{site}/img/{s} {r.status} {r.headers.get("content-type")} {len(b)} {hashlib.md5(b).hexdigest()}')
        except Exception as e: rep.append(f'{site}/img/{s} ERR {e}')
open('full/report.txt','w').write('\n'.join(rep))
