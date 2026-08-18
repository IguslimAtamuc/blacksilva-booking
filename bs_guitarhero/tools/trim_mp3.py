"""Taie un mp3 la limita de cadru MPEG, fara re-encodare."""
import sys, struct

BITRATES_V1L3 = [0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,None]
SRATES_V1     = [44100,48000,32000,None]

def skip_id3(b):
    if b[:3]==b'ID3':
        size = ((b[6]&0x7f)<<21)|((b[7]&0x7f)<<14)|((b[8]&0x7f)<<7)|(b[9]&0x7f)
        return 10+size
    return 0

def frames(b, i):
    """genereaza (offset, length, samples_per_frame, samplerate)"""
    n=len(b)
    while i+4 <= n:
        if b[i]!=0xFF or (b[i+1]&0xE0)!=0xE0:
            i+=1; continue
        ver=(b[i+1]>>3)&3      # 3 = MPEG1
        lay=(b[i+1]>>1)&3      # 1 = Layer III
        if ver!=3 or lay!=1: i+=1; continue
        bi=(b[i+2]>>4)&0xF; si=(b[i+2]>>2)&3; pad=(b[i+2]>>1)&1
        br=BITRATES_V1L3[bi]; sr=SRATES_V1[si]
        if not br or not sr: i+=1; continue
        ln = 144*br*1000//sr + pad
        if ln<24: i+=1; continue
        yield i, ln, 1152, sr
        i += ln

def main(src, dst, start, end=None):
    b = open(src,'rb').read()
    i = skip_id3(b)
    kept = bytearray()
    t = 0.0
    first_t = None
    total = 0.0
    for off, ln, spf, sr in frames(b, i):
        dur = spf/sr
        if t >= start and (end is None or t < end):
            if first_t is None: first_t = t
            kept += b[off:off+ln]
            total += dur
        t += dur
    open(dst,'wb').write(bytes(kept))
    print(f"sursa {len(b)/1048576:.2f} MB / {t:.2f}s  ->  {len(kept)/1048576:.2f} MB / {total:.2f}s")
    print(f"primul cadru pastrat incepe la {first_t:.4f}s in sursa")
    return first_t

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]),
         float(sys.argv[4]) if len(sys.argv)>4 else None)
