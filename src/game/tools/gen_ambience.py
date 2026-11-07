"""Gera os sons ambientes do protótipo por síntese (sem licença de terceiros).

Fundos em loop sem emenda (crossfade início/fim) e sons avulsos com muitas variações
(cada pássaro/coruja/grilo/gota sai diferente) — o jogo sorteia posição, tom e volume.

Uso: python src/game/tools/gen_ambience.py
Saída: src/game/audio/*.wav (16 bits, 44,1 kHz, mono)
"""
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "audio"
rng = np.random.default_rng(1234)


def save(name, x, peak_db=-3.0):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * (10 ** (peak_db / 20))
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t_axis(sec):
    return np.arange(int(sec * SR)) / SR


def band(x, lo=None, hi=None, order=2):
    if lo and hi:
        b, a = butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    elif hi:
        b, a = butter(order, hi / (SR / 2), btype="low")
    else:
        b, a = butter(order, lo / (SR / 2), btype="high")
    return lfilter(b, a, x)


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] = np.minimum(e[-r:], np.linspace(1, 0, r))
    return e


def slow_lfo(n, rate, depth, phase=0.0):
    t = np.arange(n) / SR
    return 1.0 - depth * 0.5 * (1 + np.sin(2 * np.pi * rate * t + phase))


def seamless(x, fade=2.0):
    """Loop sem emenda: o fim cruza com o começo."""
    f = int(fade * SR)
    head, body, tail = x[:f], x[f:-f], x[-f:]
    ramp = np.linspace(0, 1, f)
    return np.concatenate([body, tail * (1 - ramp) + head * ramp])


def echo(x, taps=((0.09, 0.35), (0.17, 0.22), (0.31, 0.12))):
    y = np.concatenate([x, np.zeros(int(max(d for d, _ in taps) * SR) + 1)])
    for delay, gain in taps:
        d = int(delay * SR)
        y[d:d + len(x)] += x * gain
    return y


# ------------------------------------------------------------------ fundos
def bed_day():
    n = int(26 * SR)
    wind = band(rng.normal(size=n), hi=700) * slow_lfo(n, 0.07, 0.6) * slow_lfo(n, 0.19, 0.3, 1.0)
    leaves = band(rng.normal(size=n), 2500, 6500) * 0.18 * slow_lfo(n, 0.11, 0.9, 2.0)
    save("bed_day", seamless(wind + leaves), -10)


def bed_night():
    n = int(26 * SR)
    wind = band(rng.normal(size=n), hi=420) * slow_lfo(n, 0.05, 0.5)
    t = np.arange(n) / SR
    wash = np.zeros(n)
    for k in range(9):  # coro distante de grilos, bem baixo
        f = rng.uniform(3900, 5200)
        pulses = (np.sin(2 * np.pi * rng.uniform(2.0, 3.5) * t + k) > 0.6).astype(float)
        wash += np.sin(2 * np.pi * f * t) * band(pulses, hi=60) * 0.03
    save("bed_night", seamless(wind + wash), -12)


def bed_cave():
    n = int(26 * SR)
    rumble = band(rng.normal(size=n), 40, 160) * slow_lfo(n, 0.04, 0.4)
    air = band(rng.normal(size=n), 300, 900) * 0.12 * slow_lfo(n, 0.09, 0.7, 1.3)
    save("bed_cave", seamless(rumble + air), -12)


def water_loop(name, lo, hi, sec, bubbles):
    n = int(sec * SR)
    x = band(rng.normal(size=n), lo, hi) * slow_lfo(n, 0.3, 0.25)
    t = np.arange(n) / SR
    for _ in range(int(bubbles * sec)):  # bolhas/gotas na superfície
        start = rng.integers(0, n - 4000)
        f = rng.uniform(700, 1800)
        k = np.arange(3000) / SR
        x[start:start + 3000] += np.sin(2 * np.pi * (f + 900 * k / 0.07) * k) * np.exp(-k * 45) * 0.25
    save(name, seamless(x, 1.5), -9)


# ------------------------------------------------------------------ pássaros
def bird_trill():
    out = []
    base = rng.uniform(3200, 4600)
    for _ in range(rng.integers(6, 15)):
        d = rng.uniform(0.02, 0.045)
        k = t_axis(d)
        f = base + rng.uniform(-300, 300) + 900 * k / d
        out.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(k), 0.004, 0.012))
        out.append(np.zeros(int(rng.uniform(0.015, 0.04) * SR)))
    return np.concatenate(out)


