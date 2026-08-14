#!/usr/bin/env python3
"""Generate original placeholder arcade audio without external samples."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44_100
OUT = Path(__file__).resolve().parents[1] / "game/assets/audio"


def save(name: str, seconds: float, sample_fn) -> None:
    count = int(RATE * seconds)
    OUT.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for i in range(count):
        t = i / RATE
        envelope = min(1.0, t * 80.0) * min(1.0, (seconds - t) * 30.0)
        value = max(-1.0, min(1.0, sample_fn(t, i, seconds))) * envelope
        frames.extend(struct.pack("<h", int(value * 32767)))
    with wave.open(str(OUT / name), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(frames)


def main() -> None:
    noise = random.Random(7319)
    save("engine_loop.wav", 1.2, lambda t, _i, _s: 0.22 * math.sin(2 * math.pi * 74 * t + 0.8 * math.sin(2 * math.pi * 8 * t)) + 0.09 * math.sin(2 * math.pi * 148 * t))
    save("boost.wav", 0.7, lambda t, _i, s: 0.28 * math.sin(2 * math.pi * (180 + 720 * t / s) * t) + 0.08 * (noise.random() * 2 - 1))
    save("pickup.wav", 0.32, lambda t, _i, s: 0.35 * math.sin(2 * math.pi * (520 + 500 * t / s) * t) + 0.16 * math.sin(2 * math.pi * 1040 * t))
    save("countdown.wav", 0.18, lambda t, _i, _s: 0.38 * math.sin(2 * math.pi * 440 * t) + 0.12 * math.sin(2 * math.pi * 880 * t))
    save("impact.wav", 0.24, lambda t, _i, s: (0.40 * (noise.random() * 2 - 1) + 0.24 * math.sin(2 * math.pi * 92 * t)) * (1 - t / s))
    notes = (523.25, 659.25, 783.99, 1046.5)
    save("finish_stinger.wav", 1.2, lambda t, _i, _s: 0.26 * math.sin(2 * math.pi * notes[min(3, int(t / 0.3))] * t) + 0.08 * math.sin(2 * math.pi * notes[min(3, int(t / 0.3))] * 2 * t))
    for path in sorted(OUT.glob("*.wav")):
        print(path.relative_to(OUT.parents[2]))


if __name__ == "__main__":
    main()
