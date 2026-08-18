import guitarpro as gp, json, collections

SRC='linkin_park-faint.gp4'   # pune fisierul .gp4 langa script
BPM   = 135.03
OFFSET= 0.823          # audio time of measure 1, beat 1
QN    = 960            # ticks per quarter in pyguitarpro
SPB   = 60.0/BPM       # seconds per quarter note

song = gp.parse(SRC)
hdrs = song.measureHeaders

# ---------- 1. expand repeats -> linear list of source measure indices ----------
def expand(hdrs):
    out=[]; i=0; openIdx=0; playedRepeat=set()
    n=len(hdrs)
    repeatCount={}
    while i < n:
        mh=hdrs[i]
        if mh.isRepeatOpen: openIdx=i
        # alternate endings: on the final pass skip alt==1 blocks, on first pass skip alt==2
        alt=mh.repeatAlternative
        passNo=repeatCount.get(openIdx,0)
        if alt:
            # alt is a bitmask of pass numbers (1 => pass 0, 2 => pass 1, ...)
            if not (alt >> passNo) & 1:
                i+=1; continue
        out.append(i)
        if mh.repeatClose > 0:
            done=repeatCount.get(openIdx,0)
            if done < mh.repeatClose:
                repeatCount[openIdx]=done+1
                i=openIdx
                continue
        i+=1
    return out

order = expand(hdrs)
print("expanded measures:", len(order), "-> end time",
      round(OFFSET + len(order)*4*SPB, 2), "s")

# ---------- 2. collect beats per track keyed by (measureIndex, tickInMeasure) ----------
def pitch_of(track, note):
    return track.strings[note.string-1].value + note.value

def track_beats(ti):
    """{measureIndex: [(tickRel, [pitches], durTicks, isRest)]}"""
    t=song.tracks[ti]; res={}
    for mi,m in enumerate(t.measures):
        lst=[]
        for v in m.voices:
            for b in v.beats:
                if b.status.name=='rest' or not b.notes: continue
                ps=[pitch_of(t,nt) for nt in b.notes
                    if nt.type.name in ('normal','tie')]
                if not ps: continue
                lst.append((b.start-m.start, ps, b.duration.time))
        lst.sort()
        res[mi]=lst
    return res

LEAD = track_beats(1)   # Brad Delson - lead guitar
SYNTH= track_beats(0)   # Joesph Hahn - synth/string riff
RHY  = track_beats(2)   # Mike Shinoda - rhythm guitar

# ---------- 3. per-source pitch -> lane tables ----------
def lane_table(src, pick):
    """Map pitch -> lane 0..4, keeping pitch order but balancing lane usage by
    how often each pitch actually occurs (frequency quantiles)."""
    cnt=collections.Counter()
    for lst in src.values():
        for _,ps,_ in lst: cnt[pick(ps)]+=1
    order_=sorted(cnt)
    total=sum(cnt.values())
    table={}; run=0
    for p in order_:
        mid = run + cnt[p]/2.0
        table[p] = min(4, int(mid/total*5))
        run += cnt[p]
    return table

LOW  = min      # chord root for guitars
HIGH = max      # top note for the synth lead
LANE_LEAD  = lane_table(LEAD,  LOW)
LANE_SYNTH = lane_table(SYNTH, HIGH)
LANE_RHY   = lane_table(RHY,   LOW)
print("lead lanes ", LANE_LEAD)
print("synth lanes", LANE_SYNTH)

# ---------- 4. build the chart ----------
notes=[]
sections=[]
lastSection=None
for pos,mi in enumerate(order):
    mh=hdrs[mi]
    mStart = OFFSET + pos*4*SPB
    if mh.marker and mh.marker.title != lastSection:
        lastSection=mh.marker.title
        sections.append({"t": round(mStart,4), "name": mh.marker.title})
    # pick the source that carries this measure
    if LEAD.get(mi):        src, table, pick, kind = LEAD[mi],  LANE_LEAD,  LOW,  "lead"
    elif SYNTH.get(mi):     src, table, pick, kind = SYNTH[mi], LANE_SYNTH, HIGH, "synth"
    elif RHY.get(mi):       src, table, pick, kind = RHY[mi],   LANE_RHY,   LOW,  "rhythm"
    else: continue
    for tick, ps, dur in src:
        beatPos = tick/QN                      # 0..4 within the measure
        t = mStart + beatPos*SPB
        lane = table[pick(ps)]
        # subdivision class: 0 = downbeat, 1 = quarter, 2 = eighth, 3 = finer
        e = round(beatPos*4)
        if abs(beatPos*4 - e) > 0.02: sub=3
        elif e % 16 == 0:             sub=0
        elif e % 4 == 0:              sub=1
        elif e % 2 == 0:              sub=2
        else:                         sub=3
        notes.append({
            "t":  round(t,4),
            "l":  lane,
            "d":  round(dur/QN*SPB,4),
            "s":  sub,
            "k":  kind,
        })

notes.sort(key=lambda n:(n["t"], n["l"]))
# drop exact duplicates (same time + lane)
ded=[]; seen=set()
for n in notes:
    key=(round(n["t"],3), n["l"])
    if key in seen: continue
    seen.add(key); ded.append(n)
notes=ded

chart={
    "title":"Faint", "artist":"Linkin Park", "album":"Meteora",
    "bpm":BPM, "offset":OFFSET, "lanes":5,
    "measures":len(order),
    "duration": round(OFFSET+len(order)*4*SPB, 3),
    "sections":sections,
    "notes":notes,
}
json.dump(chart, open('chart.json','w'), separators=(',',':'))
print("notes:", len(notes))
print("per lane:", collections.Counter(n["l"] for n in notes))
print("per sub :", collections.Counter(n["s"] for n in notes))
print("per kind:", collections.Counter(n["k"] for n in notes))
print("sections:", sections)
print("first 16:", notes[:16])
print("last  4:", notes[-4:])
