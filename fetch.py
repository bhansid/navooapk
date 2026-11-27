import json, urllib.request, urllib.parse, os, sys
from PIL import Image, ImageDraw
Q = [l.strip() for l in open('queries.txt') if l.strip()]
H = {'User-Agent':'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/124 Safari/537.36','Accept':'application/json'}
def get(u, raw=False):
    r = urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=40).read()
    return r if raw else json.loads(r)
os.makedirs('out', exist_ok=True)
meta = {}
n = 0
for qi, q in enumerate(Q):
    try:
        d = get('https://unsplash.com/napi/search/photos?' + urllib.parse.urlencode({'query': q, 'per_page': 30}))
    except Exception as e:
        print('ERR', q, e); continue
    thumbs = []
    for p in d.get('results', []):
        if p.get('premium') or p.get('plus') or 'plus.unsplash' in p['urls']['small']: continue
        n += 1; key = f'{qi}-{len(thumbs)}'
        try:
            b = get(p['urls']['small'], raw=True)
        except Exception as e:
            continue
        fn = f'out/t_{key}.jpg'; open(fn, 'wb').write(b)
        meta[key] = {'id': p['id'], 'raw': p['urls']['raw'], 'w': p['width'], 'h': p['height'], 'user': p['user']['name'], 'link': p['links']['html'], 'alt': p.get('alt_description'), 'q': q}
        thumbs.append((key, fn))
        if len(thumbs) >= 24: break
    W, Hh, cols = 260, 260, 6
    rows = (len(thumbs) + cols - 1) // cols
    sh = Image.new('RGB', (W * cols, (Hh + 18) * max(rows,1)), 'white'); dr = ImageDraw.Draw(sh)
    for i, (k, f) in enumerate(thumbs):
        im = Image.open(f).convert('RGB'); im.thumbnail((W - 4, Hh)); x = (i % cols) * W; y = (i // cols) * (Hh + 18)
        sh.paste(im, (x, y)); dr.text((x + 3, y + Hh + 3), k, fill='black')
    sh.save(f'out/sheet_{qi:02d}.jpg', quality=70)
    for k, f in thumbs: os.remove(f)
    print(q, len(thumbs))
json.dump(meta, open('out/meta.json', 'w'), indent=1)
