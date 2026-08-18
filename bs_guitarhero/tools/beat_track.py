"""Beat tracking cu programare dinamica (stil Ellis 2007), care urmareste
tempo-ul variabil in loc sa-l presupuna constant."""
import numpy as np

flux=np.load('flux3.npy').astype(np.float64); fps=22050/256

# netezim putin plicul de onset si scoatem media locala
k=int(0.10*fps)
kern=np.ones(k)/k
loc=np.convolve(flux,kern,mode='same')
o=np.maximum(0.0, flux-loc)
o/= (o.std()+1e-9)

def track(period_frames, tightness=100.0):
    N=len(o)
    # fereastra de cautare a bataii anterioare: 0.5x .. 2x perioada
    lo=int(period_frames*0.55); hi=int(period_frames*1.75)
    score=np.full(N,-1e18); back=np.full(N,-1,dtype=int)
    score[:hi]=o[:hi]
    for t in range(hi,N):
        js=np.arange(t-hi,t-lo+1)
        pen=-tightness*(np.log(np.maximum(t-js,1)/period_frames))**2
        cand=score[js]+pen
        i=int(np.argmax(cand))
        score[t]=o[t]+cand[i]
        back[t]=js[i]
    # pornim de la cel mai bun final
    tail=int(np.argmax(score[-int(period_frames*2):]))+N-int(period_frames*2)
    beats=[]; t=tail
    while t>=0 and back[t]>=0:
        beats.append(t); t=back[t]
    beats.append(t if t>=0 else 0)
    return np.array(sorted(beats))/fps

per=60.0/128.96*fps
beats=track(per)
print("batai gasite:",len(beats),"| prima %.3fs, ultima %.3fs"%(beats[0],beats[-1]))
ivs=np.diff(beats)
print("interval mediu %.4fs (%.2f BPM), min %.3f, max %.3f, deviatie %.4f"
      %(ivs.mean(),60/ivs.mean(),ivs.min(),ivs.max(),ivs.std()))
np.save('beats3.npy',beats)

# tempo local, pe ferestre de 10 batai -> arata unde accelereaza / incetineste
print("\ntempo local:")
for i in range(0,len(beats)-10,20):
    seg=np.diff(beats[i:i+11])
    print(f"   {beats[i]:6.1f}s  {60/seg.mean():6.2f} BPM")
