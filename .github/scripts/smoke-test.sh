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
echo "Signed APK installed and EraFall remained running on the Android emulator."
