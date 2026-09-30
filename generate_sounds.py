"""Generoi kovaääniset herätysäänet assets/sounds-kansioon (WAV, 16-bit mono).

Kaikki äänet ovat 8 sekunnin saumattomia looppeja. Ajo:  python tools/generate_sounds.py
"""
import os
import wave

import numpy as np

SR = 32000
DUR = 8.0
t = np.arange(int(SR * DUR)) / SR
TAU = 2 * np.pi
rng = np.random.default_rng(1)


def phase(freq):
    return TAU * np.cumsum(freq) / SR


def sine(f):
    return np.sin(phase(f))


def square(f):
    return np.sign(np.sin(phase(f)))


def saw(f):
    return 2 * ((phase(f) / TAU) % 1) - 1


def tri(period):
    p = (t % period) / period
    return 1 - np.abs(2 * p - 1)


def smooth(x, ms=2.0):
    n = max(1, int(SR * ms / 1000))
    return np.convolve(x, np.ones(n) / n, mode="same")


def pattern(starts, on, period):
    """Portti: päällä `on` sekuntia jokaisessa `starts`-kohdassa, toistuu `period` välein."""
    tp = t % period
    g = np.zeros_like(t)
    for s in starts:
        g = np.maximum(g, ((tp >= s) & (tp < s + on)).astype(float))
    return smooth(g)


def gate(on, period):
    return pattern([0.0], on, period)


def strike_bell(base, period):
    """Kelloiskut: epäharmoniset osasävelet, nopea vaimeneminen, toistuu `period` välein."""
    n = int(SR * period)
    tt = np.arange(n) / SR
    s = np.zeros(n)
    for ratio, amp in [(1, 1.0), (2.76, 0.7), (5.4, 0.5), (8.93, 0.35)]:
        s += amp * np.sin(TAU * base * ratio * tt)
    s *= np.exp(-tt / (period * 0.45))
    return np.tile(s, int(round(DUR / period)))[: len(t)]


# --- äänet -----------------------------------------------------------------

def siren():
    f = 600 + 900 * tri(2.0)
    return 0.6 * sine(f) + 0.5 * square(f)


def airraid():
    f = 350 + 600 * tri(4.0)
    return saw(f) + 0.4 * square(f * 2)


def yelp():
    f = 600 + 1200 * ((t % 0.25) / 0.25)
    return 0.6 * sine(f) + 0.6 * square(f)


def klaxon():
    f = np.where((t % 0.8) < 0.4, 440.0, 330.0)
    return square(f) + 0.6 * saw(f * 1.01)


def digital_beeps():
    return sine(np.full_like(t, 2800)) * pattern([0, 0.15, 0.30, 0.45], 0.08, 1.0) \
        + 0.5 * square(np.full_like(t, 2800)) * pattern([0, 0.15, 0.30, 0.45], 0.08, 1.0)


def fire_alarm():
    g = pattern([0, 1, 2], 0.5, 4.0)
    f = np.full_like(t, 2900)
    return (square(f) + 0.5 * sine(f * 2)) * g


def smoke_detector():
    g = pattern([i * 0.2 for i in range(5)], 0.1, 2.0)
    f = np.full_like(t, 3100)
    return (square(f) + sine(f)) * g


def bell():
    return strike_bell(1200, 0.125) * gate(0.75, 1.0)


def retro_clock():
    f1, f2 = np.full_like(t, 1500), np.full_like(t, 2050)
    clapper = pattern([0], 0.025, 0.05)
    return (sine(f1) + sine(f2) + 0.4 * square(f1)) * clapper * gate(1.4, 2.0)


def buzzer():
    am = 0.6 + 0.4 * square(np.full_like(t, 4))
    return (saw(np.full_like(t, 120)) + saw(np.full_like(t, 123)) + 0.5 * square(np.full_like(t, 240))) * am


