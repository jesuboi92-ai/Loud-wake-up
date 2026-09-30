"""Generoi luonteeltaan erilaisia herätysääniä (huuto, karjunta, raapiminen, eläimet,
räjähdykset, koneet, soittimet). Tulos: assets/sounds/c_*.wav + assets/sounds/characters.json

Kaikki on syntetisoitu (formanttisuodatus, stick-slip-kohina, inharmoniset osasävelet),
joten kyseessä ovat tyylitellyt, ei äänitetyt äänet.

Ajo:  python tools/generate_characters.py [määrä]     (oletus 145)
Vaatii: numpy, scipy
"""
import json
import os
import sys
import wave

import numpy as np
from scipy.signal import butter, lfilter

from generate_variants import (  # noqa: E402  (samat apufunktiot, 4 s looppi)
    LOOP, SR, TAU, const, gate, phase, ramp, saw, sine, smooth, square, t, tri,
)

rng = np.random.default_rng(777)
N = len(t)


def choice(seq):
    return seq[int(rng.integers(len(seq)))]


def uni(a, b):
    return float(rng.uniform(a, b))


# --- suodattimet ------------------------------------------------------------

def bandpass(x, f0, q):
    f0 = min(f0, SR * 0.45)
    w0 = TAU * f0 / SR
    alpha = np.sin(w0) / (2 * q)
    return lfilter([alpha, 0, -alpha], [1 + alpha, -2 * np.cos(w0), 1 - alpha], x)


def lowpass(x, fc, order=2):
    b, a = butter(order, fc / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, fc, order=2):
    b, a = butter(order, fc / (SR / 2), btype="high")
    return lfilter(b, a, x)


VOWELS = {
    "a": (800, 1300, 2700), "e": (500, 1800, 2600), "i": (300, 2200, 3000),
    "o": (500, 900, 2400), "u": (320, 800, 2300), "ae": (700, 1650, 2700),
}


def formants(src, vowel, scale=1.0):
    fs = VOWELS[vowel] if isinstance(vowel, str) else vowel
    out = np.zeros_like(src)
    for f, bw, g in zip(fs, (90, 110, 170), (1.0, 0.7, 0.4)):
        f = f * scale
        out += g * bandpass(src, f, max(2.0, f / bw))
    return out


def lp_noise(fc):
    return lowpass(rng.uniform(-1, 1, N), fc)


def voice_source(f0, rough=0.0, rough_hz=70, breath=0.1, jitter=0.01):
    jit = 1 + jitter * lp_noise(30) * 8
    src = saw(f0 * jit)
    if rough:
        src *= 1 + rough * square(const(rough_hz))
    return src + breath * rng.uniform(-1, 1, N)


def place(out, sig, start_s):
    """Lisää tapahtuma kohtaan start_s; häntä kiertyy loopin alkuun (saumaton)."""
    i = int(start_s * SR) % N
    idx = (np.arange(len(sig)) + i) % N
    np.add.at(out, idx, sig)


def hits(n, jitter=0.0):
    """n tapahtumaa tasavälein loopissa (hieman satunnaistettuna)."""
    return [(k + uni(-jitter, jitter)) * LOOP / n for k in range(n)]


# --- äänet: ääni ------------------------------------------------------------

def scream():
    n = choice([1, 2, 3])
    p = ramp(n)
    base = uni(520, 950)
    f0 = base * (0.75 + 0.5 * np.sin(np.pi * p) ** 0.6) * (1 + 0.03 * np.sin(TAU * 6 * t))
    src = voice_source(f0, rough=uni(0.3, 0.7), rough_hz=choice([55, 70, 90]), breath=0.25)
    s = formants(src, "a", uni(1.0, 1.3))
    return s * gate(n, 0.85)


def growl():
    n = choice([1, 2, 4])
    base = uni(65, 140)
    f0 = base * (1 + 0.25 * tri(n))
    src = voice_source(f0, rough=uni(0.6, 0.95), rough_hz=choice([28, 35, 45]), breath=0.45, jitter=0.03)
    s = formants(src, choice(["a", "o", "u"]), uni(0.8, 1.0))
    return np.tanh(2.5 * s / (np.max(np.abs(s)) + 1e-9)) * gate(n, 0.8)


