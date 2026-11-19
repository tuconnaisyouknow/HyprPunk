#!/usr/bin/env python3
# Builds the shell's two fonts into ~/.local/share/fonts/hyprpunk, under names of their
# own: Qt Quick picks a font by its family alone, so each role gets a family that holds
# exactly the cut it needs.
#   HyprPunk Text     Ioskeley Mono's Nerd Font, semi-condensed, from regular to bold,
#                     with its symbols one cell wide like its letters
#   HyprPunk Display  Orbitron Bold, with digits that all take one width (tnum): the
#                     lock's clock would shift every minute without them
#
#   fontsctl.py ensure   builds what's missing (install.sh)
#   fontsctl.py build    builds both again

import copy
import io
import os
import subprocess
import sys
import urllib.request
import zipfile

from fontTools.otlLib import builder
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables import otTables
from fontTools.varLib import instancer

DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
CACHE_HOME = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
FONTS_DIR = DATA_HOME + "/fonts/hyprpunk"
CACHE_DIR = CACHE_HOME + "/hyprpunk/fonts"

IOSKELEY = "https://github.com/ahatem/IoskeleyMono/releases/download/v2.2.0/IoskeleyMono-NerdFont.zip"
ORBITRON = "https://raw.githubusercontent.com/google/fonts/main/ofl/orbitron/Orbitron%5Bwght%5D.ttf"

# The weights the shell writes in, by the name Ioskeley gives each file
TEXT_WEIGHTS = {
    "Regular": "",
    "Medium": "Medium",
    "SemiBold": "SemiBold",
    "Bold": "Bold",
}
TEXT_FAMILY = "HyprPunk Text"
DISPLAY_FAMILY = "HyprPunk Display"


def text_path(weight):
    return f"{FONTS_DIR}/HyprPunkText-{weight}.ttf"


def display_path():
    return f"{FONTS_DIR}/HyprPunkDisplay-Bold.ttf"


# Written aside then swapped in: a running shell keeps reading the file it opened, and
# crashes if that one changes under it
def save(font, path):
    font.save(path + ".part")
    os.replace(path + ".part", path)


# Kept between runs: Ioskeley's archive is large
def download(url, name):
    path = f"{CACHE_DIR}/{name}"
    if not os.path.exists(path):
        os.makedirs(CACHE_DIR, exist_ok=True)
        print(f"Downloading {name}")
        urllib.request.urlretrieve(url, path + ".part")
        os.replace(path + ".part", path)
    return path


# Regular and Bold are the family's own styles, the weights between them hang on it
# through the typographic names, as font files do.
def rename(font, family, weight):
    names = font["name"]
    for record in list(names.names):
        if record.nameID in (1, 2, 3, 4, 6, 16, 17, 21, 22):
            names.removeNames(nameID=record.nameID)
    plain = weight in ("Regular", "Bold")
    full = family if weight == "Regular" else f"{family} {weight}"
    postscript = f"{family.replace(' ', '')}-{weight}"
    entries = {
        1: family if plain else full,
        2: weight if plain else "Regular",
        3: postscript,
        4: full,
        6: postscript,
    }
    if not plain:
        entries.update({16: family, 17: weight})
    for name_id, value in entries.items():
        names.setName(value, name_id, 3, 1, 0x409)


# Ioskeley draws its symbols (squares, arrows, ticks…) two cells wide, and keeps a
# one-cell form of each behind a feature. The shell writes with the narrow ones, so a
# symbol takes the room of a letter: a password's squares stay close together.
def narrow_symbols(font):
    glyphs = set(font.getGlyphOrder())
    for table in font["cmap"].tables:
        for code, name in table.cmap.items():
            narrow = name.removesuffix(".WWID") + ".NWID"
            if name.endswith(".WWID") and narrow in glyphs:
                table.cmap[code] = narrow


def build_text():
    archive = zipfile.ZipFile(download(IOSKELEY, "IoskeleyMono-NerdFont.zip"))
    for weight, suffix in TEXT_WEIGHTS.items():
        member = f"SemiCondensed/IoskeleyMonoNerdFont-SemiCondensed{suffix}.ttf"
        font = TTFont(io.BytesIO(archive.read(member)))
        narrow_symbols(font)
        rename(font, TEXT_FAMILY, weight)
        save(font, text_path(weight))
        print(f"Built {TEXT_FAMILY} {weight}")


# Each digit copied into a cell as wide as the widest one, centred, and offered as the
# font's tnum feature next to the ones it has.
def add_tabular_digits(font):
    cmap = font.getBestCmap()
    glyphs, metrics = font["glyf"], font["hmtx"]
    digits = [cmap[ord(digit)] for digit in "0123456789"]
    cell = max(metrics[name][0] for name in digits)
    tabular = {}
    for name in digits:
        advance, bearing = metrics[name]
        shift = (cell - advance) // 2
        glyph = copy.deepcopy(glyphs[name])
        if glyph.isComposite():
            for component in glyph.components:
                component.x += shift
        elif glyph.numberOfContours > 0:
            glyph.coordinates.translate((shift, 0))
        glyph.recalcBounds(glyphs)
        glyphs[name + ".tnum"] = glyph
        metrics[name + ".tnum"] = (cell, bearing + shift)
        tabular[name] = name + ".tnum"
    # The font learns of its new glyphs
    font.setGlyphOrder(glyphs.glyphOrder)

    table = font["GSUB"].table
    table.LookupList.Lookup.append(
        builder.buildLookup([builder.buildSingleSubstSubtable(tabular)])
    )
    table.LookupList.LookupCount = len(table.LookupList.Lookup)
    record = otTables.FeatureRecord()
    record.FeatureTag = "tnum"
    record.Feature = otTables.Feature()
    record.Feature.FeatureParams = None
    record.Feature.LookupListIndex = [table.LookupList.LookupCount - 1]
    record.Feature.LookupCount = 1
    table.FeatureList.FeatureRecord.append(record)
    table.FeatureList.FeatureCount = len(table.FeatureList.FeatureRecord)
    # Every script and language the font knows gets the feature
    for script in table.ScriptList.ScriptRecord:
        systems = [script.Script.DefaultLangSys] + [
            language.LangSys for language in script.Script.LangSysRecord
        ]
        for system in filter(None, systems):
            system.FeatureIndex.append(table.FeatureList.FeatureCount - 1)
            system.FeatureCount = len(system.FeatureIndex)


def build_display():
    font = TTFont(download(ORBITRON, "Orbitron.ttf"))
    font = instancer.instantiateVariableFont(font, {"wght": 700})
    add_tabular_digits(font)
    rename(font, DISPLAY_FAMILY, "Bold")
    font["OS/2"].usWeightClass = 700
    font["OS/2"].fsSelection = (font["OS/2"].fsSelection | 0x20) & ~0x41
    font["head"].macStyle |= 0x01
    save(font, display_path())
    print(f"Built {DISPLAY_FAMILY} Bold")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command not in ("ensure", "build"):
        sys.exit("usage: fontsctl.py <ensure|build>")
    os.makedirs(FONTS_DIR, exist_ok=True)
    again = command == "build"
    built = False
    if again or not all(os.path.exists(text_path(weight)) for weight in TEXT_WEIGHTS):
        build_text()
        built = True
    if again or not os.path.exists(display_path()):
        build_display()
        built = True
    if built:
        subprocess.run(["fc-cache", "-f", FONTS_DIR], check=True)


if __name__ == "__main__":
    main()