def foghorn():
    vib = 98 + 1.5 * np.sin(TAU * 0.5 * t)
    s = sum(a * sine(vib * k) for k, a in [(1, 1.0), (2, 0.9), (3, 0.7), (4, 0.5), (5, 0.3)])
    return s * gate(2.5, 4.0)


def aooga():
    p = (t % 2.0) / 2.0
    f = np.where(p < 0.5, 200 + 600 * (p / 0.5) ** 0.7, 800 - 500 * np.clip((p - 0.5) / 0.15, 0, 1) * (p < 0.65))
    f = np.where(p >= 0.65, 300, f)
    return (saw(f) + 0.6 * square(f * 0.5)) * gate(1.6, 2.0)


def laser():
    p = t % 0.25
    f = 200 + 2800 * np.exp(-p * 14)
    return square(f) + 0.5 * saw(f * 1.5)


def noise_bursts():
    n = rng.uniform(-1, 1, len(t))
    g = pattern([0], 0.15, 0.25)
    return (n * 0.9 + square(np.full_like(t, 1000)) * 0.7) * g


def red_alert():
    p = (t % 1.0)
    f = np.where(p < 0.7, 700 + 900 * (p / 0.7), 700)
    return (sine(f) + 0.7 * square(f)) * gate(0.7, 1.0)


def wobble():
    f = 55 + 35 * np.sin(TAU * 3 * t)
    low = saw(f) + 0.8 * square(f * 2)
    high = saw(880 + 440 * np.sin(TAU * 3 * t)) * 0.5
    return np.tanh(3 * (low + high))


def eas_tone():
    return sine(np.full_like(t, 853)) + sine(np.full_like(t, 960))


def sos():
    dot, dash, gap = 0.15, 0.45, 0.15
    starts, cur = [], 0.0
    for d in [dot] * 3 + [dash] * 3 + [dot] * 3:
        starts.append((cur, d))
        cur += d + gap
    g = np.zeros_like(t)
    tp = t % 4.0
    for s, d in starts:
        g = np.maximum(g, ((tp >= s) & (tp < s + d)).astype(float))
    g = smooth(g)
    f = np.full_like(t, 1500)
    return (square(f) + 0.5 * sine(f)) * g


def whistle():
    f = 3300 + 400 * np.sin(TAU * 25 * t)
    return (sine(f) + 0.4 * sine(f * 2)) * gate(0.6, 0.8)


def screaming_saws():
    s = np.zeros_like(t)
    for base in (220, 277.2, 329.6, 440):
        for det in (-1.006, 1.0, 1.006):
            s += saw(np.full_like(t, base * det))
    pump = 0.4 + 0.6 * tri(0.5)
    return s * pump


def mega_mix():
    return 0.9 * yelp() + 0.7 * klaxon() + 0.6 * digital_beeps() + 0.4 * wobble()


SOUNDS = {
    "siren": siren, "air_raid": airraid, "yelp": yelp, "klaxon": klaxon,
    "beeps": digital_beeps, "fire_alarm": fire_alarm, "smoke_detector": smoke_detector,
    "bell": bell, "retro_clock": retro_clock, "buzzer": buzzer, "foghorn": foghorn,
    "aooga": aooga, "laser": laser, "noise_bursts": noise_bursts, "red_alert": red_alert,
    "wobble": wobble, "eas_tone": eas_tone, "sos": sos, "whistle": whistle,
    "screaming_saws": screaming_saws, "mega_mix": mega_mix,
}


def loudify(x):
    x = x / np.max(np.abs(x))
    x = np.tanh(2.4 * x) / np.tanh(2.4)  # pehmeä leikkaus nostaa RMS:n (kuulostaa kovemmalta)
    return x / np.max(np.abs(x)) * 0.99


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        y = loudify(fn())
        pcm = (y * 32767).astype("<i2")
        path = os.path.join(out, f"{name}.wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        rms = float(np.sqrt(np.mean(y ** 2)))
        print(f"{name:16s} rms={rms:.2f}  {os.path.getsize(path) // 1024} KB")


if __name__ == "__main__":
    main()