def evil_laugh():
    n = choice([6, 8, 10, 12])
    f0 = uni(180, 420) * (1 - 0.3 * (t / LOOP)) * (1 + 0.06 * np.sin(TAU * n / LOOP * t + 1.5))
    src = voice_source(f0, rough=0.25, breath=0.3)
    s = formants(src, choice(["a", "ae", "o"]), uni(0.9, 1.15))
    return s * gate(n, 0.5)


def howl():
    n = choice([1, 2])
    p = ramp(n)
    base = uni(260, 450)
    f0 = base * (0.85 + 0.7 * np.sin(np.pi * p)) * (1 + 0.03 * np.sin(TAU * 5 * t))
    s = formants(voice_source(f0, breath=0.12), choice(["o", "u"]), uni(0.95, 1.2))
    return s * gate(n, 0.92)


# --- eläimet -------------------------------------------------------------

def meow():
    n = choice([2, 3, 4])
    p = ramp(n)
    base = uni(420, 650)
    f0 = base * (0.85 + 0.6 * np.sin(np.pi * p) ** 0.7) * (1 + 0.02 * np.sin(TAU * 7 * t))
    s = formants(voice_source(f0, breath=0.15), "ae", uni(0.95, 1.3))
    return s * gate(n, 0.6)


def rooster():
    out = np.zeros(N)
    t0 = uni(0.0, 0.8)
    syl = [(0.25, 500, 900), (0.55, 750, 1150), (0.75, 950, 550)]
    cur = t0
    for dur, a, b in syl:
        m = int(dur * SR)
        tt = np.arange(m) / m
        f0 = a + (b - a) * tt + 40 * np.sin(TAU * 12 * tt)
        src = voice_source_local(f0)
        s = formants(src, "a", uni(1.0, 1.15)) * np.sin(np.pi * np.clip(tt, 0, 1)) ** 0.5
        place(out, s, cur)
        cur += dur + 0.06
    reps = choice([1, 1, 2])
    if reps == 2:
        out = out + np.roll(out, int(2.0 * SR))
    return out


def voice_source_local(f0):
    ph = TAU * np.cumsum(f0) / SR
    s = 2 * ((ph / TAU) % 1) - 1
    s *= 1 + 0.4 * np.sign(np.sin(TAU * 80 * np.arange(len(f0)) / SR))
    return s + 0.15 * rng.uniform(-1, 1, len(f0))


def bark():
    n = choice([4, 6, 8])
    out = np.zeros(N)
    dur = uni(0.14, 0.22)
    m = int(dur * SR)
    tt = np.arange(m) / m
    for st in hits(n):
        f0 = uni(300, 480) * (1.15 - 0.45 * tt)
        s = formants(voice_source_local(f0), choice(["a", "o", "ae"]), 1.0) * np.exp(-tt * 4)
        s += 0.4 * lowpass(rng.uniform(-1, 1, m), 3000) * np.exp(-tt * 10)
        place(out, s, st)
    return out


def goose():
    n = choice([3, 4, 6])
    f0 = uni(300, 450) * (1 + 0.15 * np.sin(TAU * n / LOOP * t))
    src = voice_source(f0, rough=0.6, rough_hz=choice([80, 100]), breath=0.3)
    s = formants(src, (520, 1500, 2500), uni(0.9, 1.1))
    return s * gate(n, 0.45)


def crow():
    n = choice([3, 4, 5])
    p = ramp(n)
    f0 = uni(420, 560) * (1.15 - 0.45 * p)
    src = voice_source(f0, rough=0.7, rough_hz=choice([90, 110]), breath=0.35)
    return formants(src, (900, 1350, 2600), uni(0.95, 1.1)) * gate(n, 0.5)


# --- raapivat ja kirskuvat -------------------------------------------------

def chalk():
    n = choice([2, 3, 4])
    f0 = uni(35, 90) * (1 + 0.4 * tri(n))
    src = saw(f0)
    s = bandpass(src, uni(2200, 4200), uni(18, 40)) + 0.6 * bandpass(src, uni(4500, 7000), 25)
    s += 0.1 * highpass(rng.uniform(-1, 1, N), 4000)
    return s * gate(n, uni(0.5, 0.75))


