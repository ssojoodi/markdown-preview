#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: publish_dmg.sh <verified-dmg> <website-dmg> <backup-dir>" >&2
  exit 2
fi

source_dmg=$1
website_dmg=$2
backup_dir=$3

if [ ! -s "$source_dmg" ]; then
  echo "release DMG is missing or empty: $source_dmg" >&2
  exit 1
fi

mkdir -p "$(dirname "$website_dmg")"
staged_dmg=$(mktemp "${website_dmg}.XXXXXX")
trap 'rm -f "$staged_dmg"' EXIT
cp -p "$source_dmg" "$staged_dmg"

if [ -f "$website_dmg" ]; then
  mkdir -p "$backup_dir"
  name=$(basename "$website_dmg" .dmg)
  backup="$backup_dir/$name-$(date -u +%Y-%m-%d-%H-%M-%S)-$$.dmg"
  test ! -e "$backup"
  cp -p "$website_dmg" "$backup"
  echo "Archived previous DMG: $backup"
fi

# Rename within the website directory so readers never see a partial download.
mv -f "$staged_dmg" "$website_dmg"
