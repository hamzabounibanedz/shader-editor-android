#!/usr/bin/env bash
set -euo pipefail
mkdir -p delivery/evidence
adb install -r delivery/wayloom-transit.apk
adb install -r android/app/build/outputs/apk/androidTest/release/*.apk
adb shell wm size 1080x2160
adb shell wm density 400
adb shell settings put global window_animation_scale 0
adb shell am instrument -w -r 'app.hamzabounibanedz.way.test/androidx.test.runner.AndroidJUnitRunner' | tee delivery/evidence/instrumentation.txt
adb pull '/sdcard/Android/data/app.hamzabounibanedz.way/files/evidence/.' delivery/evidence/ || true
adb logcat -d -s AndroidRuntime:E chromium:E > delivery/evidence/runtime-errors.txt
grep -Eq 'OK \(1 test\)' delivery/evidence/instrumentation.txt
test -s delivery/evidence/catalog.png
test -s delivery/evidence/workflow.png