def metal_screech():
    base = uni(1200, 2500)
    drift = 1 + 0.15 * np.sin(TAU * choice([1, 2]) / LOOP * t)
    s = sum(a * saw(base * r * drift) for r, a in [(1, 1.0), (1.5, 0.7), (2.02, 0.6), (2.51, 0.4)])
    s *= 0.5 + 0.5 * smooth(np.sign(np.sin(phase(const(choice([25, 35, 50]))))), 4)
    s += 0.2 * highpass(rng.uniform(-1, 1, N), 3000)
    return s * gate(choice([2, 4]), 0.8)


def glass_squeal():
    base = uni(1500, 3500)
    walk = 1 + 0.03 * lp_noise(6) * 6
    f = base * walk * (1 + 0.05 * np.sin(TAU * choice([3, 5]) * t / LOOP * 4))
    s = sine(f) + 0.5 * sine(f * 2) + 0.3 * sine(f * 3)
    s += 0.05 * rng.uniform(-1, 1, N)
    return s * (0.4 + 0.6 * tri(choice([2, 4, 8])))


def feedback():
    n = choice([1, 2, 4])
    lo = uni(500, 1200)
    hi = lo * uni(2.0, 4.0)
    f = lo * (hi / lo) ** ramp(n)
    s = sine(f) + 0.5 * sine(f * 0.5)
    return np.tanh(uni(5, 12) * s)


def drill():
    n = choice([2, 4, 8])
    am = 0.5 + 0.5 * smooth(np.sign(np.sin(phase(const(choice([150, 200, 250]))))), 1)
    s = bandpass(rng.uniform(-1, 1, N), uni(4000, 6500), 6) * 2 + 0.5 * sine(const(uni(3000, 5000)))
    return s * am * gate(n, 0.7)


def chainsaw():
    n = choice([1, 2])
    f0 = uni(60, 110) * (1 + 0.5 * tri(n))
    fm = f0 * (1 + 0.05 * np.sin(TAU * 12 * t))
    s = saw(fm) + 0.7 * square(fm * 2.01) + 0.3 * lp_noise(3000) * 3
    s = lowpass(s, 4000)
    return np.tanh(2 * s / (np.max(np.abs(s)) + 1e-9))


# --- iskut ja räjähdykset -----------------------------------------------------

def glass_shatter():
    k = choice([4, 6, 8])
    out = np.zeros(N)
    for st in hits(k, 0.15):
        m = int(0.9 * SR)
        tt = np.arange(m) / SR
        s = highpass(rng.uniform(-1, 1, m), 2500) * np.exp(-tt * 14)
        for _ in range(8):
            f = uni(2500, 9000)
            s += 0.25 * np.sin(TAU * f * tt) * np.exp(-tt * uni(6, 14))
        place(out, s, st)
    return out


def explosion():
    k = choice([2, 3, 4])
    out = np.zeros(N)
    for st in hits(k):
        m = int(1.6 * SR)
        tt = np.arange(m) / SR
        s = lowpass(rng.uniform(-1, 1, m), uni(300, 1200)) * np.exp(-tt * uni(2.5, 5))
        s += 1.2 * np.sin(TAU * uni(35, 60) * tt) * np.exp(-tt * 3)
        s += 0.8 * rng.uniform(-1, 1, m) * np.exp(-tt * 40)
        place(out, s, st)
    return out


def thunder():
    env = 0.25 + 0.75 * np.clip(tri(choice([1, 2])) + 0.5 * lp_noise(3) * 4, 0, 1)
    s = lowpass(rng.uniform(-1, 1, N), uni(120, 300), 3) * env
    return s + 0.5 * sine(const(uni(35, 55))) * env


def thud():
    n = choice([2, 4, 8])
    out = np.zeros(N)
    m = int(0.35 * SR)
    tt = np.arange(m) / SR
    for st in hits(n):
        f = 45 + 90 * np.exp(-tt * 25)
        s = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-tt * 9)
        s += 0.7 * lowpass(rng.uniform(-1, 1, m), 1500) * np.exp(-tt * 60)
        place(out, s, st)
    return out


def clang():
    n = choice([2, 4, 6])
    base = uni(300, 900)
    ratios = sorted(uni(1, 7) for _ in range(6))
    out = np.zeros(N)
    m = int(0.9 * SR)
    tt = np.arange(m) / SR
    for st in hits(n):
        s = sum(np.sin(TAU * base * r * tt) * np.exp(-tt * uni(4, 10)) for r in ratios)
        s += 0.4 * rng.uniform(-1, 1, m) * np.exp(-tt * 50)
        place(out, s, st)
    return out


