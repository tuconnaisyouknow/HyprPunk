#!/usr/bin/env bash
# What the shell remembers of what you do: the clipboard history (Super+V), whether it's
# kept and how much of it, and the launcher's and emoji picker's recent picks. Every copy
# comes through here (autostart.lua), so turning the history off stops it at once. The
# settings window and `hyprpunk history` change it.
#   historyctl.sh get                         every setting, as key=value
#   historyctl.sh set clipboard <true|false>  keep a clipboard history
#   historyctl.sh set size <items>            how many copies it keeps
#   historyctl.sh store <text|image>          what wl-paste --watch runs on each copy
#   historyctl.sh list                        the copies, newest first (the clipboard panel)
#   historyctl.sh copy <entry>                puts a copy back on the clipboard
#   historyctl.sh clear <clipboard|launcher|emoji>
#   historyctl.sh count                       how much each history holds, as key=value
#   historyctl.sh ensure                      fills in what's missing (install.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
# shellcheck source=lib/settings.sh
source "$script_dir/lib/settings.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hyprpunk"
STATE_FILE="$STATE_DIR/history.conf"
# One file per copy, named by its content and kind (<hash>.txt, <hash>.png…, <hash>.uris
# for files), so the same copy twice is one file. Its modification time is when you last
# copied it.
CLIPBOARD="$STATE_DIR/clipboard"
# What the copies may weigh together, the newest always kept: no copy is too large, but
# a few 4K screenshots a day would otherwise fill the disk. About twenty of them.
BUDGET=$((256 * 1024 * 1024))

declare -A DEFAULTS=(
  [clipboard]=true
  [size]=750
)
KEYS=(clipboard size)

valid() {
  case "$1" in
  clipboard) [[ "$2" == "true" || "$2" == "false" ]] ;;
  size) [[ "$2" =~ ^[1-9][0-9]*$ ]] ;;
  esac
}

# The copies' names, newest first
entries() {
  find "$CLIPBOARD" -maxdepth 1 -type f ! -name '.*' -printf '%T@ %f\n' 2>/dev/null |
    sort -rn | cut -d' ' -f2-
}

# Writes the copy on stdin as text, an image or files and prints "new <path>", or "seen <path>"
# when it's already there. Nothing for an empty copy, one of blanks only, or an image
# type that isn't one. In its own process, so its temporary file goes with it, even when
# the session ends in the middle of a long copy.
write_entry() (
  mkdir -p "$CLIPBOARD"
  local copy ext entry
  copy=$(mktemp "$CLIPBOARD/.copy.XXXXXX")
  trap 'rm -f "$copy"' EXIT
  trap 'exit 1' HUP INT TERM
  cat >"$copy"
  case "$1" in
  text) grep -q '[^[:space:]]' "$copy" && ext=txt ;;
  image) ext=$(file -b --mime-type "$copy") && ext=${ext#image/} ;;
  files) ext=uris ;;
  esac
  [[ -s "$copy" && "${ext:-}" =~ ^[a-z0-9.+-]+$ ]] || return 0
  entry="$CLIPBOARD/$(b2sum "$copy" | cut -c1-32).$ext"
  if [[ -e "$entry" ]]; then
    printf 'seen %s\n' "$entry"
  else
    mv "$copy" "$entry"
    printf 'new %s\n' "$entry"
  fi
)

# The oldest go past the number of copies kept or the budget
trim() {
  local count=0 bytes=0 size name
  while read -r size name; do
    count=$((count + 1))
    bytes=$((bytes + size))
    if ((count > 1 && (count > ${SETTINGS[size]} || bytes > BUDGET))); then
      rm -f "$CLIPBOARD/$name"
    fi
  done < <(find "$CLIPBOARD" -maxdepth 1 -type f ! -name '.*' -printf '%T@ %s %f\n' 2>/dev/null |
    sort -rn | cut -d' ' -f2-)
}