def bird_whistle():
    out = []
    for _ in range(rng.integers(2, 4)):
        d = rng.uniform(0.15, 0.32)
        k = t_axis(d)
        f0, f1 = rng.uniform(2000, 3600), rng.uniform(2000, 3600)
        f = np.linspace(f0, f1, len(k)) + 25 * np.sin(2 * np.pi * 6 * k)
        out.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(k), 0.03, 0.06))
        out.append(np.zeros(int(rng.uniform(0.05, 0.14) * SR)))
    return np.concatenate(out)


def bird_chirp():
    out = []
    for _ in range(rng.integers(2, 4)):
        d = rng.uniform(0.05, 0.09)
        k = t_axis(d)
        f = np.linspace(rng.uniform(2300, 3000), rng.uniform(4600, 5800), len(k))
        out.append(np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(k), 0.005, 0.03))
        out.append(np.zeros(int(rng.uniform(0.06, 0.2) * SR)))
    return np.concatenate(out)


def bird_warble():
    d = rng.uniform(0.6, 1.3)
    k = t_axis(d)
    f = rng.uniform(2800, 3800) + rng.uniform(500, 900) * np.sin(2 * np.pi * rng.uniform(11, 19) * k + np.sin(2 * np.pi * 3 * k))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(k), 0.04, 0.12)
    return x * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * rng.uniform(5, 9) * k)))


# ------------------------------------------------------------------ noite e gruta
def cricket():
    sec = rng.uniform(6.0, 8.0)
    n = int(sec * SR)
    x = np.zeros(n)
    f = rng.uniform(4200, 5300)
    pos = int(rng.uniform(0.05, 0.3) * SR)
    gap = rng.uniform(0.35, 0.8)
    while pos < n - SR // 4:
        for _ in range(rng.integers(3, 5)):  # pulsos de uma estridulação
            k = t_axis(0.014)
            s = np.sin(2 * np.pi * f * k) * env(len(k), 0.002, 0.006)
            x[pos:pos + len(k)] += s * rng.uniform(0.8, 1.0)
            pos += len(k) + int(0.009 * SR)
        pos += int(gap * rng.uniform(0.85, 1.15) * SR)
    return seamless(x, 0.3)


def owl():
    out = [np.zeros(int(0.1 * SR))]
    f = rng.uniform(360, 500)
    for i in range(rng.integers(2, 5)):
        d = rng.uniform(0.25, 0.55) if i != 1 else rng.uniform(0.12, 0.22)
        k = t_axis(d)
        tone = np.sin(2 * np.pi * np.cumsum(np.linspace(f * 1.04, f * 0.94, len(k))) / SR)
        tone += 0.25 * np.sin(2 * np.pi * np.cumsum(np.linspace(f * 2.08, f * 1.88, len(k))) / SR)
        breath = band(rng.normal(size=len(k)), f * 0.8, f * 2.2) * 0.12
        out.append((tone + breath) * env(len(k), 0.06, 0.12))
        out.append(np.zeros(int(rng.uniform(0.12, 0.35) * SR)))
    return echo(np.concatenate(out), ((0.13, 0.18), (0.29, 0.08)))


def frog():
    out = []
    for _ in range(rng.integers(1, 4)):
        d = rng.uniform(0.25, 0.5)
        k = t_axis(d)
        f = rng.uniform(220, 380)
        pulses = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rng.uniform(16, 26) * k))
        tone = sum(np.sin(2 * np.pi * f * h * k) / h for h in (1, 2, 3, 4))
        out.append(tone * band(pulses, hi=200) * env(len(k), 0.02, 0.06))
        out.append(np.zeros(int(rng.uniform(0.15, 0.45) * SR)))
    return np.concatenate(out)


def drip():
    k = t_axis(0.18)
    f = rng.uniform(1100, 2400)
    tone = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.6 * np.exp(-k * 40))) / SR) * np.exp(-k * 28)
    return echo(tone, ((0.11, 0.4), (0.23, 0.25), (0.41, 0.14), (0.62, 0.07)))


def main():
    bed_day()
    bed_night()
    bed_cave()
    water_loop("water_loop", 300, 2800, 12, 3)
    water_loop("waterfall_loop", 200, 4500, 10, 8)
    kinds = [bird_trill, bird_whistle, bird_chirp, bird_warble]
    for i in range(18):
        save(f"bird_{i:02d}", echo(kinds[i % 4](), ((0.07, 0.12), (0.15, 0.05))), -4)
    for i in range(6):
        save(f"cricket_{i:02d}", cricket(), -6)
        save(f"owl_{i:02d}", owl(), -4)
    for i in range(5):
        save(f"frog_{i:02d}", frog(), -5)
    for i in range(8):
        save(f"drip_{i:02d}", drip(), -5)
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