# --- koneet ja hälyttimet ------------------------------------------------

def car_alarm():
    blocks = []
    for _ in range(4):
        m = SR
        tt = np.arange(m) / m
        kind = choice(["up", "down", "beeps", "two"])
        if kind == "up":
            f = 600 + 900 * tt
        elif kind == "down":
            f = 1500 - 900 * tt
        elif kind == "two":
            f = np.where(tt < 0.5, 900.0, 1300.0)
        else:
            f = np.full(m, 1100.0)
        ph = TAU * np.cumsum(f) / SR
        s = np.sign(np.sin(ph)) + 0.4 * np.sin(ph * 2)
        if kind == "beeps":
            s = s * (np.sin(TAU * 8 * tt) > 0)
        blocks.append(s)
    return np.concatenate(blocks)[:N]


def old_phone():
    f1, f2 = choice([(440, 480), (420, 520), (500, 640), (660, 880)])
    am = 0.5 + 0.5 * np.sign(np.sin(phase(const(choice([20, 25, 30])))))
    s = (sine(const(f1)) + sine(const(f2))) * am
    return s * pattern_ring()


def pattern_ring():
    p = (t % 2.0)
    return smooth(((p < 0.4) | ((p >= 0.6) & (p < 1.0))).astype(float))


def modem():
    tones = [980, 1180, 1300, 1650, 1800, 2100, 2225, 2400, 2750]
    parts, total = [], 0
    while total < N:
        m = int(uni(0.05, 0.22) * SR)
        if rng.random() < 0.25:
            parts.append(rng.uniform(-1, 1, m) * 0.6)
        else:
            f = choice(tones)
            parts.append(np.sin(TAU * f * np.arange(m) / SR) + 0.3 * np.sin(TAU * 2 * f * np.arange(m) / SR))
        total += m
    return np.concatenate(parts)[:N]


def helicopter():
    rate = choice([10, 14, 18]) * LOOP
    p = (t * rate / LOOP) % 1
    thump = np.exp(-p * 9)
    s = lowpass(rng.uniform(-1, 1, N), 600) * thump * 3 + 0.6 * sine(const(uni(60, 90))) * thump
    return s + 0.15 * lp_noise(2000)


def dive_siren():
    n = choice([1, 2])
    p = ramp(n)
    f = 2200 * np.exp(-p * uni(1.4, 2.2)) + 200
    s = saw(f) + 0.5 * square(f * 0.5)
    s += (0.2 + 0.6 * p) * rng.uniform(-1, 1, N)
    return s


# --- soittimet ------------------------------------------------------------

def fanfare():
    notes = choice([[262, 330, 392, 523], [294, 370, 440, 587], [196, 262, 330, 392, 523]])
    rate = choice([4, 6, 8])
    idx = np.floor(ramp(rate) * 1).astype(int)
    seq = [notes[(i * 1) % len(notes)] for i in range(rate)]
    f = np.repeat(np.array(seq, float), int(np.ceil(N / rate)))[:N]
    s = saw(f) + 0.5 * saw(f * 2.005)
    s = lowpass(s, 2800)
    env = 0.4 + 0.6 * np.clip(1 - ramp(rate) * 0.8, 0, 1)
    return s * env * gate(rate, 0.85)


def organ_cluster():
    root = uni(110, 260)
    s = np.zeros(N)
    for r in choice([[1, 1.0595, 1.122], [1, 1.0595, 1.5], [1, 1.414, 1.5]]):
        for h, a in [(1, 1.0), (2, 0.6), (3, 0.5), (4, 0.35), (6, 0.25), (8, 0.2)]:
            s += a * sine(const(root * r * h))
    trem = 0.7 + 0.3 * np.sin(TAU * choice([4, 6, 8]) * t)
    return s * trem * (0.5 + 0.5 * tri(choice([1, 2])))


def cowbell():
    base = uni(0.8, 1.2)
    grid = 16
    pat = [1 if rng.random() < 0.6 else 0 for _ in range(grid)]
    pat[0] = 1
    out = np.zeros(N)
    m = int(0.25 * SR)
    tt = np.arange(m) / SR
    hit = (np.sin(TAU * 560 * base * tt) + np.sin(TAU * 845 * base * tt) * 0.9) * np.exp(-tt * 18)
    for i, on in enumerate(pat):
        if on:
            place(out, hit, i * LOOP / grid)
    return out * 1.5


