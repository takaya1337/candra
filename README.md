# Candra

An almanac of sacred time: a calendar and private journal that reads every
day through five calendars at once, the Javanese weton, the Javanese, the
Chinese, the Hijri and the Gregorian, with the tools each brings (prayer
times and the hilal, the bazi chart, the pranata mangsa and Lintang Jawa,
the sun, moon, planets and stars). Everything is worked out on the phone,
and the journal never leaves it unless its keeper sends it.

- The app: [suryamajapahit.com/candra](https://suryamajapahit.com/candra)
- Changes, version by version: [suryamajapahit.com/candra/code](https://suryamajapahit.com/candra/code#changes)
- Privacy: [Android](https://suryamajapahit.com/candra/privacy/android), [iPhone and iPad](https://suryamajapahit.com/candra/privacy/ios)

## What is here

| Folder | What it is |
|---|---|
| `app/` | The Flutter app: the screens, the journal's storage and sync, and the phone side for Android and iOS (widgets, the Live Activity, the native bar) |
| `packages/sacred_time/` | The calendar and astronomy engine, pure Dart with no dependencies: weton, the Javanese, Hijri and Chinese calendars, the sun and moon (VSOP87, Meeus), stars and planets, prayer times, bazi and the pranata mangsa |
| `packages/sm_design/` | The design system: tokens, pressables, the text field and the fonts, on Flutter's `widgets` alone, with nothing from Material or Cupertino |

## Building

With Flutter (stable) installed:

```
cd app
flutter pub get
flutter test
flutter run
```

The engine's own tests: `cd packages/sacred_time && dart test`.

A release build is obfuscated and keeps its symbols apart:
`app/tool/build_release.sh` for Android. It signs with the key named in
`app/android/key.properties` if there is one, and with the debug key if
not; no key is in this repository. For iOS, set your own team in Xcode.

## Licence

Candra's code is under the PolyForm Noncommercial License 1.0.0
([`LICENSE`](LICENSE)): free to use, study, change and share for any
noncommercial purpose, personal use and religious observance among them,
and by charities, schools, research and public bodies. Selling it, putting
ads in it, or any other commercial use needs the owner's permission.
Copyright (C) 2026 <the owner's name>.

The name "Candra" and its sigil are not licensed with the code: a copy
or a work built on it may not carry them.

The data and fonts it carries keep their own licences: see
[`NOTICE.md`](NOTICE.md).
