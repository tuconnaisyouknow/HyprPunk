#!/usr/bin/env bash
# Gives Papirus's folders the wallpaper's accent. Each accent gets its own icon theme,
# HyprPunk-<accent>: Papirus-Dark's folders recolored, everything else inherited. Open
# apps only reload icons when the theme's name changes, so a new accent is a new theme.
# wallpaperctl.sh runs apply once matugen has written the folder colors
# (folder-colors.template).
#   foldersctl.sh apply   builds the accent's theme if needed, and moves every app to it
#   foldersctl.sh name    prints the theme apps should use (qt-configctl.sh)
set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
COLORS_FILE="$STATE_HOME/hyprpunk/folder-colors"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
SKELETON="${XDG_CACHE_HOME:-$HOME/.cache}/hyprpunk/papirus-folders"
PAPIRUS=/usr/share/icons/Papirus-Dark
LOCK_FILE="$STATE_HOME/hyprpunk/folders.lock"

# The folder's front, its back and the symbol on it, as matugen wrote them
read_colors() {
  read -r front back symbol <"$COLORS_FILE"
}

# Papirus-Dark until matugen has written the colors once
theme_name() {
  if [[ -r "$COLORS_FILE" ]]; then
    read_colors
    printf 'HyprPunk-%s\n' "${front#\#}"
  else
    echo Papirus-Dark
  fi
}

# The skeleton and the themes are rebuilt when Papirus changes under them (an update)
papirus_stamp() {
  stat -c %Y "$PAPIRUS/index.theme"
}

# Papirus-Dark's places, where the folders are, by size
places_dirs() {
  awk -F'[][]' '/^\[[^]]*\/places\]$/ { print $2 }' "$PAPIRUS/index.theme"
}

