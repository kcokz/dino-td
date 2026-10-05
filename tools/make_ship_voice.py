# tools/make_ship_voice.py
# The ship's computer, speaking in the opening film (scripts/fx/Opening.gd; the player, 2026-10-04: "配音你可以想办法").
#
#   python tools/make_ship_voice.py
#
# Each line is spoken by the speech synthesiser Windows comes with (System.Speech, its "Microsoft Zira" voice: the ship's
# own calm, even voice -- a computer's, which is what a synthesiser sounds like), in English, whichever language the game
# is played in: the words under it are the player's own (Config.OPENING.lines, translations/strings.csv). Then it is put
# through the ship's intercom: the band a small speaker carries, a little ring-modulated metal in it, the short slap of a
# hard room -- and written where the game's other sounds are (assets/audio/voice_ship_<id>.wav, Config.SOUNDS).
#
# Nothing is downloaded: the voice is the machine's own. A different one is a different VOICE name below (Windows'
# Settings > Time & language > Speech adds more).

import math
import os
import struct
import subprocess
import tempfile
import wave

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(REPO, "assets", "audio")
RATE = 22050
VOICE = "Microsoft Zira Desktop"
SPEED = -1                       # the synthesiser's rate: a little slower than it speaks by default

# What the ship says, by the id of its sound (Config.SOUNDS voice_ship_<id>) -- the same as its words in English
# (translations/strings.csv FILM_LINE_*).
LINES = {
    "jump": "Temporal jump in progress. All systems nominal.",
    "failure": "Warning. Temporal drive failure.",
    "breach": "Hull breach. Separating the crew module.",
    "down": "Crew module down. Power reserve, limited. ... Wake up.",
}


def speak(text, path):
    """The line spoken into a WAV at RATE, mono, 16-bit, by Windows' own synthesiser."""
    ps = (
        "Add-Type -AssemblyName System.Speech;"
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        "$s.SelectVoice('%s');"
        "$s.Rate = %d;"
        "$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(%d, "
        "[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono);"
        "$s.SetOutputToWaveFile('%s', $f);"
        "$s.Speak('%s');"
        "$s.SetOutputToNull(); $s.Dispose()"
    ) % (VOICE, SPEED, RATE, path.replace("'", "''"), text.replace("'", "''"))
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True)


def read(path):
    with wave.open(path, "rb") as w:
        n = w.getnframes()
        raw = w.readframes(n)
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


def intercom(data):
    """The ship's speaker: the band it carries (two poles each side), a touch of ring modulation, a hard room's slap."""
    band = one_pole(one_pole(data, 260.0, True), 260.0, True)
    band = one_pole(one_pole(band, 3900.0), 3900.0)
    ring = [x * (0.85 + 0.15 * math.sin(2.0 * math.pi * 58.0 * i / RATE)) for i, x in enumerate(band)]
    d = int(0.011 * RATE)
    out = ring + [0.0] * int(0.25 * RATE)
    for i in range(d, len(out)):
        out[i] += out[i - d] * 0.28
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
    for key, text in LINES.items():
        raw = os.path.join(tmp, key + ".wav")
        speak(text, raw)
        data = trimmed(intercom(read(raw)))
        path = os.path.join(OUT, "voice_ship_%s.wav" % key)
        write(path, data)
        print("[OK] voice_ship_%s.wav  %.1f s  \"%s\"" % (key, len(data) / RATE, text))


if __name__ == "__main__":
    main()
