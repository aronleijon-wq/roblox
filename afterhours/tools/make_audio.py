#!/usr/bin/env python3
"""Genererar AFTERHOURS ljud (syntes, inga samplingar) till assets/audio/*.ogg.

Kör från mappen afterhours/:  python3 tools/make_audio.py
Kräver numpy och ffmpeg (med libvorbis).

Loopande ljud filtreras i frekvensdomänen (cirkulärt), så att början och slut
passar ihop utan klick när Roblox loopar dem.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(30003)


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def spectral(signal, curve):
    """Filtrera med en kurva över frekvens (Hz -> förstärkning). Cirkulärt = loopbart."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    return np.fft.irfft(spectrum * curve(freqs), len(signal))


def lowpass(signal, cutoff, order=2):
    return spectral(signal, lambda f: 1 / np.sqrt(1 + (f / cutoff) ** (2 * order)))


def highpass(signal, cutoff, order=2):
    return spectral(signal, lambda f: 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(signal, low, high):
    return highpass(lowpass(signal, high), low)


def noise(seconds):
    return rng.standard_normal(len(t(seconds)))


def envelope(n, attack, release, curve=3.0):
    env = np.ones(n)
    a = int(attack * RATE)
    r = int(release * RATE)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if r > 0:
        env[-r:] *= np.linspace(1, 0, r) ** curve
    return env


def decay(seconds, rate):
    return np.exp(-t(seconds) * rate)


def normalize(signal, peak=0.89):
    m = np.max(np.abs(signal))
    return signal * (peak / m) if m > 0 else signal


def write(name, signal, peak=0.89):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(normalize(signal, peak), -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    target = os.path.join(OUT, name)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "5", target],
        check=True,
    )
    os.remove(path)
    print(f"{name:22s} {len(signal) / RATE:5.2f} s")


def tone(freq, seconds, phase=0.0):
    return np.sin(2 * np.pi * freq * t(seconds) + phase)


# Bakgrund ------------------------------------------------------------------------------


def city_ambience():
    # Stadens sus: brunt brus, avlägsen trafik som sveper förbi, svagt ventilationsbrus.
    seconds = 30
    base = lowpass(noise(seconds), 260, 2) * 1.0
    air = bandpass(noise(seconds), 300, 1800) * 0.08
    x = t(seconds)
    # Bilar långt bort: långsamma svep (heltal perioder => loopbart)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * x * 2 / seconds) * np.sin(2 * np.pi * x * 3 / seconds + 1.3)
    traffic = lowpass(noise(seconds), 140, 3) * swell * 1.6
    hum = tone(50, seconds) * 0.015 + tone(100, seconds) * 0.01
    return base + air + traffic + hum


def electrical_hum():
    # Transformator: 60 Hz med övertoner och lite surr. 4 s = 240 hela perioder.
    seconds = 4
    x = t(seconds)
    sig = (
        np.sin(2 * np.pi * 60 * x) * 0.5
        + np.sin(2 * np.pi * 120 * x) * 0.9
        + np.sin(2 * np.pi * 180 * x) * 0.25
        + np.sin(2 * np.pi * 240 * x) * 0.35
        + np.sin(2 * np.pi * 360 * x) * 0.12
    )
    buzz = bandpass(noise(seconds), 1500, 5000) * 0.05 * (0.6 + 0.4 * np.sin(2 * np.pi * 120 * x))
    return sig * (0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * x)) + buzz


def station_drone():
    # Tunneln: djup, svävande ton och vind. 10 s, frekvenser valda för hela perioder.
    seconds = 10
    x = t(seconds)
    drone = np.sin(2 * np.pi * 41 * x) * 0.8 + np.sin(2 * np.pi * 41.5 * x) * 0.6 + np.sin(2 * np.pi * 82.1 * x) * 0.2
    wind = bandpass(noise(seconds), 80, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * x / seconds * 2) ** 2) * 0.5
    return drone * 0.6 + wind


def static_loop():
    seconds = 3
    hiss = bandpass(noise(seconds), 800, 9000) * 0.4
    crackle = np.zeros(len(t(seconds)))
    for _ in range(90):
        i = rng.integers(0, len(crackle) - 200)
        crackle[i : i + 200] += rng.standard_normal(200) * np.exp(-np.arange(200) / 25) * rng.uniform(0.5, 2)
    return hiss + highpass(crackle, 1000) * 0.6


def alarm():
    # Kontorslarm: två toner som växlar, 2 s loop.
    seconds = 2
    x = t(seconds)
    gate = (np.floor(x * 4) % 2 == 0).astype(float)
    sig = gate * (np.sign(np.sin(2 * np.pi * 880 * x)) * 0.3 + np.sin(2 * np.pi * 1760 * x) * 0.3)
    sig += (1 - gate) * (np.sign(np.sin(2 * np.pi * 660 * x)) * 0.3 + np.sin(2 * np.pi * 1320 * x) * 0.3)
    return lowpass(sig, 4000)


# Händelser ---------------------------------------------------------------------------------


def radio_blip():
    seconds = 0.38
    x = t(seconds)
    chirp = np.sin(2 * np.pi * (1200 + 900 * (x < 0.07)) * x) * ((x < 0.14).astype(float))
    burst = bandpass(noise(seconds), 600, 3500) * decay(seconds, 9) * 0.5
    return (chirp * 0.6 + burst) * envelope(len(x), 0.004, 0.08)


