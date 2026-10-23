# Candra (the app)

The Flutter app: the screens, the journal's storage and sync, and the
phone side for Android and iOS.

- Run the tests: `flutter test`
- Make a release: `tool/build_release.sh` (obfuscated, its symbols kept
  apart). A plain `flutter build` is not a release.
- The data generators in `tool/gen_*.py` are run by hand, never by the
  app; they show how the bundled tables were made from their sources.
