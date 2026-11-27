import json, urllib.request, urllib.parse, os
from PIL import Image, ImageDraw
H = {'User-Agent':'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36'}
def get(u, raw=True):
    r = urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=40).read()
    return r if raw else json.loads(r)
os.makedirs('out', exist_ok=True)
meta = {}
groups = {}
# Pexels IDs
for i in []:
    groups.setdefault('pexels', []).append(('p'+i, f'https://images.pexels.com/photos/{i}/pexels-photo-{i}.jpeg?auto=compress&cs=tinysrgb&w=500', {'src':'pexels','id':i}))
# Openverse (stocksnap etc, commercial-use)
for qi, q in enumerate([l.strip() for l in open('queries.txt') if l.strip()]):
    try:
        d = get('https://api.openverse.org/v1/images/?' + urllib.parse.urlencode({'q': q, 'license_type': 'commercial,modification', 'page_size': 20, 'size':'large', 'category':'photograph', 'source':'stocksnap'}), raw=False)
    except Exception as e:
        print('ERR ov', q, e); continue
    for j, r in enumerate(d.get('results', [])):
        groups.setdefault(f'ov{qi:02d}', []).append((f'o{qi}-{j}', r.get('thumbnail') or r['url'], {'src':r.get('source'),'url':r['url'],'lic':r.get('license'),'landing':r.get('foreign_landing_url'),'creator':r.get('creator'),'q':q,'w':r.get('width'),'h':r.get('height')}))
for g, items in groups.items():
    thumbs = []
    for k, u, m in items:
        try:
            b = get(u); fn = f'/tmp/{k}.jpg'; open(fn,'wb').write(b); Image.open(fn).verify()
            thumbs.append((k, fn)); meta[k] = m
        except Exception as e:
            print('ERR', k, e)
    W, Hh, cols = 260, 260, 6
    for page in range(0, len(thumbs), 24):
        chunk = thumbs[page:page+24]
        rows = (len(chunk)+cols-1)//cols
        sh = Image.new('RGB', (W*cols, (Hh+18)*max(rows,1)), 'white'); dr = ImageDraw.Draw(sh)
        for i, (k, f) in enumerate(chunk):
            im = Image.open(f).convert('RGB'); im.thumbnail((W-4, Hh)); x=(i%cols)*W; y=(i//cols)*(Hh+18)
            sh.paste(im,(x,y)); dr.text((x+3,y+Hh+3), k + ' ' + str(meta[k].get('src')), fill='black')
        sh.save(f'out/sheet_{g}_{page//24}.jpg', quality=70)
    print(g, len(thumbs))
json.dump(meta, open('out/meta.json','w'), indent=1)
