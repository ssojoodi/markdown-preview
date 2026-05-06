#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "usage: create_dmg.sh <app-path> <dmg-path> <volume-name> <background-png> <work-dir>" >&2
  exit 2
fi

app_path=$1
dmg_path=$2
volume_name=$3
background_png=$4
work_dir=$5

app_name=$(basename "$app_path")
staging_dir="$work_dir/dmg-root"
rw_dmg="$work_dir/$volume_name.rw.dmg"
mount_dir="/Volumes/$volume_name"
mounted=0

cleanup() {
  if [ "$mounted" -eq 1 ]; then
    hdiutil detach "$mount_dir" -quiet || true
  fi
}
trap cleanup EXIT

if [ ! -d "$app_path" ]; then
  echo "app not found: $app_path" >&2
  exit 1
fi

if [ ! -f "$background_png" ]; then
  echo "background not found: $background_png" >&2
  exit 1
fi

if [ -e "$mount_dir" ]; then
  echo "volume is already mounted: $mount_dir" >&2
  exit 1
fi

rm -rf "$staging_dir" "$rw_dmg" "$dmg_path"
mkdir -p "$staging_dir/.background" "$work_dir" "$(dirname "$dmg_path")"

ditto "$app_path" "$staging_dir/$app_name"
ln -s /Applications "$staging_dir/Applications"
cp "$background_png" "$staging_dir/.background/background.png"

hdiutil create \
  -quiet \
  -volname "$volume_name" \
  -srcfolder "$staging_dir" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$rw_dmg"

hdiutil attach "$rw_dmg" -quiet -readwrite -noverify -noautoopen -mountpoint "$mount_dir"
mounted=1

osascript - "$volume_name" "$app_name" <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv
  set appName to item 2 of argv

  tell application "Finder"
    tell disk volumeName
      open
      delay 1

      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {100, 100, 760, 500}

      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 104
      set background picture of viewOptions to file ".background:background.png"

      set position of item appName of container window to {169, 230}
      set position of item "Applications" of container window to {491, 230}

      update without registering applications
      delay 1
      close
    end tell
  end tell
end run
APPLESCRIPT

sync
hdiutil detach "$mount_dir" -quiet
mounted=0

hdiutil convert "$rw_dmg" -quiet -format UDZO -imagekey zlib-level=9 -o "$dmg_path"
hdiutil verify "$dmg_path" -quiet
rm -rf "$staging_dir" "$rw_dmg"
