#!/usr/bin/env python3
"""Lyrics of a track from lrclib.net, timed per line when it has them.

Usage: lyrics-lookup.py <artist> <title> <album> <seconds>

Prints one JSON line:
  {"status": "found", "synced": bool, "instrumental": bool,
   "lines": [{"t": seconds, "text": "..."}]}   (t is -1 for untimed lyrics)
  {"status": "missing"}   lrclib has nothing for it
  {"status": "network"}   lrclib could not be asked (offline, busy): ask again later

Answers are cached in $XDG_STATE_HOME/hyprpunk/lyrics, a miss for a week.
"""

import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
AGENT = "hyprpunk (github.com/tuconnaisyouknow/HyprPunk)"
TIMEOUT = 8
MISS_LIFETIME = 7 * 24 * 3600
# Off by more than this many seconds, a record is another version of the track
# (Spotify and lrclib often disagree by a few seconds on the same one).
LENGTH_TOLERANCE = 8

STAMP = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
# "Song - Remastered 2011", "Song - Radio Edit", "Song (feat. Someone)".
SUFFIX = re.compile(r"\s+-\s+.*$")
FEATURING = re.compile(r"\s*[\(\[](feat|ft|with)\.?\s[^\)\]]*[\)\]]", re.IGNORECASE)


class Unreachable(Exception):
    """lrclib gave no answer: offline, a server error or a rate limit."""


def cache_path(artist, title, album, seconds):
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    directory = os.path.join(base, "hyprpunk", "lyrics")
    os.makedirs(directory, exist_ok=True)
    key = hashlib.sha1(f"{artist}\n{title}\n{album}\n{round(seconds)}".encode()).hexdigest()
    return os.path.join(directory, key + ".json")


def ask(endpoint, params):
    url = f"{API}/{endpoint}?{urllib.parse.urlencode(params)}"
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # 404 and other refusals are answers; a server error or a rate limit is not.
        if error.code >= 500 or error.code == 429:
            raise Unreachable(f"HTTP {error.code}") from error
        return None
    except (urllib.error.URLError, OSError, ValueError) as error:
        raise Unreachable(str(error)) from error


def folded(text):
    return re.sub(r"\W+", " ", text.casefold()).strip()


def has_lyrics(record):
    return bool(record and (record.get("syncedLyrics") or record.get("plainLyrics") or record.get("instrumental")))


def lookup(artist, title, album, seconds):
    """The exact record, else the best of a few searches: timed lyrics first, then the closest length."""
    unreachable = False

    if artist and seconds > 0:
        params = {"artist_name": artist, "track_name": title, "duration": round(seconds)}
        if album:
            params["album_name"] = album
        try:
            record = ask("get", params)
            if has_lyrics(record) and record.get("syncedLyrics"):
                return record
        except Unreachable:
            unreachable = True

    # Spotify lists every artist ("A, B"): lrclib often has only the first.
    first_artist = re.split(r",\s*|\s+&\s+", artist)[0] if artist else ""
    song = FEATURING.sub("", SUFFIX.sub("", title)).strip() or title
    searches = [{"track_name": title, "artist_name": artist}]
    if song != title or first_artist != artist:
        searches.append({"track_name": song, "artist_name": first_artist})
    searches.append({"q": f"{first_artist} {song}".strip()})

    def fits(record):
        if not has_lyrics(record):
            return False
        if seconds > 0 and abs((record.get("duration") or 0) - seconds) > LENGTH_TOLERANCE:
            return False
        # A free search matches any word: the artist must be the one playing.
        singer = folded(record.get("artistName") or "")
        wanted = folded(first_artist)
        return not wanted or wanted in singer or singer in folded(artist)

    found = []
    for params in searches:
        params = {key: value for key, value in params.items() if value}
        try:
            found += [record for record in ask("search", params) or [] if fits(record)]
        except Unreachable:
            unreachable = True
            continue
        if any(record.get("syncedLyrics") for record in found):
            break

    if not found:
        if unreachable:
            raise Unreachable("no answer")
        return None
    return min(found, key=lambda record: (not record.get("syncedLyrics"), abs((record.get("duration") or 0) - seconds)))


def parse(record):
    if record.get("instrumental"):
        return {"status": "found", "synced": False, "instrumental": True, "lines": []}

    lines = []
    for raw in (record.get("syncedLyrics") or "").splitlines():
        text = STAMP.sub("", raw).strip()
        # A line sung several times carries one stamp per time.
        for minutes, seconds in STAMP.findall(raw):
            lines.append({"t": int(minutes) * 60 + float(seconds), "text": text})
    if lines:
        lines.sort(key=lambda line: line["t"])
        return {"status": "found", "synced": True, "instrumental": False, "lines": lines}

    plain = [line.strip() for line in (record.get("plainLyrics") or "").splitlines()]
    if any(plain):
        return {"status": "found", "synced": False, "instrumental": False,
                "lines": [{"t": -1, "text": line} for line in plain]}
    return {"status": "missing"}


def report(artist, title, album, seconds):
    if not title:
        return {"status": "missing"}

    path = cache_path(artist, title, album, seconds)
    try:
        with open(path) as file:
            kept = json.load(file)
        if kept["status"] == "found" or time.time() - kept.get("at", 0) < MISS_LIFETIME:
            kept.pop("at", None)
            return kept
    except (OSError, ValueError, KeyError):
        pass

    try:
        record = lookup(artist, title, album, seconds)
    except Unreachable as error:
        sys.stderr.write(f"lyrics-lookup: {error}\n")
        return {"status": "network"}

    result = parse(record) if record else {"status": "missing"}
    staging = path + ".tmp"
    with open(staging, "w") as file:
        json.dump({**result, "at": time.time()}, file)
    os.replace(staging, path)
    return result


def main():
    args = sys.argv[1:] + [""] * 4
    try:
        seconds = float(args[3] or 0)
    except ValueError:
        seconds = 0
    try:
        result = report(args[0].strip(), args[1].strip(), args[2].strip(), seconds)
    except Exception as error:  # The shell only reads the JSON line.
        sys.stderr.write(f"lyrics-lookup failed: {error}\n")
        result = {"status": "network"}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
