#!/usr/bin/env python3
"""Personalize a GPL-3.0 SongTube source checkout as MeloTube.

Run at the root of an *imported SongTube source tree*, not MeloTR main.
Original LICENSE is retained and original authorship is acknowledged.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import re

root = Path(__file__).resolve().parents[1]
assert (root / "lib/main.dart").exists(), "Flutter sources missing"
pubspec = root / "pubspec.yaml"
source = pubspec.read_text(encoding="utf-8")
assert re.search(r"^name:\s*songtube\s*$", source, re.M), "Expected SongTube pubspec"
source = re.sub(r"^name:\s*songtube\s*$", "name: melotube", source, count=1, flags=re.M)
source = re.sub(r"^version:\s*[^\n]+", "version: 0.1.0+1", source, count=1, flags=re.M)
pubspec.write_text(source, encoding="utf-8")

# Rename internal Dart import namespace while keeping external Git dependencies.
for dart in list((root / "lib").rglob("*.dart")) + list((root / "test").rglob("*.dart")):
    data = dart.read_text(encoding="utf-8")
    data = data.replace("package:songtube/", "package:melotube/")
    # These class references and user-facing messages are internal to our fork.
    data = data.replace("SongTube", "MeloTube")
    # Keep upstream attribution links and original repository addresses intact.
    data = data.replace("github.com/MeloTube/", "github.com/SongTube/")
    data = data.replace("https://t.me/melotubechannel", "https://t.me/songtubechannel")
    dart.write_text(data, encoding="utf-8")

global_dart = root / "lib/internal/global.dart"
data = global_dart.read_text(encoding="utf-8")
data = data.replace("com.artxdev.songtube", "com.melotube.player")
data = data.replace("Color.fromARGB(255, 229, 12, 73)", "Color(0xFF22D6DB)")
# Do not let this fork self-update from the original application's APK server.
data = data.replace("sharedPreferences.getBool(enableInAppUpdatesKey) ?? true",
                    "sharedPreferences.getBool(enableInAppUpdatesKey) ?? false")
global_dart.write_text(data, encoding="utf-8")

dark_dart = root / "lib/ui/themes/dark.dart"
data = dark_dart.read_text(encoding="utf-8")
data = data.replace("Color.fromARGB(255, 35, 35, 35)", "Color(0xFF0C1326)")
data = data.replace("Color(0xFF282828)", "Color(0xFF16263D)")
dark_dart.write_text(data, encoding="utf-8")

gradle = root / "android/app/build.gradle"
data = gradle.read_text(encoding="utf-8")
data = data.replace('namespace "com.artxdev.songtube"', 'namespace "com.melotube.player"')
data = data.replace('applicationId "com.artxdev.songtube"', 'applicationId "com.melotube.player"')
data = data.replace('resValue "string", "app_name", "SongTube"',
                    'resValue "string", "app_name", "MeloTube"')
data = data.replace('resValue "string", "app_name", "SongDebug"',
                    'resValue "string", "app_name", "MeloTube Dev"')
# Testing-only signed APK; normal application updates require a stable key.
data = data.replace("signingConfig signingConfigs.release", "signingConfig signingConfigs.debug")
gradle.write_text(data, encoding="utf-8")

old_java = root / "android/app/src/main/java/com/artxdev/songtube/MainActivity.java"
if old_java.exists():
    new_java = root / "android/app/src/main/java/com/melotube/player/MainActivity.java"
    new_java.parent.mkdir(parents=True, exist_ok=True)
    new_java.write_text(old_java.read_text(encoding="utf-8").replace(
        "package com.artxdev.songtube;", "package com.melotube.player;"), encoding="utf-8")
    old_java.unlink()

# Generate our own brand mark rather than redistributing SongTube's logo.
size = 1024
canvas = Image.new("RGB", (size, size))
pixels = canvas.load()
for y in range(size):
    for x in range(size):
        mix = (x / size * 0.30 + y / size * 0.70)
        pixels[x, y] = (int(8 + mix * 11), int(15 + mix * 17), int(34 + mix * 22))
image = canvas.convert("RGBA")
d = ImageDraw.Draw(image, "RGBA")
d.rounded_rectangle((72, 72, 952, 952), radius=244, fill=(16, 29, 57, 255))
# Sonic ring and rhythm bars
d.ellipse((178, 178, 846, 846), outline=(26, 216, 221, 245), width=27)
d.arc((223, 223, 800, 800), start=190, end=345,
      fill=(180, 83, 246, 235), width=33)
for x, bar in [(330, 152), (430, 275), (530, 378), (630, 225), (730, 135)]:
    top = 512 - bar // 2
    bottom = 512 + bar // 2
    d.rounded_rectangle((x - 27, top, x + 27, bottom),
                        radius=26, fill=(38, 218, 221, 255))
# Purple accent gleam (abstract mark, no YouTube/SongTube trademark).
d.ellipse((717, 204, 792, 279), fill=(182, 86, 249, 255))

for density, px in [
    ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
    ("xxhdpi", 144), ("xxxhdpi", 192)
]:
    dest = root / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    image.resize((px, px), Image.Resampling.LANCZOS).save(dest)
for name in ["logo.png", "logo_bw.png", "logo_christmas.png"]:
    dest = root / "assets/images" / name
    if dest.exists():
        image.resize((512, 512), Image.Resampling.LANCZOS).save(dest)

lic = root / "LICENSE"
assert lic.exists() and "GNU GENERAL PUBLIC LICENSE" in lic.read_text(
    encoding="utf-8"), "GPL-3.0 source license missing"

notes = root / "MELOTUBE_CHANGES.md"
notes.write_text(
    "# MeloTube v0.1.0 (SongTube-derived)\n\n"
    "Base: SongTube/SongTube-App development commit "
    "a6c51b6ab28cf566d048e7e8abff3367226afef1.\n\n"
    "- App branding changed to MeloTube; unique cyan/purple mark generated.\n"
    "- Android package ID: com.melotube.player; Dart package: melotube.\n"
    "- Original application update routine is off by default.\n"
    "- Dark theme uses midnight blue and cyan accent.\n"
    "- This is an independently modified GPL-3.0 source tree; original "
    "authors retain their respective copyrights. Do not represent "
    "this build as the official SongTube application.\n"
    "- APK is currently signed with a testing key, not for commercial release.\n"
    "- Media providers can reject individual downloads; source availability "
    "is not guaranteed, even with the NewPipe engine.\n",
    encoding="utf-8",
)
print("MeloTube name, package ID, theme, icon, and license notice updated.")
