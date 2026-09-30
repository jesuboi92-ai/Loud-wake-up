"""Generoi satoja kovaääniisiä herätysääni-variantteja (4 s saumattomia looppeja).

Jokainen variantti on oman perheensä sisällä satunnaisesti parametrisoitu (sävelkorkeus,
tahti, aaltomuoto, kuvio). Tulos: assets/sounds/v_*.wav + assets/sounds/variants.json

Ajo:  python tools/generate_variants.py [määrä]     (oletus 271 -> yhteensä 300 äänen kanssa)
"""
import json
import os
import sys
import wave

import numpy as np

SR = 22050
LOOP = 4.0
t = np.arange(int(SR * LOOP)) / SR
TAU = 2 * np.pi
rng = np.random.default_rng(2024)


def phase(f):
    return TAU * np.cumsum(f) / SR


def const(f):
    return np.full_like(t, float(f))


def sine(f):
    return np.sin(phase(f))


def square(f):
    return np.sign(np.sin(phase(f)))


def saw(f):
    return 2 * ((phase(f) / TAU) % 1) - 1


def wave_mix(f, w):
    """w: 0=sini, 1=neliö, 2=saha, 3=sekoitus."""
    if w == 0:
        return sine(f) + 0.4 * sine(f * 2)
    if w == 1:
        return square(f)
    if w == 2:
        return saw(f)
    return 0.6 * sine(f) + 0.6 * square(f) + 0.3 * saw(f * 1.01)


def tri(n):
    p = (t * n / LOOP) % 1
    return 1 - np.abs(2 * p - 1)


def ramp(n):
    return (t * n / LOOP) % 1


def smooth(x, ms=2.0):
    k = max(1, int(SR * ms / 1000))
    return np.convolve(x, np.ones(k) / k, mode="same")


def gate(n, duty, offset=0.0):
    p = ((t * n / LOOP) + offset) % 1
    return smooth((p < duty).astype(float))


def choice(seq):
    return seq[int(rng.integers(len(seq)))]


# --- perheet: (nimi, funktio) ----------------------------------------------

def f_siren():
    lo = rng.uniform(300, 900)
    hi = lo * rng.uniform(1.6, 3.2)
    f = lo + (hi - lo) * tri(choice([1, 2, 4, 8]))
    return wave_mix(f, choice([0, 1, 2, 3]))


def f_yelp():
    lo = rng.uniform(400, 1000)
    hi = lo * rng.uniform(1.8, 3.5)
    r = ramp(choice([4, 8, 12, 16, 20]))
    if rng.random() < 0.5:
        r = 1 - r
    return wave_mix(lo + (hi - lo) * r, choice([0, 1, 2, 3]))


def f_twotone():
    fa = rng.uniform(300, 1400)
    fb = fa * choice([0.75, 1.25, 1.33, 1.5, 2.0])
    n = choice([2, 4, 8, 10, 16])
    f = np.where(((t * n / LOOP) % 1) < 0.5, fa, fb)
    return wave_mix(f, choice([1, 2, 3]))


def f_beeps():
    f = rng.uniform(1000, 4200)
    n = choice([4, 6, 8, 12, 16, 24])
    s = wave_mix(const(f), choice([0, 1, 3]))
    return s * gate(n, rng.uniform(0.3, 0.6))


def f_burst():
    f = rng.uniform(900, 3800)
    groups = choice([1, 2, 4])
    k = choice([2, 3, 4, 5])
    n = groups * 8
    p = ((t * n / LOOP) % 1)
    g = smooth(((p < 0.5) & ((np.floor(t * n / LOOP) % 8) < k)).astype(float))
    return wave_mix(const(f), choice([0, 1, 3])) * g


def f_wobble():
    base = rng.uniform(40, 200)
    rate = choice([1, 2, 3, 4, 6, 8]) / LOOP * choice([1, 2])
    rate = round(rate * LOOP) / LOOP  # kokonaislukua jaksoja looppiin
    f = base + base * rng.uniform(0.3, 1.2) * np.sin(TAU * rate * t)
    s = saw(f) + 0.7 * square(f * 2) + 0.4 * saw(f * 4 * 1.003)
    return np.tanh(rng.uniform(2, 5) * s)


def f_laser():
    n = choice([4, 8, 12, 16, 24])
    f0 = rng.uniform(1500, 4000)
    p = ((t * n / LOOP) % 1)
    f = 150 + f0 * np.exp(-p * rng.uniform(6, 16))
    return wave_mix(f, choice([1, 2, 3]))


def f_chord():
    root = rng.uniform(110, 330)
    ints = choice([[1, 1.25, 1.5], [1, 1.2, 1.5], [1, 1.5, 2], [1, 1.33, 1.78], [1, 1.12, 1.5]])
    s = np.zeros_like(t)
    for r in ints:
        for det in (0.994, 1.0, 1.006):
            s += saw(const(root * r * det))
    pump = 0.35 + 0.65 * tri(choice([2, 4, 8, 16]))
    return s * pump


