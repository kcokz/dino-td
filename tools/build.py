#!/usr/bin/env python3
"""Builds the game -- the development build, the release build, or both.

    python tools/build.py              # both
    python tools/build.py dev          # the development build, into build/dev/
    python tools/build.py release      # the release build, into build/release/
    python tools/build.py --check PCK  # only look inside a pack for development code

What tells the two builds apart is decided here and in export_presets.cfg, not by a switch inside the
game (v0.6 round seven, the player: "release版本没有这个功能和按钮，这在你的build file或者build script得区分"):

  * dev     -- a DEBUG export of the "Windows Dev" preset. It carries everything under scripts/dev/: the
               bug report, its key and its button (scripts/dev/BugReport.gd).
  * release -- a RELEASE export of the "Windows Release" preset, whose exclude_filter leaves scripts/dev/
               out. The game adds the bug report by its path, only where the file was shipped and the build
               is a debug one (Main._add_bug_report), so the release has neither the feature nor the button.
               After exporting, this script reads the release pack's list of files and fails the build if
               anything from scripts/dev/ got into it.

Godot is found as --godot PATH, the GODOT environment variable, or `godot` on the PATH, and its export
templates must be installed for its version (Editor > Manage Export Templates).
"""

import argparse
import os
import platform
import re
import shutil
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The builds: which preset, exported how, to where (export_presets.cfg holds the presets themselves).
BUILDS = {
    "dev": {"preset": "Windows Dev", "how": "--export-debug", "out": "build/dev/Defend Dinosaur.exe"},
    "release": {"preset": "Windows Release", "how": "--export-release", "out": "build/release/Defend Dinosaur.exe"},
}

# What only a development build may carry.
DEV_ONLY = "scripts/dev/"

# The template a Windows export of each kind is made from.
TEMPLATES = {"--export-debug": "windows_debug_x86_64.exe", "--export-release": "windows_release_x86_64.exe"}


def find_godot(given):
    for candidate in (given, os.environ.get("GODOT"), shutil.which("godot")):
        if candidate and os.path.isfile(candidate):
            return candidate
    sys.exit("build: no Godot -- pass --godot PATH or set GODOT to the Godot executable "
             "(on Windows, the _console.exe shows its output).")


def godot_version(godot):
    out = subprocess.run([godot, "--version"], capture_output=True, text=True).stdout.strip()
    m = re.match(r"(\d+\.\d+(?:\.\d+)?)\.(\w+)", out)
    if not m:
        sys.exit("build: could not read Godot's version from %r" % out)
    return "%s.%s" % (m.group(1), m.group(2))


def templates_dir(version):
    system = platform.system()
    if system == "Windows":
        base = os.path.join(os.environ.get("APPDATA", ""), "Godot")
    elif system == "Darwin":
        base = os.path.expanduser("~/Library/Application Support/Godot")
    else:
        base = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "godot")
    return os.path.join(base, "export_templates", version)


def pack_paths(pck):
    """The files a Godot 4 pack (.pck) holds, as its directory lists them."""
    with open(pck, "rb") as f:
        data = f.read()
    start = data.find(b"GDPC")
    if start < 0:
        raise ValueError("%s: not a Godot pack" % pck)
    at = start + 4

    def u32():
        nonlocal at
        v = struct.unpack_from("<I", data, at)[0]
        at += 4
        return v

    def u64():
        nonlocal at
        v = struct.unpack_from("<Q", data, at)[0]
        at += 8
        return v

    version = u32()
    u32(), u32(), u32()                    # the engine's major, minor, patch
    flags = u32()
    if flags & 1:
        raise ValueError("%s: its directory is encrypted" % pck)
    u64()                                  # where the files begin
    if version >= 3:
        at = start + u64()                 # the directory is at the end
    else:
        at += 16 * 4                       # reserved; the directory follows
    paths = []
    for _ in range(u32()):
        length = u32()
        paths.append(data[at:at + length].rstrip(b"\0").decode("utf-8"))
        at += length
        at += 8 + 8 + 16                   # offset, size, md5
        if version >= 2:
            at += 4                        # flags
    return paths


def shown(path):
    """A path as the project sees it, where it is in the project."""
    try:
        return os.path.relpath(path, ROOT)
    except ValueError:                     # on another drive
        return path


def check_release(pck):
    """Fails if a release pack carries anything only a development build may."""
    found = [p for p in pack_paths(pck) if p.replace("res://", "").startswith(DEV_ONLY)]
    if found:
        sys.exit("build: the release carries development code -- %s" % ", ".join(found))
    print("build: %s carries nothing from %s" % (shown(pck), DEV_ONLY))


def build(godot, kind):
    spec = BUILDS[kind]
    out = os.path.join(ROOT, spec["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    print("build: %s -- %s %r -> %s" % (kind, spec["how"], spec["preset"], shown(out)))
    done = subprocess.run([godot, "--headless", "--path", ROOT, spec["how"], spec["preset"], out])
    if done.returncode != 0 or not os.path.isfile(out):
        sys.exit("build: the %s export failed" % kind)
    if kind == "release":
        check_release(os.path.splitext(out)[0] + ".pck")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("kind", nargs="?", choices=["dev", "release", "all"], default="all")
    parser.add_argument("--godot", help="the Godot executable (else GODOT, else godot on the PATH)")
    parser.add_argument("--check", metavar="PCK", help="only check a release pack for development code")
    args = parser.parse_args()
    if args.check:
        check_release(args.check)
        return
    godot = find_godot(args.godot)
    kinds = ["dev", "release"] if args.kind == "all" else [args.kind]
    have = templates_dir(godot_version(godot))
    for kind in kinds:
        template = os.path.join(have, TEMPLATES[BUILDS[kind]["how"]])
        if not os.path.isfile(template):
            sys.exit("build: no export template %s -- install the templates for this Godot "
                     "(Editor > Manage Export Templates)" % template)
    for kind in kinds:
        build(godot, kind)


if __name__ == "__main__":
    main()
