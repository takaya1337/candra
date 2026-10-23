#!/bin/sh
# Builds the Android release: the bundle for Play and the two APKs for
# handing out, into build/candra-<version>.*
#
# The source is closed, so the release is made as hard to read back as
# the tools allow:
#
#   --obfuscate           every Dart class, function and field is renamed
#                         to nothing meaningful
#   --split-debug-info    the names and line numbers are kept OUT of the
#                         app, in a folder beside the signing key; that
#                         folder is the only way to read a crash report
#                         from this build, so it is kept with the key and
#                         never shipped
#   R8 (build.gradle.kts) the Kotlin and Java side is shrunk and renamed
#
# What this cannot hide: the text the app shows, the names of its assets
# and their contents, and what the code does to anyone who reads the
# machine code itself. It takes away the map, not the territory.
#
# Usage: tool/build_release.sh [extra flutter flags, e.g. --dart-define=...]
set -e
cd "$(dirname "$0")/.."

version=$(grep '^version:' pubspec.yaml | sed 's/version: //')
name=${version%%+*}
symbols="../keys/symbols/$version"
mkdir -p "$symbols"

flags="--release --obfuscate --split-debug-info=$symbols $*"

flutter build appbundle $flags
cp build/app/outputs/bundle/release/app-release.aab "build/candra-$name.aab"
flutter build apk $flags
cp build/app/outputs/flutter-apk/app-release.apk "build/candra-$name.apk"
flutter build apk $flags --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk "build/candra-$name-arm64.apk"

ls -la build/candra-"$name"*
echo "Symbols for reading crash reports: $symbols (keep with the signing key)"