# The sizes built, as Papirus declares them. Each theme puts its own name in.
write_index() {
  awk -v built=" $* " '
    /^\[/ { section = substr($0, 2, length($0) - 2); keep = index(built, " " section " ") > 0 }
    keep { body = body $0 "\n" }
    keep && /^\[/ { if (section ~ /@/) scaled = scaled "," section; else plain = plain "," section }
    END {
      print "[Icon Theme]"
      print "Name=HyprPunk"
      print "Comment=Papirus-Dark with folders in the wallpaper'"'"'s accent, built by foldersctl.sh"
      print "Inherits=Papirus-Dark"
      print "Directories=" substr(plain, 2)
      print "ScaledDirectories=" substr(scaled, 2)
      printf "\n%s", body
    }' "$PAPIRUS/index.theme"
}

# What every accent's theme shares, built once for each Papirus: its grey folders, the
# names that lead to them and the index. Papirus names each folder after its color
# (folder-grey-music) and links the plain names to the color papirus-folders picked,
# some through others (folder-txt to folder-documents). Every name that ends on a
# folder of that color leads to the grey one here, whichever color is picked. The grey
# files are listed in .recolor for the themes to paint.
build_skeleton() {
  local tmp dir source real picked link target final grey
  local -a built=()
  local -A links copies

  mkdir -p "$(dirname "$SKELETON")"
  rm -rf -- "$SKELETON".*
  tmp=$(mktemp -d "$SKELETON.XXXXXX")

  for dir in $(places_dirs); do
    source="$PAPIRUS/$dir"
    [[ "$dir" != */symbolic* && -e "$source/folder.svg" ]] || continue
    built+=("$dir")
    mkdir -p "$(dirname "$tmp/$dir")"

    # At 16px Papirus draws folders in the text's color. They're its own here too, or
    # GTK would shrink our 22px ones before looking in Papirus.
    if [[ ! -L "$source/folder.svg" ]]; then
      ln -s "$(realpath "$source")" "$tmp/$dir"
      continue
    fi

    # Sizes Papirus draws once (22x22@2x is 22x22) share one copy
    real=$(realpath "$source")
    if [[ -v "copies[$real]" ]]; then
      ln -s "../${copies[$real]}" "$tmp/$dir"
      continue
    fi
    copies[$real]=$dir

    picked=$(readlink "$source/folder.svg")
    picked=${picked#folder-}
    picked=${picked%.svg}
    mkdir "$tmp/$dir"

    links=()
    while read -r link target; do
      links[$link]=$target
    done < <(find "$source/" -maxdepth 1 -name '*.svg' -type l -printf '%f %l\n')

    for link in "${!links[@]}"; do
      final=${links[$link]}
      while [[ -v "links[$final]" ]]; do final=${links[$final]}; done
      [[ "$final" == folder-"$picked"* || "$final" == user-"$picked"* ]] || continue
      grey=${final/-"$picked"/-grey}
      [[ -f "$source/$grey" ]] || continue
      if [[ ! -e "$tmp/$dir/$grey" ]]; then
        cp "$source/$grey" "$tmp/$dir/$grey"
        echo "$dir/$grey" >>"$tmp/.recolor"
      fi
      ln -s "$grey" "$tmp/$dir/$link"
    done
  done

  write_index "${built[@]}" >"$tmp/index.theme"
  papirus_stamp >"$tmp/.papirus"
  rm -rf -- "$SKELETON"
  mv -T "$tmp" "$SKELETON"
}

# An accent's theme is the skeleton painted: one copy, one pass of sed
build_theme() {
  local name="$1" tmp

  [[ "$(cat "$SKELETON/.papirus" 2>/dev/null)" == "$(papirus_stamp)" ]] || build_skeleton

  tmp=$(mktemp -d "$ICONS/.$name.XXXXXX")
  cp -a "$SKELETON/." "$tmp/"
  # Papirus's grey: #8e8e8e in front, #727272 behind, #323232 for the symbol
  # shellcheck disable=SC2046 # one file a line, none with a space
  (cd "$tmp" && sed -i -e "s/#8e8e8e/$front/gI" -e "s/#727272/$back/gI" -e "s/#323232/$symbol/gI" \
    -e "s/^Name=HyprPunk$/Name=$name/" index.theme $(<.recolor))
  rm -- "$tmp/.recolor"

  rm -rf -- "${ICONS:?}/$name"
  mv -T "$tmp" "$ICONS/$name"
}

# GTK follows gsettings, Qt apps their qt5ct and qt6ct files, KDE apps kdeglobals once
# told. The theme left behind stays for an app that hasn't moved yet; older ones go.
switch_to() {
  local name="$1" previous theme

  previous=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
  gsettings set org.gnome.desktop.interface icon-theme "$name"
  "$script_dir/qt-configctl.sh" restore all >/dev/null
  dbus-send --session --type=signal /KIconLoader org.kde.KIconLoader.iconChanged int32:0 2>/dev/null || true

  for theme in "$ICONS"/HyprPunk-*/; do
    theme=$(basename "$theme")
    [[ "$theme" == "$name" || "$theme" == "$previous" ]] || rm -rf -- "${ICONS:?}/$theme"
  done
}

apply() {
  local name

  [[ -r "$COLORS_FILE" ]] || {
    echo "No folder colors yet: matugen writes them with the wallpaper's palette." >&2
    return 1
  }
  read_colors
  name=$(theme_name)
  mkdir -p "$ICONS"

  # Two quick wallpaper changes build one after the other. A build cut short left its
  # half-made theme behind.
  exec 9>"$LOCK_FILE"
  flock 9
  rm -rf -- "$ICONS"/.HyprPunk-*
  if [[ "$(cat "$ICONS/$name/.papirus" 2>/dev/null)" != "$(papirus_stamp)" ]]; then
    build_theme "$name"
  fi
  switch_to "$name"
}

case "${1:-}" in
apply) apply ;;
name) theme_name ;;
*)
  echo "Usage: $(basename "$0") <apply|name>" >&2
  exit 1
  ;;
esac
