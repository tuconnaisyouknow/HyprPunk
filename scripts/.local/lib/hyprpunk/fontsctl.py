#!/usr/bin/env python3
# Builds the desktop's three fonts into ~/.local/share/fonts/hyprpunk, under names of
# their own: Qt Quick picks a font by its family alone, so each role gets a family that
# holds exactly the cut it needs. The apps write in the text one too.
#   HyprPunk Text     Ioskeley Mono, semi-condensed, from regular to bold, upright and
#                     italic, with its symbols one cell wide like its letters. No icons:
#                     the shell draws its own from Material Symbols
#   HyprPunk Term     the same at full width, regular and bold, with the Nerd Font icons
#                     (Ioskeley Mono Term), for the terminal and whatever asks for monospace
#   HyprPunk Display  Orbitron Bold, with digits that all take one width (tnum): the
#                     lock's clock would shift every minute without them
#
#   fontsctl.py ensure   builds what's missing or now comes from elsewhere (install.sh)
#   fontsctl.py build    builds them all again

import copy
import io
import json
import os
import subprocess
import sys
import urllib.parse
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

IOSKELEY = "https://github.com/ahatem/IoskeleyMono/releases/download/v2.2.0/"
ORBITRON = "https://raw.githubusercontent.com/google/fonts/main/ofl/orbitron/Orbitron%5Bwght%5D.ttf"

# Ioskeley's families: the archive each comes from and a cut's file in it, the width it's
# cut from, and the weights it's written in. The shell writes in four, the terminal only
# in regular and bold. In a file's name, the width, weight and slant run together.
IOSKELEY_FAMILIES = {
    "HyprPunk Text": (
        IOSKELEY + "IoskeleyMono.zip",
        "{width}/Hinted/IoskeleyMono-{cut}.ttf",
        "SemiCondensed",
        ["Regular", "Medium", "SemiBold", "Bold"],
    ),
    "HyprPunk Term": (
        IOSKELEY + "IoskeleyMono-NerdFont.zip",
        "{width}/IoskeleyMonoNerdFont-{cut}.ttf",
        "",
        ["Regular", "Bold"],
    ),
}
DISPLAY_FAMILY = "HyprPunk Display"
# Where each family was built from, so one whose source changed is built again
SOURCES_FILE = FONTS_DIR + "/sources.json"


# A cut's name as font files spell it: Regular, Italic, Medium, Medium Italic…
def style(weight, italic):
    return f"{weight} Italic".removeprefix("Regular ") if italic else weight


# Each weight upright then italic: the shell only writes upright, the apps ask for both
def cuts(family):
    weights = IOSKELEY_FAMILIES[family][3]
    return [(weight, italic) for weight in weights for italic in (False, True)]


def font_path(family, weight, italic):
    return f"{FONTS_DIR}/{family.replace(' ', '')}-{style(weight, italic).replace(' ', '')}.ttf"


def display_path():
    return f"{FONTS_DIR}/HyprPunkDisplay-Bold.ttf"


# Written aside then swapped in: a running shell keeps reading the file it opened, and
# crashes if that one changes under it
def save(font, path):
    font.save(path + ".part")
    os.replace(path + ".part", path)


# Kept between runs, by its file's name: Ioskeley's archives are large
def download(url):
    name = urllib.parse.unquote(url.rsplit("/", 1)[1])
    path = f"{CACHE_DIR}/{name}"
    if not os.path.exists(path):
        os.makedirs(CACHE_DIR, exist_ok=True)
        print(f"Downloading {name}")
        urllib.request.urlretrieve(url, path + ".part")
        os.replace(path + ".part", path)
    return path


# Regular and Bold, upright and italic, are the family's own styles. The weights between
# them hang on it through the typographic names, as font files do.
def rename(font, family, weight, italic=False):
    names = font["name"]
    for record in list(names.names):
        if record.nameID in (1, 2, 3, 4, 6, 16, 17, 21, 22):
            names.removeNames(nameID=record.nameID)
    cut = style(weight, italic)
    plain = weight in ("Regular", "Bold")
    full = family if cut == "Regular" else f"{family} {cut}"
    postscript = f"{family.replace(' ', '')}-{cut.replace(' ', '')}"
    entries = {
        1: family if plain else f"{family} {weight}",
        2: cut if plain else style("Regular", italic),
        3: postscript,
        4: full,
        6: postscript,
    }
    if not plain:
        entries.update({16: family, 17: cut})
    for name_id, value in entries.items():
        names.setName(value, name_id, 3, 1, 0x409)


# Ioskeley draws its symbols (squares, arrows, ticks…) two cells wide, and keeps a
# one-cell form of each behind a feature. Both families write with the narrow ones, so a
# symbol takes the room of a letter: a password's squares stay close together, and the
# terminal's grid holds. At full width, that's exactly Ioskeley Mono Term.
def narrow_symbols(font):
    glyphs = set(font.getGlyphOrder())
    for table in font["cmap"].tables:
        for code, name in table.cmap.items():
            narrow = name.removesuffix(".WWID") + ".NWID"
            if name.endswith(".WWID") and narrow in glyphs:
                table.cmap[code] = narrow


# A cut's file in its family's archive: the full-width regular is the one left to call
# itself Regular
def ioskeley_member(family, weight, italic):
    _, member, width, _ = IOSKELEY_FAMILIES[family]
    cut = width + weight.removeprefix("Regular") + ("Italic" if italic else "")
    return member.format(width=width or "Normal", cut=cut or "Regular")


def build_ioskeley(family):
    archive = zipfile.ZipFile(download(IOSKELEY_FAMILIES[family][0]))
    for weight, italic in cuts(family):
        font = TTFont(io.BytesIO(archive.read(ioskeley_member(family, weight, italic))))
        narrow_symbols(font)
        rename(font, family, weight, italic)
        save(font, font_path(family, weight, italic))
        print(f"Built {family} {style(weight, italic)}")


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
    font = TTFont(download(ORBITRON))
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
    try:
        with open(SOURCES_FILE) as file:
            sources = json.load(file)
    except (OSError, ValueError):
        sources = {}
    built = False
    for family, (url, *_) in IOSKELEY_FAMILIES.items():
        if (
            again
            or sources.get(family) != url
            or not all(os.path.exists(font_path(family, *cut)) for cut in cuts(family))
        ):
            build_ioskeley(family)
            sources[family] = url
            built = True
    if (
        again
        or sources.get(DISPLAY_FAMILY) != ORBITRON
        or not os.path.exists(display_path())
    ):
        build_display()
        sources[DISPLAY_FAMILY] = ORBITRON
        built = True
    if built:
        with open(SOURCES_FILE, "w") as file:
            json.dump(sources, file, indent=2)
        subprocess.run(["fc-cache", "-f", FONTS_DIR], check=True)


if __name__ == "__main__":
    main()