def f_arcade():
    scale = choice([[523, 659, 784, 988, 1319, 1568], [440, 554, 659, 880, 1109, 1319, 1760],
                    [392, 523, 659, 784, 1047, 1319, 1568, 2093], [659, 988, 1319, 1976, 2637, 3136]])
    rate = choice([8, 12, 16, 24])
    steps = rng.choice(scale, size=int(LOOP * rate))
    f = np.repeat(steps, int(np.ceil(len(t) / len(steps))))[: len(t)].astype(float)
    return wave_mix(f, choice([1, 2, 3])) * (0.6 + 0.4 * gate(rate, 0.8))


def f_bell():
    n = choice([8, 16, 24, 32])
    base = rng.uniform(600, 2200)
    period = LOOP / n
    m = int(SR * period)
    tt = np.arange(m) / SR
    s = np.zeros(m)
    for ratio, amp in [(1, 1.0), (2.76, 0.7), (5.4, 0.5), (8.93, 0.35)]:
        s += amp * np.sin(TAU * base * ratio * tt)
    s *= np.exp(-tt / (period * rng.uniform(0.3, 0.7)))
    out = np.tile(s, n)
    out = np.concatenate([out, np.zeros(len(t) - len(out))])[: len(t)]
    return out * gate(choice([2, 4]), rng.uniform(0.6, 0.9))


def f_horn():
    f0 = rng.uniform(70, 220)
    amps = [(1, 1.0), (2, rng.uniform(0.5, 1)), (3, rng.uniform(0.3, 0.9)), (4, 0.5), (5, 0.3), (6, 0.2)]
    s = sum(a * sine(const(f0 * k)) for k, a in amps)
    return s * gate(choice([1, 2, 4]), rng.uniform(0.5, 0.8))


def f_stairs():
    k = choice([4, 5, 6, 8])
    n = choice([1, 2, 4])
    lo = rng.uniform(300, 700)
    mult = rng.uniform(1.15, 1.35)
    idx = np.floor(ramp(n) * k)
    f = lo * mult ** idx
    return wave_mix(f, choice([1, 2, 3])) * (0.7 + 0.3 * gate(n * k, 0.85))


def f_dual():
    f1 = rng.uniform(500, 2500)
    f2 = f1 * choice([1.12, 1.26, 1.5, 1.125, 1.067])
    am = 0.5 + 0.5 * gate(choice([2, 4, 8, 16]), 0.5)
    return (sine(const(f1)) + sine(const(f2)) + 0.3 * square(const(f1))) * am


def f_noise():
    n = choice([4, 8, 12, 16])
    tone = rng.uniform(600, 2400)
    g = gate(n, rng.uniform(0.3, 0.6))
    noise = rng.uniform(-1, 1, len(t))
    return (noise * rng.uniform(0.6, 1.0) + square(const(tone)) * 0.7) * g


FAMILIES = [
    ("Sireeni", "sirens", f_siren), ("Yelp", "sirens", f_yelp), ("Kaksisävel", "sirens", f_twotone),
    ("Piippaus", "beeps", f_beeps), ("Piippausryhmä", "beeps", f_burst), ("Portaat", "beeps", f_stairs),
    ("Wobble", "heavy", f_wobble), ("Sointusaha", "heavy", f_chord), ("Torvi", "heavy", f_horn),
    ("Laser", "weird", f_laser), ("Arcade", "weird", f_arcade), ("Kaksoisääni", "weird", f_dual),
    ("Kohinapurske", "weird", f_noise), ("Kellot", "bells", f_bell),
]


def loudify(x):
    x = x / np.max(np.abs(x))
    x = np.tanh(2.4 * x) / np.tanh(2.4)
    return x / np.max(np.abs(x)) * 0.99


def main():
    total = int(sys.argv[1]) if len(sys.argv) > 1 else 271
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
    os.makedirs(out, exist_ok=True)
    counts = {name: 0 for name, _, _ in FAMILIES}
    manifest = []
    for i in range(total):
        name, cat, fn = FAMILIES[i % len(FAMILIES)]
        counts[name] += 1
        sid = f"v_{cat}_{name.lower().replace('ä', 'a').replace('ö', 'o')}_{counts[name]:02d}"
        y = loudify(fn())
        with wave.open(os.path.join(out, f"{sid}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((y * 32767).astype("<i2").tobytes())
        manifest.append({"id": sid, "name": f"{name} {counts[name]}", "category": cat})
    with open(os.path.join(out, "variants.json"), "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=0)
    mb = sum(os.path.getsize(os.path.join(out, f"{m['id']}.wav")) for m in manifest) / 1e6
    print(f"{len(manifest)} varianttia, {mb:.1f} MB")


if __name__ == "__main__":
    main()
