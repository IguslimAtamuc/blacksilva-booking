"""Genereaza chart-ul pentru Rammstein - Ich Will din tab-ul Guitar Pro."""
import guitarpro as gp, json, collections

SRC    = 'rammstein-ich_will.gp4'
BPM    = 127.99   # tempo masurat in inregistrare
# Masura 1 cade la 30.802 s in fisierul original (varianta de videoclip).
# Fisierul livrat e taiat la 33.0188 s ca sa sara peste intro-ul filmului,
# deci pe noua axa de timp masura 1 cade inainte de secunda 0.
TRIM   = 33.0188
OFFSET = round(30.802 - TRIM, 4)
QN     = 960
SPB    = 60.0 / BPM
LANES  = 4

song  = gp.parse(SRC)
hdrs  = song.measureHeaders
NM    = len(hdrs)

def track_beats(ti):
    t = song.tracks[ti]; res = {}
    for m in t.measures:
        lst = []
        for v in m.voices:
            for b in v.beats:
                if b.status.name == 'rest' or not b.notes: continue
                ps = [t.strings[n.string - 1].value + n.value
                      for n in b.notes if n.type.name in ('normal', 'tie')]
                if ps: lst.append((b.start - m.start, ps, b.duration.time))
        lst.sort()
        res[m.number] = lst
    return res

GTR  = track_beats(0)   # Richard Kruspe - Guitar 1 (ritmica distorsionata)
BASS = track_beats(2)   # Oliver Riedel - Bass

def voicing(ps):
    """Cheia care distinge doua acorduri: nota cea mai inalta + cate coarde suna.
    Riff-ul din Ich Will alterneaza doua acorduri cu ACELASI varf (re), diferite
    doar prin numarul de coarde - deci numarul de note trebuie sa conteze."""
    return (max(ps), len(ps))

def lane_table(src):
    """Imparte acordurile - ordonate dupa inaltime - in 4 blocuri consecutive,
    alese ca sa incarce benzile cat mai egal (programare dinamica). Ordinea dupa
    inaltime se pastreaza, deci conturul melodic ramane corect, dar nicio banda
    nu ramane aproape nefolosita."""
    cnt = collections.Counter()
    for lst in src.values():
        for _, ps, _ in lst: cnt[voicing(ps)] += 1
    keys = sorted(cnt)
    w    = [cnt[k] for k in keys]
    n    = len(keys)
    if n <= LANES:
        return {k: min(LANES - 1, i) for i, k in enumerate(keys)}

    pre = [0]
    for x in w: pre.append(pre[-1] + x)
    ideal = pre[-1] / LANES
    INF = float('inf')
    # best[i][j] = costul minim pentru primele i acorduri impartite in j blocuri
    best = [[INF] * (LANES + 1) for _ in range(n + 1)]
    cut  = [[0] * (LANES + 1) for _ in range(n + 1)]
    best[0][0] = 0.0
    for j in range(1, LANES + 1):
        for i in range(1, n + 1):
            for k in range(j - 1, i):
                if best[k][j - 1] == INF: continue
                load = pre[i] - pre[k]
                c = best[k][j - 1] + (load - ideal) ** 2
                if c < best[i][j]:
                    best[i][j] = c; cut[i][j] = k
    table, i = {}, n
    for j in range(LANES, 0, -1):
        k = cut[i][j]
        for idx in range(k, i): table[keys[idx]] = j - 1
        i = k
    return table

LANE_GTR  = lane_table(GTR)
LANE_BASS = lane_table(BASS)
print('lane table guitar:', LANE_GTR)
print('lane table bass  :', LANE_BASS)

notes, sections, lastSection = [], [], None
for mn in range(1, NM + 1):
    mh     = hdrs[mn - 1]
    mStart = OFFSET + (mn - 1) * 4 * SPB
    if mh.marker and mh.marker.title != lastSection:
        lastSection = mh.marker.title
        sections.append({'t': round(mStart, 4), 'name': mh.marker.title})

    if GTR.get(mn):
        src, table, kind = GTR[mn], LANE_GTR, 'guitar'
    elif BASS.get(mn):
        src, table, kind = BASS[mn], LANE_BASS, 'bass'
    else:
        continue

    for tick, ps, dur in src:
        beatPos = tick / QN
        e = round(beatPos * 4)
        if   abs(beatPos * 4 - e) > 0.02: sub = 3
        elif e % 16 == 0:                 sub = 0
        elif e % 4 == 0:                  sub = 1
        elif e % 2 == 0:                  sub = 2
        else:                             sub = 3
        notes.append({
            't': round(mStart + beatPos * SPB, 4),
            'l': table[voicing(ps)],
            'd': round(dur / QN * SPB, 4),
            's': sub,
            'k': kind,
        })

notes.sort(key=lambda n: (n['t'], n['l']))
ded, seen = [], set()
for n in notes:
    key = (round(n['t'], 3), n['l'])
    if key in seen: continue
    seen.add(key); ded.append(n)
notes = ded

chart = {
    'title': 'Ich Will', 'artist': 'Rammstein', 'album': 'Mutter',
    'bpm': BPM, 'offset': OFFSET, 'lanes': LANES,
    'measures': NM,
    'songEnd': round(OFFSET + NM * 4 * SPB, 3),
    'sections': sections,
    'notes': notes,
}
json.dump(chart, open('ichwill.json', 'w'), separators=(',', ':'))

print('measures %d  -> masura 1 la %.3fs, ultima masura se termina la %.2fs'
      % (NM, OFFSET, chart['songEnd']))
print('note:', len(notes))
print('pe banda :', dict(sorted(collections.Counter(n['l'] for n in notes).items())))
print('pe sursa :', dict(collections.Counter(n['k'] for n in notes)))
print('pe subdiv:', dict(sorted(collections.Counter(n['s'] for n in notes).items())))
print('sectiuni :', [(s['name'], round(s['t'], 1)) for s in sections])
print('prima nota %.3f  ultima nota %.3f' % (notes[0]['t'], notes[-1]['t']))
# densitate pe sectiune
for i, s in enumerate(sections):
    e = sections[i + 1]['t'] if i + 1 < len(sections) else chart['songEnd']
    seg = [n for n in notes if s['t'] <= n['t'] < e]
    lanes_used = sorted(set(n['l'] for n in seg))
    print('  %-12s %5.1f-%5.1fs  %3d note  %.2f/s  benzi %s'
          % (s['name'], s['t'], e, len(seg), len(seg) / (e - s['t']), lanes_used))
