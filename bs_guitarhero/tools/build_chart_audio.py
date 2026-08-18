"""Chart dintr-o inregistrare cu tempo variabil, fara tab.

Bataile vin din beat tracking (programare dinamica), nu dintr-o grila fixa, ca
sa urmareasca accelerarile si incetinirile piesei. Notele cad pe optimile pe
care se aude efectiv o lovitura, iar culoarele urmeaza structura de fraze.
"""
import numpy as np, json, collections

TITLE, ARTIST, ALBUM = 'O Mie De Pahare', 'White Mahala', ''
OUT   = 'pahare.json'
# Fisierul livrat e taiat la TRIM secunde din original, ca sa inceapa direct
# in banda (intro-ul avea ~30 s in care nu se canta mai nimic). Toti timpii de
# mai jos sunt in secundele fisierului ORIGINAL si se muta la final.
TRIM  = 28.0033
START, END = 28.6, 199.6      # portiunea folosita din inregistrare
LANES = 4
PHRASE = 4                    # masuri intr-o fraza

flux  = np.load('flux3.npy'); fps = 22050/256
beats = np.load('beats3.npy')

def amp(t):
    i = int(round(t*fps))
    return float(max(flux[i-1], flux[i], flux[i+1])) if 1 <= i < len(flux)-1 else 0.0

# ---- optimile, cu energia lor -------------------------------------------
cand = []
for i in range(len(beats)-1):
    b0, b1 = beats[i], beats[i+1]
    cand.append((b0,            i, 0, amp(b0)))
    cand.append(((b0+b1)/2,     i, 1, amp((b0+b1)/2)))
cand = [c for c in cand if START <= c[0] <= END]

energies = np.array([c[3] for c in cand])
FLOOR   = float(np.percentile(energies, 22))   # sub asta nu se canta nimic
OFFBEAT = float(np.percentile(energies, 52))   # contratimpul intra doar cand se aude

# ---- alegerea notelor ----------------------------------------------------
notes = []
for t, bi, off, e in cand:
    if e < FLOOR: continue                      # pasaj gol / prea slab
    if off == 1 and e < OFFBEAT: continue       # contratimp doar unde chiar e o lovitura

    bar     = bi // 4
    inBar   = bi % 4
    phrase  = bar // PHRASE
    base    = [0, 1, 3, 2][phrase % 4]          # baza frazei se plimba prin culoare
    step    = inBar if (phrase % 2 == 0) else (3 - inBar)   # fraze alternate: urca / coboara
    lane    = (base + step + (2 if off else 0)) % LANES

    notes.append({
        't': round(float(t) - TRIM, 4),
        'l': int(lane),
        'd': 0.0,
        's': 1 if off == 0 else 2,
        'e': round(float(e), 3),
    })

notes.sort(key=lambda n: n['t'])
ded, seen = [], set()
for n in notes:
    k = (round(n['t'], 3), n['l'])
    if k in seen: continue
    seen.add(k); ded.append(n)
notes = ded
for n in notes: n.pop('e', None)

chart = {
    'title': TITLE, 'artist': ARTIST, 'album': ALBUM,
    'bpm': round(60.0/float(np.diff(beats).mean()), 2),
    'offset': round(float(beats[0]) - TRIM, 4),
    # tempo variabil -> liniile de masura merg pe bataile reale, nu pe o grila fixa
    'beats': [round(float(b) - TRIM, 4) for b in beats if START - 3 <= b <= END + 2],
    'lanes': LANES,
    'songEnd': round(END - TRIM, 3),
    'sections': [],
    'notes': notes,
}
json.dump(chart, open(OUT, 'w'), separators=(',', ':'))

span = notes[-1]['t'] - notes[0]['t']
print(f"note: {len(notes)}  ({notes[0]['t']:.2f}s -> {notes[-1]['t']:.2f}s, {len(notes)/span:.2f}/s)")
print("pe banda:", dict(sorted(collections.Counter(n['l'] for n in notes).items())))
print("pe pozitie:", dict(collections.Counter('bataie' if n['s']==1 else 'contratimp' for n in notes)))
print("tempo mediu %.2f BPM (variaza %.1f - %.1f)"
      % (chart['bpm'], 60/np.diff(beats).max(), 60/np.diff(beats).min()))
print("\ndensitate pe 20s:")
for a in range(0, 180, 20):
    k = sum(1 for n in notes if a <= n['t'] < a+20)
    print(f"   {a:3d}-{a+20:3d}s  {k:3d} note  {k/20:.2f}/s  {'#'*int(k/4)}")