def power_down():
    seconds = 2.4
    x = t(seconds)
    freq = 30 + 330 * np.exp(-x * 2.2)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    whine = (np.sin(phase) * 0.6 + np.sin(phase * 2) * 0.25) * decay(seconds, 1.4)
    thunk = lowpass(noise(seconds), 120, 3) * decay(seconds, 8) * 3
    click = highpass(noise(seconds), 2000) * decay(seconds, 60) * 0.6
    return (whine + thunk + click) * envelope(len(x), 0.002, 0.3)


def power_up():
    seconds = 1.8
    x = t(seconds)
    freq = 60 + 300 * (1 - np.exp(-x * 2.5))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    rise = (np.sin(phase) * 0.5 + np.sin(phase * 2) * 0.3) * (1 - np.exp(-x * 3))
    clack = highpass(noise(seconds), 1500) * decay(seconds, 45) * 0.8
    hum = (np.sin(2 * np.pi * 120 * x) * 0.3) * np.clip((x - 0.8) * 2, 0, 1)
    return (rise + clack + hum) * envelope(len(x), 0.002, 0.4)


def shift_siren():
    # 02:30-sirenen: långsam stigande och fallande ton, som en avlägsen fabrikssiren.
    seconds = 4.5
    x = t(seconds)
    freq = 300 + 280 * np.sin(np.pi * np.clip(x / 4.0, 0, 1)) ** 1.5
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    sig = np.sin(phase) * 0.6 + np.sin(phase * 2) * 0.25 + np.sin(phase * 3) * 0.1
    return lowpass(sig, 2500) * envelope(len(x), 0.4, 0.8, 1.5)


def knock():
    seconds = 1.4
    out = np.zeros(len(t(seconds)))
    for start in (0.0, 0.32, 0.58):
        hit = lowpass(noise(0.25), 400, 3) * decay(0.25, 28) * 2 + tone(95, 0.25) * decay(0.25, 22)
        i = int(start * RATE)
        out[i : i + len(hit)] += hit
    return out


def secure():
    # Lönen säkrad: kassaapparatens klick och två varma toner.
    seconds = 1.1
    x = t(seconds)
    click = highpass(noise(seconds), 2500) * decay(seconds, 70) * 0.5
    a = (np.sin(2 * np.pi * 784 * x) + 0.3 * np.sin(2 * np.pi * 1568 * x)) * decay(seconds, 5)
    b = np.zeros_like(x)
    start = int(0.12 * RATE)
    xb = x[: len(x) - start]
    b[start:] = (np.sin(2 * np.pi * 1175 * xb) + 0.3 * np.sin(2 * np.pi * 2350 * xb)) * np.exp(-xb * 4)
    return (click + a * 0.5 + b * 0.5) * envelope(len(x), 0.002, 0.2)


def pickup():
    seconds = 0.35
    x = t(seconds)
    pluck = (np.sin(2 * np.pi * 523 * x) + 0.5 * np.sin(2 * np.pi * 1046 * x)) * decay(seconds, 14)
    rustle = bandpass(noise(seconds), 1500, 6000) * decay(seconds, 30) * 0.3
    return (pluck * 0.6 + rustle) * envelope(len(x), 0.002, 0.05)


def rare():
    # Sällsynt fynd: skimrande arpeggio (moll, lite kusligt).
    seconds = 2.0
    x = t(seconds)
    out = np.zeros_like(x)
    for i, freq in enumerate((440, 523.25, 659.25, 880, 1046.5)):
        start = int(i * 0.09 * RATE)
        xs = x[: len(x) - start]
        out[start:] += (np.sin(2 * np.pi * freq * xs) + 0.2 * np.sin(2 * np.pi * freq * 2.01 * xs)) * np.exp(-xs * 2.2)
    shimmer = bandpass(noise(seconds), 5000, 12000) * decay(seconds, 3) * 0.08
    return (out + shimmer) * envelope(len(x), 0.002, 0.5)


def keypad_ok():
    seconds = 0.45
    x = t(seconds)
    beep = np.sin(2 * np.pi * 1320 * x) * ((x < 0.1) | ((x > 0.16) & (x < 0.3))).astype(float)
    return lowpass(beep, 6000) * envelope(len(x), 0.002, 0.05)


def keypad_no():
    seconds = 0.5
    x = t(seconds)
    buzz = np.sign(np.sin(2 * np.pi * 140 * x)) * 0.5 + np.sin(2 * np.pi * 280 * x) * 0.3
    return lowpass(buzz, 1800) * envelope(len(x), 0.004, 0.08) * (x < 0.42)


SOUNDS = {
    "city_ambience.ogg": (city_ambience, 0.6),
    "electrical_hum.ogg": (electrical_hum, 0.7),
    "station_drone.ogg": (station_drone, 0.7),
    "static.ogg": (static_loop, 0.6),
    "alarm.ogg": (alarm, 0.8),
    "radio_blip.ogg": (radio_blip, 0.8),
    "power_down.ogg": (power_down, 0.9),
    "power_up.ogg": (power_up, 0.85),
    "shift_siren.ogg": (shift_siren, 0.85),
    "knock.ogg": (knock, 0.9),
    "secure.ogg": (secure, 0.8),
    "pickup.ogg": (pickup, 0.7),
    "rare.ogg": (rare, 0.8),
    "keypad_ok.ogg": (keypad_ok, 0.7),
    "keypad_no.ogg": (keypad_no, 0.7),
}

if __name__ == "__main__":
    for name, (fn, peak) in SOUNDS.items():
        write(name, fn(), peak)
