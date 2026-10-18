#!/usr/bin/env bash
# Re-enable every package listed in a debloat file, restore the stock launcher as home and reset
# animation scales. Pass the same list you used with tools/disable.sh.
#
# Usage: TV_HOST=192.168.1.50 tools/restore.sh examples/xiaomi-mi-tv-4a/debloat.txt [stock.launcher.package]
#
# FIRE_TV=1  Fire OS: never touch the home activity (com.amazon.tv.launcher stays as it is). If backup/
#            exists (see README), also re-enable anything disabled since the backup and put the backed-up
#            screensaver and accessibility settings back.
# DRY_RUN=1  print the commands instead of running them on the TV.
set -euo pipefail
cd "$(dirname "$0")/.."
LIST="${1:?usage: restore.sh <debloat list> [stock launcher package]}"
STOCK="${2:-com.google.android.tvlauncher}"
FIRE_TV="${FIRE_TV:-0}"
DRY_RUN="${DRY_RUN:-0}"
BACKUP=backup
PY=tools/venv/bin/python
[ -x "$PY" ] || PY=tools/venv/Scripts/python.exe
export MSYS_NO_PATHCONV=1

# value of a key in a `settings list` dump, or empty
backup_setting() { sed -n "s/^$2=//p" "$BACKUP/settings-$1.txt" 2>/dev/null | head -n 1; }

commands() {
  grep -vE '^\s*(#|$)' "$LIST" | sed -E 's/[[:space:]]+#.*$//' | awk '{print "pm enable " $1}'
  if [ "$FIRE_TV" = 1 ]; then
    if [ -f "$BACKUP/packages-disabled.txt" ]; then
      # anything disabled on the TV now that was enabled when the backup was taken
      "$PY" -I tools/tv.py pm list packages -d | tr -d '\r' | sort \
        | comm -23 - <(tr -d '\r' < "$BACKUP/packages-disabled.txt" | sort) \
        | sed -n 's/^package:/pm enable /p'
    fi
    for key in screensaver_components screensaver_enabled enabled_accessibility_services accessibility_enabled; do
      [ -f "$BACKUP/settings-secure.txt" ] || break
      val="$(backup_setting secure "$key")"
      if [ -n "$val" ] && [ "$val" != null ]; then echo "settings put secure $key $val"; else echo "settings delete secure $key"; fi
    done
  else
    echo "pm enable $STOCK"
    # resolve the stock HOME component on the TV (Android 9 needs pkg/activity, not just pkg)
    echo "cmd package set-home-activity --user 0 \$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME $STOCK | tail -n 1)"
  fi
  echo "settings put global window_animation_scale 1.0"
  echo "settings put global transition_animation_scale 1.0"
  echo "settings put global animator_duration_scale 1.0"
  echo "pm list packages -d"
}

if [ "$DRY_RUN" = 1 ]; then
  commands | awk '!seen[$0]++'
else
  commands | awk '!seen[$0]++' | "$PY" -I tools/tv.py --batch
fi
