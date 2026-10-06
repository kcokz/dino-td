# tools/make_ship_voice.py
# The ship's computer, speaking in the opening film (scripts/fx/Opening.gd; the player, 2026-10-04: "配音你可以想办法";
# 2026-10-05: "配音完全机械声" -- chose Microsoft's neural voices through edge-tts).
#
#   python tools/make_ship_voice.py
#
# Each line in both the game's languages, its words taken from translations/strings.csv (FILM_LINE_*), so the voice says
# what the words under it say: English by en-US-AriaNeural, Chinese by zh-CN-XiaoxiaoNeural -- a calm voice that reads
# like a person, a little slower than it speaks by default. Then through the ship's speaker, lightly -- the band a good
# speaker carries and the short slap of a hard room, no more: it is the ship talking, not a radio -- and written where
# the game's other sounds are: assets/audio/voice_ship_<id>.wav (English) and voice_ship_<id>_zh.wav (Chinese)
# (Config.SOUNDS; the film plays the one in the player's language, Opening._say_in).
#
# Needs the edge-tts package (pip install edge-tts) and ffmpeg on the path, and is online: the lines go to Microsoft's
# speech service and come back as speech (the player agreed, 2026-10-05).

import asyncio
import csv
import math
import os
import shutil
import struct
import subprocess
import tempfile
import wave

import edge_tts

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(REPO, "assets", "audio")
STRINGS = os.path.join(REPO, "translations", "strings.csv")
RATE = 24000

# What the ship says, by the id of its sound (Config.SOUNDS voice_ship_<id>): the key of its words.
LINES = {
    "jump": "FILM_LINE_JUMP",
    "failure": "FILM_LINE_FAILURE",
    "breach": "FILM_LINE_BREACH",
    "down": "FILM_LINE_DOWN",
}

# Its voice in each language: the column of strings.csv its words are in, the voice, how fast and how high, and the
# end of its file's name.
VOICES = {
    "en": {"column": 1, "voice": "en-US-AriaNeural", "rate": "-6%", "pitch": "+0Hz", "suffix": ""},
    "zh": {"column": 2, "voice": "zh-CN-XiaoxiaoNeural", "rate": "-4%", "pitch": "+0Hz", "suffix": "_zh"},
}


def words():
    """FILM_LINE_* from strings.csv: {key: [key, english, chinese]}."""
    out = {}
    with open(STRINGS, encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            if row and row[0].startswith("FILM_LINE_"):
                out[row[0]] = row
    return out


async def speak(text, voice, rate, pitch, path):
    await edge_tts.Communicate(text, voice, rate=rate, pitch=pitch).save(path)


def decode(mp3, wav):
    ffmpeg = shutil.which("ffmpeg") or os.environ.get("FFMPEG", "ffmpeg")
    subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", mp3, "-ac", "1", "-ar", str(RATE), "-sample_fmt", "s16", wav],
                   check=True)


def read(path):
    with wave.open(path, "rb") as w:
        raw = w.readframes(w.getnframes())
    return [s / 32768.0 for s in struct.unpack("<%dh" % (len(raw) // 2), raw)]


def write(path, data):
    peak = max(1e-6, max(abs(x) for x in data))
    k = 0.89 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(data), *[int(max(-1.0, min(1.0, x * k)) * 32767) for x in data]))


def one_pole(data, hz, high=False):
    a = 1.0 - math.exp(-2.0 * math.pi * hz / RATE)
    y = 0.0
    out = []
    for x in data:
        y += a * (x - y)
        out.append(x - y if high else y)
    return out


def ship_speaker(data):
    """The ship's own speaker, lightly: the band a good speaker carries (one pole each side), and the short slap of the
    module's hard walls -- the voice left a person's."""
    band = one_pole(data, 110.0, True)
    band = one_pole(band, 7500.0)
    d = int(0.013 * RATE)
    out = band + [0.0] * int(0.2 * RATE)
    for i in range(d, len(out)):
        out[i] += out[i - d] * 0.16
    return out


def trimmed(data, floor=0.004, tail=0.18):
    """Its silence before and after cut down to a breath."""
    lo = next((i for i, x in enumerate(data) if abs(x) > floor), 0)
    hi = len(data) - next((i for i, x in enumerate(reversed(data)) if abs(x) > floor), 0)
    lo = max(0, lo - int(0.03 * RATE))
    hi = min(len(data), hi + int(tail * RATE))
    out = data[lo:hi]
    fade = int(0.01 * RATE)
    for i in range(min(fade, len(out))):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    said = words()
    for key, word_key in LINES.items():
        row = said[word_key]
        for lang, v in VOICES.items():
            text = row[v["column"]]
            mp3 = os.path.join(tmp, "%s_%s.mp3" % (key, lang))
            wav = os.path.join(tmp, "%s_%s.wav" % (key, lang))
            asyncio.run(speak(text, v["voice"], v["rate"], v["pitch"], mp3))
            decode(mp3, wav)
            data = trimmed(ship_speaker(read(wav)))
            name = "voice_ship_%s%s.wav" % (key, v["suffix"])
            write(os.path.join(OUT, name), data)
            print("[OK] %s  %.1f s  %s" % (name, len(data) / RATE, v["voice"]))


if __name__ == "__main__":
    main()
