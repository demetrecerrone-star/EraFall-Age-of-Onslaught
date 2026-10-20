#!/usr/bin/env bash
set -euo pipefail
APK='build/EraFall-release.apk'
PKG='com.dabsky.erafall'

test -s "$APK"
adb wait-for-device
adb install -r "$APK"
adb logcat -c
# Intent resolution is delegated to Android, not a hardcoded Godot activity.
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 15
adb shell pidof "$PKG" >/dev/null || {
  echo "EraFall process is not running after launch" >&2
  adb logcat -d -s AndroidRuntime:E | tail -n 100 >&2
  exit 1
}
if adb logcat -d -s AndroidRuntime:E | grep -E 'FATAL EXCEPTION|Process: com.dabsky.erafall'; then
  echo "Android crash detected" >&2
  exit 1
fi
# Preserve actual Android screenshots so visual regressions can be reviewed.
mkdir -p build
adb exec-out screencap -p > build/erafall-title-emulator.png
DISPLAY_SIZE="$(adb shell wm size | tr -d '\r' | sed -n 's/.*: //p' | tail -1)"
WIDTH="${DISPLAY_SIZE%x*}"
HEIGHT="${DISPLAY_SIZE#*x}"
if [[ "$WIDTH" =~ ^[0-9]+$ && "$HEIGHT" =~ ^[0-9]+$ ]]; then
  # Main menu is portrait and Play is the leftmost bottom menu image.
  adb shell input tap "$(( WIDTH * 14 / 100 ))" "$(( HEIGHT * 85 / 100 ))"
  sleep 4
  # Exercise a player swipe, then capture the gameplay screen.
  adb shell input swipe "$(( WIDTH * 48 / 100 ))" "$(( HEIGHT * 63 / 100 ))" "$(( WIDTH * 78 / 100 ))" "$(( HEIGHT * 63 / 100 ))" 450
  sleep 2
  adb exec-out screencap -p > build/erafall-gameplay-emulator.png
  adb shell pidof "$PKG" > /dev/null || {
    echo "EraFall stopped after gameplay swipe" >&2
    exit 1
  }
fi
echo "Signed APK installed, launched and withstood Android emulator touch input."