# What cliphist kept before, brought over as older than every copy since, so an update
# that copies before it imports loses nothing. A copy it can't read is skipped, and
# cliphist is emptied once it's all here, so it's brought over only once.
import_cliphist() {
  command -v cliphist >/dev/null && [[ -n "$(cliphist list 2>/dev/null | head -1)" ]] || return 0
  local oldest id preview kind written i=0
  oldest=$(find "$CLIPBOARD" -maxdepth 1 -type f ! -name '.*' -printf '%T@\n' 2>/dev/null | sort -n | head -1)
  oldest=${oldest%.*}
  oldest=${oldest:-$(date +%s)}
  mapfile -t lines < <(cliphist list)
  for ((n = ${#lines[@]} - 1; n >= 0; n--)); do
    IFS=$'\t' read -r id preview <<<"${lines[n]}"
    kind=text
    [[ "$preview" == '[[ binary data '* ]] && kind=image
    written=$(cliphist decode "$id" 2>/dev/null | write_entry "$kind") || continue
    i=$((i + 1))
    [[ "$written" == new\ * ]] && touch -d "@$((oldest - ${#lines[@]} - 1 + i))" "${written#new }"
  done
  cliphist wipe
  # The thumbnails the panel decoded from cliphist
  rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/hyprpunk/clipboard"
}

# "PNG · 3840x2160 · 11 MiB". file names each image's size last (a JPEG's density comes first).
image_label() {
  local name=$1 description=$2 bytes=$3 label
  label=${name##*.}
  label=${label^^}
  [[ "$description" =~ .*[^0-9]([0-9]+)\ ?x\ ?([0-9]+) ]] && label+=" · ${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
  if ((bytes >= 1048576)); then
    label+=" · $(((bytes + 524288) / 1048576)) MiB"
  else
    label+=" · $(((bytes + 512) / 1024)) KiB"
  fi
  printf '%s' "$label"
}

case "${1:-}" in
# The copy comes on stdin. What a password manager marks as sensitive, or an emptied
# clipboard, isn't a copy to keep (CLIPBOARD_STATE). One copy is one entry, of the
# richest kind it offers: files, then text, then an image. Files copied in a file
# manager come with their paths as text, and a range of cells with its picture.
store)
  [[ "${2:-}" == "text" || "${2:-}" == "image" ]] || {
    echo "Usage: $(basename "$0") store <text|image>" >&2
    exit 1
  }
  settings_load
  types=$(wl-paste --list-types 2>/dev/null || true)
  if [[ "${SETTINGS[clipboard]}" != "true" || "${CLIPBOARD_STATE:-data}" != "data" ]] ||
    { [[ "$2" == "image" ]] && grep -qx 'text/plain;charset=utf-8' <<<"$types"; }; then
    cat >/dev/null
    exit 0
  fi
  # Local files only: a link copied in a browser stays text. The text is read first, so
  # the app never waits on one answer while it's asked for another.
  uris=
  if [[ "$2" == "text" ]] && grep -qx 'text/uri-list' <<<"$types"; then
    # Its last newlines too, which $(...) would drop
    text=$(
      cat
      printf x
    )
    text=${text%x}
    uris=$(wl-paste --type text/uri-list 2>/dev/null | tr -d '\r' | grep -v '^#' | grep -v '^$' || true)
    [[ -n "$uris" ]] && ! grep -qv '^file://' <<<"$uris" || uris=
  fi
  if [[ -n "$uris" ]]; then
    written=$(printf '%s\n' "$uris" | write_entry files)
  elif [[ -v text ]]; then
    written=$(printf '%s' "$text" | write_entry text)
  else
    written=$(write_entry "$2")
  fi
  [[ -n "$written" ]] || exit 0
  touch "${written#* }"
  trim
  ;;
# One "path<TAB>text<TAB>image" line per copy: the start of a text on one line, an
# image's format, size and weight with its path again, or the files' names with the
# file itself when it's one picture. Images are labelled in one call to file, texts and
# files read without leaving bash, so a long history lists at once.
list)
  mapfile -t names < <(entries)
  images=()
  for name in "${names[@]}"; do
    [[ "$name" == *.txt || "$name" == *.uris ]] || images+=("$CLIPBOARD/$name")
  done
  declare -A descriptions=()
  if ((${#images[@]})); then
    mapfile -t described < <(file -N -b -- "${images[@]}")
    for i in "${!images[@]}"; do
      descriptions[${images[i]}]=${described[i]}
    done
  fi
  for name in "${names[@]}"; do
    path="$CLIPBOARD/$name"
    if [[ "$name" == *.txt ]]; then
      text=
      read -r -d '' -N 200 text <"$path" || true
      text=${text//[$'\n\t\r']/ }
      text=${text#"${text%%[![:space:]]*}"}
      printf '%s\t%s\t\n' "$path" "$text"
    elif [[ "$name" == *.uris ]]; then
      mapfile -t uris <"$path"
      files=()
      for uri in "${uris[@]}"; do
        file=${uri#file://}
        printf -v file '%b' "${file//%/\\x}"
        files+=("${file%/}")
      done
      text=${files[0]##*/}
      ((${#files[@]} == 2)) && text+=", ${files[1]##*/}"
      ((${#files[@]} > 2)) && text+=", ${files[1]##*/} and $((${#files[@]} - 2)) more"
      picture=
      [[ ${#files[@]} == 1 && -f "${files[0]}" && "${files[0],,}" =~ \.(png|jpe?g|webp|gif|bmp|avif|svg)$ ]] && picture=${files[0]}
      printf '%s\t%s\t%s\n' "$path" "$text" "$picture"
    else
      bytes=$(stat -c %s "$path")
      printf '%s\t%s\t%s\n' "$path" "$(image_label "$name" "${descriptions[$path]}" "$bytes")" "$path"
    fi
  done
  ;;
# Back with the type it came with, so an image pastes as an image and files as files.
# The watcher sees it again and brings it to the top.
copy)
  [[ -f "${2:-}" ]] || {
    echo "Usage: $(basename "$0") copy <entry>" >&2
    exit 1
  }
  case "$2" in
  *.txt) type='text/plain;charset=utf-8' ;;
  *.uris) type=text/uri-list ;;
  *) type="image/${2##*.}" ;;
  esac
  exec wl-copy --type "$type" <"$2"
  ;;
# The panels watch their history files, so an empty one empties them on the spot
clear)
  case "${2:-}" in
  clipboard) rm -rf "$CLIPBOARD" && mkdir -p "$CLIPBOARD" ;;
  launcher) printf '{}' >"$STATE_DIR/launcher-history.json" ;;
  emoji) printf '[]' >"$STATE_DIR/emoji-history.json" ;;
  *)
    echo "Usage: $(basename "$0") clear <clipboard|launcher|emoji>" >&2
    exit 1
    ;;
  esac
  ;;
# A history that was never written holds nothing
count)
  echo "clipboard=$(entries | wc -l)"
  echo "launcher=$(jq length "$STATE_DIR/launcher-history.json" 2>/dev/null || echo 0)"
  echo "emoji=$(jq length "$STATE_DIR/emoji-history.json" 2>/dev/null || echo 0)"
  ;;
ensure)
  import_cliphist
  settings_main "$@"
  ;;
*) settings_main "$@" ;;
esac
