#!/bin/bash
# Runs all unit tests: Dart (when test/ has any) and Android JVM tests.
# Optionally also runs the device tests: Android instrumented tests and Flutter
# integration tests (when integration_test/ has any).
set -e

cd "$(dirname "$0")"

has_dart_tests() {
  compgen -G "$1/*_test.dart" > /dev/null || compgen -G "$1/**/*_test.dart" > /dev/null
}

run_device_tests=false
# Only ask when run interactively; CI runs unit tests only.
if [ -t 0 ]; then
  echo "Device tests need an Android device or emulator connected via adb."
  read -r -p "Also run device tests (runs ALL tests)? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] && run_device_tests=true
fi

if $run_device_tests && ! adb devices | grep -qw "device$"; then
  echo "No Android device connected via adb (see 'adb devices'). Aborting." >&2
  exit 1
fi

if has_dart_tests test; then
  flutter test
fi

# The plugin's Gradle module is built through the example app.
gradle_tasks=(:simple_media:testDebugUnitTest)
if $run_device_tests; then
  gradle_tasks+=(:simple_media:connectedDebugAndroidTest)
fi
(cd example/android && ./gradlew "${gradle_tasks[@]}")

if $run_device_tests && has_dart_tests integration_test; then
  (cd example && flutter test ../integration_test)
fi
