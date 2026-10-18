#!/usr/bin/env bash
# Build the launcher APK and install it on the TV as the default home screen.
set -euo pipefail
cd "$(dirname "$0")"
: "${TV_HOST:?set TV_HOST to the TV IP address, e.g. TV_HOST=192.168.1.50 $0}"
STOCK_LAUNCHER="${STOCK_LAUNCHER:-com.google.android.tvlauncher}"
# FIRE_TV=1: install only. Fire OS has no default-home setting and disabling the stock launcher can brick the UI.
FIRE_TV="${FIRE_TV:-0}"
# FIRE_HOME_REDIRECT=1 (with FIRE_TV=1): turn on the accessibility service that sends Home to this launcher.
FIRE_HOME_REDIRECT="${FIRE_HOME_REDIRECT:-0}"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 17 2>/dev/null || echo /opt/homebrew/opt/openjdk@17)}"
export ANDROID_HOME="${ANDROID_HOME:-$([ -d ~/Library/Android/sdk ] && echo ~/Library/Android/sdk || echo /opt/homebrew/share/android-commandlinetools)}"
export PATH="$JAVA_HOME/bin:$PATH"
[ -f local.properties ] || echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew assembleDebug -q --console=plain
PY=../tools/venv/bin/python
[ -x "$PY" ] || PY=../tools/venv/Scripts/python.exe
export MSYS_NO_PATHCONV=1
APK=app/build/outputs/apk/debug/app-debug.apk
"$PY" -I ../tools/b64push.py "$APK" /data/local/tmp/tvhome.apk
{
  echo "pm install -r /data/local/tmp/tvhome.apk"
  echo "rm -f /data/local/tmp/tvhome.apk"
  echo "pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION 2>/dev/null; echo location-granted"
  if [ "$FIRE_TV" = 1 ] && [ "$FIRE_HOME_REDIRECT" = 1 ]; then
    # toggle off and on: reinstalling the app can leave the service unbound
    echo "settings put secure enabled_accessibility_services ''"
    echo "settings put secure enabled_accessibility_services com.gathin.tvhome/.HomeRedirectService"
    echo "settings put secure accessibility_enabled 1"
  fi
  if [ "$FIRE_TV" != 1 ]; then
    echo "cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity"
    echo "pm disable-user --user 0 $STOCK_LAUNCHER"
  fi
} | "$PY" -I ../tools/tv.py --batch
echo "Installed. Press Home on the remote to see it."