def gong():
    k = choice([1, 2])
    base = uni(90, 200)
    ratios = [1, 1.47, 2.09, 2.56, 3.33, 4.21]
    out = np.zeros(N)
    m = int(3.0 * SR)
    tt = np.arange(m) / SR
    for st in hits(k):
        s = sum(a * np.sin(TAU * base * r * tt) * np.exp(-tt * d)
                for r, a, d in zip(ratios, [1, 0.8, 0.7, 0.5, 0.4, 0.3], [0.8, 1.1, 1.5, 2, 2.6, 3.2]))
        s *= 1 + 0.15 * np.sin(TAU * 4 * tt)
        place(out, s, st)
    return out


FAMILIES = [
    ("Kauhuhuuto", "voice", scream), ("Karjunta", "voice", growl),
    ("Paha nauru", "voice", evil_laugh), ("Ulvonta", "voice", howl),
    ("Kissan naukuna", "animal", meow), ("Kukonlaulu", "animal", rooster),
    ("Haukunta", "animal", bark), ("Hanhen töräytys", "animal", goose), ("Variksen raakunta", "animal", crow),
    ("Liitutaulun raapaisu", "scrape", chalk), ("Metallin kirskunta", "scrape", metal_screech),
    ("Lasin vinkuna", "scrape", glass_squeal), ("Mikin kierto", "scrape", feedback),
    ("Hammasporan kiljunta", "scrape", drill), ("Moottorisaha", "scrape", chainsaw),
    ("Lasin särkyminen", "impact", glass_shatter), ("Räjähdys", "impact", explosion),
    ("Ukkonen", "impact", thunder), ("Jymähdys", "impact", thud), ("Metallin kalina", "impact", clang),
    ("Autohälytin", "machine", car_alarm), ("Vanha puhelin", "machine", old_phone),
    ("Modeemi", "machine", modem), ("Helikopteri", "machine", helicopter), ("Syöksypommittaja", "machine", dive_siren),
    ("Torvifanfaari", "music", fanfare), ("Urkuklusteri", "music", organ_cluster),
    ("Lehmänkello", "music", cowbell), ("Gongi", "music", gong),
]


def loudify(x, target_rms=0.35):
    """Tasaa voimakkuuden RMS:n mukaan ja rajoittaa huiput pehmeästi: harvat, terävät
    tapahtumat (räjähdys, haukunta) eivät jää hiljaisiksi."""
    x = x - np.mean(x)
    x = x / (np.sqrt(np.mean(x ** 2)) + 1e-9) * target_rms
    x = np.tanh(2.2 * x) / np.tanh(2.2)
    return x / np.max(np.abs(x)) * 0.99


def slug(s):
    for a, b in (("ä", "a"), ("ö", "o"), ("å", "a"), (" ", "_")):
        s = s.lower().replace(a, b)
    return s


def main():
    total = int(sys.argv[1]) if len(sys.argv) > 1 else 145
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
    os.makedirs(out, exist_ok=True)
    counts = {n: 0 for n, _, _ in FAMILIES}
    manifest = []
    for i in range(total):
        name, cat, fn = FAMILIES[i % len(FAMILIES)]
        counts[name] += 1
        y = np.nan_to_num(fn()[:N])
        if len(y) < N:
            y = np.pad(y, (0, N - len(y)))
        if np.max(np.abs(y)) < 1e-6:
            raise SystemExit(f"{name}: hiljainen ääni")
        y = loudify(y)
        sid = f"c_{cat}_{slug(name)}_{counts[name]:02d}"
        with wave.open(os.path.join(out, f"{sid}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((y * 32767).astype("<i2").tobytes())
        manifest.append({"id": sid, "name": f"{name} {counts[name]}", "category": cat})
    with open(os.path.join(out, "characters.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=0)
    mb = sum(os.path.getsize(os.path.join(out, f"{m['id']}.wav")) for m in manifest) / 1e6
    print(f"{len(manifest)} luonne-ääntä, {mb:.1f} MB")


if __name__ == "__main__":
    main()
