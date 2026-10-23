# Candra code audit, 23 October 2026

A read-only review of this repository as published: the app (`app/`), the
calendar and astronomy engine (`packages/sacred_time/`), the privacy
policies against what the code does, and the repository itself. Nothing was
changed while auditing.

At the time of the audit `flutter analyze` reported no issues, `flutter
test` passed all 737 app tests, and `dart test` passed all 184 engine tests.

Severities: **high** can lose or hide a user's data or stop the app;
**medium** is wrong behaviour a user will meet; **low** is an edge case, a
gap in wording, or hygiene.

## Contents

1. [App: journal, sync and reminders](#1-app-journal-sync-and-reminders)
2. [Engine: sacred_time](#2-engine-sacred_time)
3. [Privacy: the policies against the code](#3-privacy-the-policies-against-the-code)
4. [Repository](#4-repository)
5. [Checked and found correct](#5-checked-and-found-correct)

---

## 1. App: journal, sync and reminders

### 1.1 High: one bad file in the journal hides the journal or stops the app from launching

- **Where:** `app/lib/journal/journal_storage.dart:263-281` (`rebuildIndex`),
  `:407-418` (`loadCategories`); `app/lib/journal/entry_file.dart:218-226`;
  `app/lib/main.dart:110`; `app/lib/sync/sync_controller.dart:295-305`.
- **What happens:** `EntryFile.decode` builds the date with `CivilDate(...)`,
  which throws on an impossible date such as `2026-02-30` or `2026-13-01`.
  Reading a file that is not valid UTF-8 also throws. `rebuildIndex` runs
  `BEGIN` and `DELETE FROM entries` with no try and no rollback, so a throw
  leaves the SQLite connection inside an open transaction with every row
  deleted. The error is an `ArgumentError` or `TypeError`, which `on
  Exception` in the sync controller does not catch.
- **Scenario:** an entry is hand-edited on GitHub with a wrong date, or
  `categories.json` loses a `color`, and sync pulls it.
  - For the rest of the session the journal looks empty or cut short. Every
    later write goes into a transaction that is never committed, so after a
    restart the index silently lacks those entries.
  - If `index.dirty` exists at launch, or `categories.json` is malformed,
    `FileJournalStorage.open` or the `JournalStore` constructor throws
    before `runApp`, and the app never starts. On iOS the user cannot reach
    the folder to repair it.
  - `loadCategories` does not clamp `color`, so a value above 23 crashes
    later in `categoryPalette[...]`.
- **Fix:**
  - Decode each file inside try/catch, skip the bad ones and count them.
  - Wrap the rebuild in try/`ROLLBACK`.
  - Validate the date in `_date` before calling `CivilDate`.
  - Make `loadCategories` tolerant: try/catch, check each item, clamp the
    colour.
  - Catch `Object` around `reload()` in `syncNow`.

### 1.2 Medium: changing an entry's category and its date or time in one edit leaves the old file behind

- **Where:** `app/lib/journal/entry_screen.dart:526-539`,
  `app/lib/journal/journal_store.dart:274-275`,
  `app/lib/journal/journal_storage.dart:525-528`.
- **What happens:** `_save` builds `changed` with the new `categoryId`, then
  calls `store.move(changed, ...)`. `move` calls `_storage.remove(entry)`,
  which deletes the path of `changed`, in the new category's folder, where
  no file exists. The real file in the old category's folder stays, hidden
  only until the next rebuild.
- **Scenario:** after the next sync that pulls anything, or any rebuild, the
  entry appears twice, and sync pushes the orphan to GitHub.
- **Fix:** have `move` remove the original entry (`_entry`), not `changed`.

### 1.3 Medium: files pulled by a sync that fails partway are never shown

- **Where:** `app/lib/sync/sync_engine.dart:222-232`,
  `app/lib/sync/sync_controller.dart:288-309`.
- **What happens:** `takeTheirs` writes or deletes files as it goes. If a
  later request throws (offline, 403, timeout), `reload()` never runs. On
  the next sync those files already match the remote, so `pulled == 0` and
  there is still no reload. The index is rebuilt at startup only if
  `index.dirty` exists.
- **Scenario:** pulled entries stay invisible and remotely deleted ones stay
  visible, possibly for a long time. A new entry at the same second and in
  the same category as an invisible one overwrites its file, and the next
  sync reports a conflict on it.
- **Fix:** reload whenever any file was written, failure or not (track it on
  the engine), or set the dirty marker before sync writes anything.

### 1.4 Medium: sync can overwrite an edit made while it runs

- **Where:** `app/lib/sync/sync_engine.dart:186` (the one scan), `:246-249`,
  `:222-229`; `app/lib/journal/entry_screen.dart:526-534`.
- **What happens:** the local state is read once at the start, then the
  engine waits on the network. If the user saves an entry in that window
  and the remote also changed it, `takeTheirs` replaces the file just saved
  without a conflict. The other way round, an editor left open across a
  sync reload saves its stale entry over a change that was just pulled, and
  that change is pushed away as if it were an ordinary edit.
- **Scenario:** a sync starts on resume, or four seconds after a change; the
  user saves an entry the other device also changed, and the new text is
  lost.
- **Fix:**
  - Before `takeTheirs`, re-check the file's blob SHA against the scan and
    treat any difference as a conflict.
  - Have the editor notice that its entry changed underneath it (for
    example through `JournalStore.revision`).

### 1.5 Medium: one malformed reminder or tag wipes its whole list on the next save

- **Where:** `app/lib/reminders/reminder_store.dart:67-82` and `:283-296`,
  `app/lib/reminders/reminder.dart:353-357`,
  `app/lib/journal/journal_storage.dart:429-440`,
  `app/lib/journal/journal_archive.dart:141-153`.
- **What happens:** `Reminder.fromJson` throws on a date like `2026-02-30`.
  `_read` catches it for the whole list, so the list in memory is empty. The
  next `save` writes only what is in memory over `reminders.json`, and sync
  pushes the empty list. The same happens with `loadTags` followed by
  `addTag` (wipes `tags.json`); an import silently drops every reminder; and
  the background re-scheduler schedules nothing.
- **Fix:** catch errors per item, and never overwrite a file that failed to
  read (or back it up first).

### 1.6 Medium: GitHub's rate limit is reported as a bad token

- **Where:** `app/lib/sync/github_host.dart:106`,
  `app/lib/sync/sync_engine.dart:214-217`.
- **What happens:** a 403 from the primary or secondary rate limit becomes
  `SyncDenied`, and a 429 a generic failure. A first sync fetches one blob
  per file, so a journal of about 5,000 entries or more passes the limit of
  5,000 requests an hour.
- **Scenario:** the user is told the token is wrong and enters a new one,
  though the old one was fine.
- **Fix:** read `x-ratelimit-remaining` and `retry-after` and show a
  rate-limited state of its own; batch the blob fetches, or use the
  tarball/zipball endpoint for a first sync.

### 1.7 Medium: notification ids change on every run

- **Where:** `app/lib/reminders/reminder_store.dart:349`,
  `app/lib/reminders/announcer.dart:113-133`.
- **What happens:** the id is `Object.hash(reminder.id, date.dayNumber)`, but
  Dart seeds `Object.hash` per process: three runs on the same input gave
  499427029, 476738611 and 35844863. The comment above it says the same
  reminder on the same day always has the same id. When the app and the
  background task both run `replaceAll`, each sees the other's pending ids
  as unwanted.
- **Scenario:** interleaved, they cancel each other's notifications or
  schedule duplicates.
- **Fix:** a fixed hash, for example FNV-1a of `"$id:$dayNumber"`.

### 1.8 Low: conflict choices can be dropped

- **Where:** `app/lib/sync/sync_controller.dart:276-282`, `:313-316`.
- If a sync is already running, `resolve(choices)` sets `_again` and
  returns; the re-run uses no resolutions, so the user's choices are lost
  and the conflicts come back. **Fix:** queue the resolutions.

### 1.9 Low: a retry can raise false conflicts

- **Where:** `app/lib/sync/sync_engine.dart:171-179`.
- The `StaleHead` retry reuses the original state, so a file pulled in the
  failed attempt that has changed again remotely shows as a conflict.
  **Fix:** rescan before retrying.

### 1.10 Low: "Keep both" can silently overwrite the GitHub copy

- **Where:** `app/lib/sync/sync_engine.dart:277-288`.
- If the remote file does not parse as an entry, `_beside` returns null and
  `sendMine` overwrites it on GitHub; it survives only in the git history,
  though the screen offered both. **Fix:** keep the remote file under a new
  name when it cannot be parsed.

### 1.11 Low: an import can add tags and then fail

- **Where:** `app/lib/journal/journal_store.dart:416-427` against `:464`.
- `merge` saves the imported tags before the `TooManyCategories` check,
  though its doc says the check comes before anything changes. **Fix:** check
  first.

### 1.12 Low: two entries at the same second hide one another

- **Where:** `app/lib/journal/journal_storage.dart:251`, `:283`.
- The index key `(day, second)` leaves out the category, and `INSERT OR
  REPLACE` keeps one row. Two devices writing at the same second in
  different categories leave one entry hidden. **Fix:** add the category to
  the key.

### 1.13 Low: an import accepts `..` as a category folder

- **Where:** `app/lib/journal/journal_archive.dart:48-50`.
- A zip folder named `..` is taken as a category id, and the entry lands one
  level up (`entries/Y/M/`). It cannot escape `entries/`. **Fix:** require
  `^[0-9a-f]{6}$`. No other path is built from user input.

### 1.14 Low: the sync state file is written in place

- **Where:** `app/lib/sync/sync_controller.dart:192`, `:155-170`.
- `sync.json` is not written atomically, and a failure to read it silently
  turns sync off (the token stays in the keychain). **Fix:** write to a temp
  file and rename, and report a damaged state instead of switching off.

### 1.15 Low: the iOS file pickers can stay stuck

- **Where:** `app/ios/Runner/AppDelegate.swift:318-368`.
- If `presenter` is nil the picker never shows, `waiting` stays set, and
  every later save or import answers "busy" until a restart. **Fix:** clear
  `waiting` when nothing can be presented.

### 1.16 Low: two tests may not test what they say

- `app/test/month_screen_test.dart:534` and `:5040` tap a point where nothing
  is hit, so they pass without exercising the tap.

---

## 2. Engine: sacred_time

### 2.1 Medium: `Sky.nextPhase` reports a phase that has just passed as today's

- **Where:** `packages/sacred_time/lib/src/sky.dart:107`.
- **What happens:** `if (short(before) >= 0 && short(before) < 1) return
  before;`. A positive `short` means the moon has already passed the phase,
  and 1° is about two hours of its motion, so a phase up to two hours before
  local midnight is returned as happening at midnight.
- **Example:** the full moon of 26 October 2026 was at 04:11:43 UTC.
  `nextPhase(CivilDate(2026, 10, 26), utcOffset: -5h)` returns
  `2026-10-26 05:00:00Z` (local midnight) instead of the next full moon,
  24 November 2026 at 14:53 UTC. `Moon.of` rightly calls 25 October the
  full moon's day.
- **In the app:** `app/lib/sky_section.dart:113` and
  `app/lib/sky/sky_screen.dart:858` would show "full moon · today" for
  yesterday's full moon. It only happens at offsets west of about UTC+2,
  which is why the tests (at UTC+7) never met it.
- **Fix:** drop the tolerance (keep only an exact hit within about 1e-6°),
  or search forward so that a phase just past is skipped.

### 2.2 Medium: under true solar midnight the zi hour repeats the day's first hour

- **Where:** `packages/sacred_time/lib/src/bazi_chart.dart:203`.
- **What happens:** `hourOf` steps to the next day only under `split`. Under
  `trueSolarMidnight`, 23:00 to 24:00 takes the current day's stem.
- **Example (a 己未 day):** 21:43 gives 乙亥, then 23:23 gives 甲子, the same
  pillar as 00:23 that morning. The unbroken sixty-hour cycle gives 丙子.
- **Related:** with `TimeMode.clock` and `trueSolarMidnight`, the day comes
  from the sundial and the hour from the clock. West of the zone's meridian,
  clock 00:20 can be sundial 23:55 of the day before, which gives that day's
  early zi hour, about 23 hours off.
- **Fix:** step the day when `chartTime.hour == 23` under
  `trueSolarMidnight` too; if the present behaviour is a school's choice,
  document it.

### 2.3 Medium in the library, low in the app: ΔT is far off before 1900

- **Where:** `packages/sacred_time/lib/src/moon.dart:199-206`.
- **What happens:** the 1900 to 1920 Espenak and Meeus polynomial is used for
  every year before 1920.

  | Year | The code | Expected (Espenak and Meeus) |
  |---|---|---|
  | 1880 | −138 s | about −5 s |
  | 1850 | −2,233 s | about +7 s |
  | 1800 | −26,648 s (−7.4 h) | about +14 s |
  | 1700 | −367,470 s (−4.25 days) | about +9 s |

  For example, the March equinox of 1800 comes out at 21 March 03:32 UTC
  instead of about 20 March 20:08 UTC. It reaches the sun's crossings, bazi
  pillars near a term, `Moon.of`, the hilal and the prayer times. After 2150
  the 2050 to 2150 bridge term keeps running (2200 gives 470 s against
  Espenak's 442 s).
- **In the app:** the date picker starts at 1900
  (`app/lib/date_picker.dart:16`), and 1900 to 1920 is right, so users never
  reach it; the library accepts those dates all the same.
- **Fix:** add the 1800 to 1860 and 1860 to 1900 segments, use the long-term
  parabola `−20 + 32u²` (u = (year − 1820) / 100) outside 1800 to 2150, or
  refuse dates outside the supported range.

### 2.4 Low: Umm al-Qura's Ramadan Isya uses the tabular Hijri calendar

- **Where:** `packages/sacred_time/lib/src/salat.dart:227-230`.
- The extra 30 minutes in Ramadan is decided by the tabular calendar, which
  can be a day off the Umm al-Qura calendar at either end of the month.
  **Fix:** document it, or accept the Hijri date from the caller.

### 2.5 Low: the magnetic model's years are not enforced

- **Where:** `packages/sacred_time/lib/src/magnetic.dart`.
- WMM2025 holds for 2025 to 2030, as its doc says, but `MagneticField.at`
  extrapolates any year without a word. **Fix:** clamp, or flag the result
  outside the model's years.

### 2.6 Assumptions a user could be surprised by

- **The Hijri calendar is tabular** (documented in `hijri_date.dart:23-29`).
  It puts 1 Ramadan 1447 on 18 February 2026, where Indonesia's ministry
  (Kemenag) set 19 February, and 1 Syawal 1447 on 20 March 2026, where the
  package's own MABIMS check says the criterion was not met anywhere in
  Indonesia on the evening of 19 March (Banda Aceh 2.88°), which points to
  21 March. Any screen showing these dates should call them tabular.
- **Days turn at civil midnight** for the Javanese, Hijri and weton
  calendars (as `civil_date.dart` says), where traditionally they begin at
  sunset, so "malam 1 Sura" or "malam Jumat Kliwon" falls on the evening
  before. None of the calendar classes says so.
- **The Javanese calendar covers kurup Asapon only** (24 March 1936 to
  25 August 2052), and throws outside it; this is documented.
- **`Bazi.of` counts the whole day a solar term falls on as the new month**,
  with `turnsAt` giving the exact instant; this is documented.

---

## 3. Privacy: the policies against the code

Measured against `CALENDAR/docs/store/google-play/en/privacy-policy.md` and
`CALENDAR/docs/store/app-store/en/privacy-policy.md`. No high-severity gap
was found; the core promises hold (see section 5).

### 3.1 Medium: on iPhone the GitHub token stays after the app is deleted

- **Where:** `app/lib/sync/sync_controller.dart:29-32` stores it with
  `FlutterSecureStorage(iOptions: IOSOptions(accessibility:
  KeychainAccessibility.first_unlock_this_device))`. iOS keeps Keychain
  items after an app is deleted, and nothing removes it on the first launch
  after a reinstall (`start()` returns early when `sync.json` is missing, so
  the old token is never used, but it is still there).
- **The policy (iOS):** "Deleting Candra from your iPhone removes everything
  it kept there."
- **Fix:** on launch, if a "has run" flag in UserDefaults is missing, delete
  the Keychain item and then set the flag; or say in the policy that the
  token goes with "Stop syncing", not with deleting the app.

### 3.2 Low: an export holds more than the journal's text

- **Where:** `app/lib/journal/journal_archive.dart:59-78` zips the whole
  journal folder: `categories.json`, `tags.json`, `reminders.json`, and a
  `candra.json` with the export's local time. Each entry and reminder also
  carries a creation record (`app/lib/moment_stamp.dart:98-100`) with the
  exact moment it was saved and the phone's UTC offset, which hints at the
  time zone. With a geotag it also holds the sun's and moon's places worked
  out from the rounded geotag, which reveals nothing more than the geotag.
- **Fix:** say in the policy that an export includes categories, tags and
  reminders, and the time each item was first saved with its time zone
  offset.

### 3.3 Low: sync sends a little more than the policy lists

- **Where:** `app/lib/sync/sync_engine.dart:106-111` also syncs `tags.json`;
  `app/lib/sync/github_host.dart:171-178` creates a `.candra` file in an
  empty repository; `sync_engine.dart:308-310` writes `Candra sync from
  $device` in each commit message, with `device = Platform.operatingSystem`
  (`sync_controller.dart:188`), so "ios" or "android" is in the commit
  history, with the creation records of 3.2.
- **Fix:** add tags and the kind of phone in commit messages to the policy,
  or drop `device`.

### 3.4 Low: saving a picture on Android is not in the Android policy

- **Where:** `app/android/app/src/main/kotlin/com/suryamajapahit/candra/MainActivity.kt:458-484`
  writes PNGs into the shared `Pictures/Candra` folder through MediaStore,
  where other apps and photo backups (Google Photos among them) can see
  them. The iOS policy covers its counterpart ("Photos, add only").
- **Fix:** add a line to the Android policy, under "When data leaves" and
  under permissions and features.

### 3.5 Low: what the widgets keep goes into iOS backups

- **Where:** `app/ios/Runner/AppDelegate.swift:146` writes thirty days of
  widget data into the app group's UserDefaults; from
  `app/lib/phone_surfaces.dart:173-178` that includes `dots`, the colour of
  each category with a reminder on a given day. App group containers are in
  iCloud backups; the policy says only "the small settings listed above"
  are.
- **Fix:** mention it, or stop sending `dots` to the widgets.

### 3.6 Low: "Open in Maps" falls back to the web on iPhone

- **Where:** `app/ios/Runner/AppDelegate.swift:493` builds
  `https://maps.apple.com/?ll=…&q=<label>`. With Apple Maps removed, iOS
  opens it in Safari, sending the rounded place and its name to Apple.
- **Fix:** use the `maps://` scheme so it fails quietly
  (`openInMaps` already returns false and shows "no maps app").

### 3.7 Low (wording): links the user taps

- **Where:** `app/lib/menu/policy_screen.dart:219` opens links (GitHub's
  privacy statement) in the browser, and `app/lib/menu/menu_screen.dart:313-315`
  opens `mailto:` with the app's version in the subject. Both are the user's
  doing, in other apps; "Candra uses the network for nothing else" could
  add "links you tap open in your browser or mail app".

### 3.8 Low: Android permissions from the plugins are not in the policy's table

- `workmanager_android` adds `FOREGROUND_SERVICE` and
  `FOREGROUND_SERVICE_SHORT_SERVICE`; androidx.work adds `WAKE_LOCK` and
  `ACCESS_NETWORK_STATE`; `flutter_local_notifications` adds `VIBRATE`. The
  table lists notifications, exact alarms, starting after a restart,
  location and internet only.
- **Fix:** list them, or remove the foreground-service ones with
  `tools:node="remove"` if they are not needed; then compare the table with
  the merged manifest of a release build (none was built for this audit).

### 3.9 Low: a plain copy of the whole journal stays after an export

- **Where:** `app/lib/journal/journal_files.dart:24-38` builds the zip in
  `<tmp>/exports` and deletes it only at the next export; on iOS,
  `app/ios/Runner/AppDelegate.swift:337-343` also copies it to
  `temporaryDirectory/<name>` and never removes it. Neither place is backed
  up, and the system may clear them.
- **Fix:** delete the files once the share or save sheet closes.

### 3.10 Low (comment): AndroidManifest describes location too narrowly

- **Where:** `app/android/app/src/main/AndroidManifest.xml:7-9` says location
  is for "the geotag button on an entry, and nothing else"; the code and the
  policy also use it for the sky's place, the bazi chart, and refreshing the
  place on Today or when a tool opens. Only the comment is out of date.

### 3.11 Minor notes

- `data_extraction_rules.xml` does not exclude the `device_*` domains
  (storage readable before the first unlock). Nothing in the app seems to
  use them, but excluding them is tidier.
- The build step of `sqlite3` 3.7.0 (`hook/build.dart`) can download a
  prebuilt SQLite while building. That happens on the build machine, never
  on the phone, and is the only use of `http` in the lockfile.

---

## 4. Repository

### 4.1 The commits carry a placeholder address

- All four commits are authored and committed as `takaya1337 <your GitHub
  noreply or the address you want shown>`, which GitHub shows publicly.
- **Fix:** set `git config user.email` to the GitHub noreply address. The
  existing commits keep the placeholder unless the history is rewritten and
  force-pushed.

### 4.2 A test names the real sync repository

- **Where:** `app/test/sync_controller_test.dart:409-416` uses
  `takaya1337/CANDRA_DATA` as its example. Harmless if that repository is
  private, but it says where the owner's journal syncs to.
- **Fix:** use a made-up name.

### 4.3 A release build signs with the debug key when no key is set

- **Where:** `app/android/app/build.gradle.kts`, and `app/tool/build_release.sh`.
- Documented in the README, but easy to ship by mistake: a store upload
  signed with the debug key is refused, and a sideloaded one cannot be
  updated by the real build.
- **Fix:** have the release script stop when `key.properties` is missing,
  unless asked otherwise.

---

## 5. Checked and found correct

### Repository

- No secrets in the whole history: no tokens, keys, keystores, signing
  files or passwords. `key.properties`, keystores and signing keys are
  ignored, and the Xcode project carries no development team.
- Every third-party source in `NOTICE.md` has its licence text in
  `app/assets/licences/` (Natural Earth, public domain, needs none).
- The fonts carry their OFL texts; IBM Plex reserves the name "Plex" and is
  shipped unmodified; the cut of Noto Sans Symbols has no reserved name, so
  subsetting it is allowed.
- The bazi test fixtures are values generated with lunar_python (MIT), not
  copied code.

### Privacy

- **No analytics, trackers, ads, crash reporting, Firebase, remote fonts,
  map tiles, geocoding or update checks.** The dependencies (archive,
  crypto, flutter_local_notifications, flutter_secure_storage,
  path_provider, shared_preferences, sqlite3, timezone, workmanager) and the
  lockfile hold none. The only network client is `HttpClient` in
  `github_host.dart`, aimed at `https://api.github.com`. The iOS and widget
  privacy manifests declare no tracking and no collected data.
- **Sync uses verified HTTPS:** a default `HttpClient`, no
  `badCertificateCallback`, no security-context or proxy overrides, no App
  Transport Security exceptions and no cleartext on Android. The token goes
  only in the `Authorization` header, which Dart drops on a redirect to
  another host.
- **Only journal data goes to GitHub:** `_ours()` limits sync to `entries/`,
  `categories.json`, `reminders.json` and `tags.json`. Errors become fixed
  messages or GitHub's own `message`; headers, URLs and the token are never
  logged. The only `print`/`debugPrint` calls sit behind build-time flags
  (`REARM_NOW`, `SHOTS`, `REVIEW`) that the release script does not set.
- **Geotags are rounded to about 100 m before saving** (`GeoTag.rounded`,
  three decimals, `geo.dart:27-45`), when made (`entry_screen.dart:401`),
  read from the index (`journal_storage.dart:329`, `:366`) and read from a
  file (`entry_file.dart:179`); files are written with `toStringAsFixed(3)`.
- **The place is rounded to 0.1° before saving** (`SkyPlace.rounded`) on
  every write: `sky_place.dart:22`, `place_editor.dart:43`, `:77`,
  `sky_section.dart:55`, `place_screen.dart:76`; `main.dart:63-68` saves only
  those. The bazi screen rounds longitude to 0.1° and saves nothing.
- **The exact position is never stored:** it lives only in memory between
  the native code and Dart, and reaches no widget, Live Activity, sync,
  export or log.
- **Location only "while using" and only on request:** iOS calls
  `requestWhenInUseAuthorization` and a one-off `requestLocation`, has no
  "Always" text, and its only background mode is `fetch`; Android has no
  `ACCESS_BACKGROUND_LOCATION` and makes one-off `getCurrentLocation` calls.
  The refresh on Today or a tool checks `allowed()` first and never asks.
  The background reminder task reads no location.
- **iOS backups:** `keepOutOfBackups()` (`AppDelegate.swift:262-273`) excludes
  Application Support, where the journal, `index.db` and `sync.json` live.
  UserDefaults holds only the rounded place and harmless flags.
- **iOS token:** `first_unlock_this_device`, not synchronizable, so it never
  travels through iCloud Keychain.
- **Android backups and token:** `allowBackup="false"`,
  `fullBackupContent="false"`, and the extraction rules exclude every
  standard domain for cloud backup and device transfer; the token is
  encrypted with a key held in the Android Keystore.
- **Android components and flags:** only the launcher activity is exported;
  the FileProvider is not, and serves only `cache/exports/`; the
  notification receivers are not exported; release builds set
  `isDebuggable = false` with minify on.
- **Widgets and the Live Activity** show calendar days, the moon's phase and
  category colours, and for a practice its category, colour and times; no
  journal text and no reminder titles.
- **Maps** receive only the rounded coordinates and the name (`geo:` on
  Android, Apple Maps on iOS).
- **The search and the bazi chart save nothing**, as the policies say. The
  compass needs no permission on either platform.

### App

- At most 60 notifications pending, under iOS's 64. Times are scheduled as
  exact instants per date; DST and month and year boundaries are handled.
- Entry, category and reminder files are written to a temp file and renamed
  into place.
- The token is kept in the Keychain or Keystore and sent only to
  api.github.com. A truncated file list from GitHub stops the sync instead
  of deleting local files.
- No unsafe force unwraps in the iOS native code; the Live Activity's timer
  ranges are guarded.
- No undisposed controllers or listeners found.
- Every deletion of an entry, card, category or tag asks first.

### Engine

- **Weton:** 1 January 2000 is Sabtu Legi, neptu 14 (from the anchor of
  17 August 1945, Jumat Legi); 24 March 1936 is Selasa Pon, the Asapon
  name; the weekday from the Julian day number mod 7 is right.
- **Javanese calendar:** epoch, windu of 2,835 days, the long years Ehe, Dal
  and Jimakir, month lengths; 1 Sura 1959 is 27 June 2025 and 1 Sura 1960 is
  17 June 2026.
- **Hijri:** matches Reingold's arithmetic formulas exactly, including the
  civil epoch, Julian day 1948440.
- **Chinese calendar:** all fourteen new years 2020 to 2033 right; leap
  months right (4 in 2020, 2 in 2023, 6 in 2025, 5 in 2028, 3 in 2031, 11 in
  2033); shio and element right; the table runs 19 February 1901 to
  8 February 2100; the jiazi day anchor of 1 October 1949 checks out.
- **Bazi:** 1 January 2000 is 己卯 / 丙子 / 戊午 (year, month, day); the
  five-tigers and five-rats rules, the cycle index, void branches, the six
  harmonies, the three-branch harmonies, stem combinations, the ten gods,
  all 30 nayin, the true solar time formula and the luck pillars' direction
  are right.
- **Solstices and equinoxes,** all within a minute of the published times:
  2024 at 03:06, 20:51, 12:44 and 09:20 UTC; 2025 March 09:01 and June 02:42
  UTC; 2000 March 07:35 UTC.
- **Moon phases:** full moons 25 January 2024 17:54 and 14 March 2025 06:55
  UTC; new moons 8 April 2024 18:21 and 17 February 2026 12:01 UTC.
- **Transcription:** the Meeus VSOP87 tables L0 to L5 and R0 to R4, tables
  47.A and 47.B, the additive terms A1, A2 and A3, nutation, aberration, the
  FK5 correction, topocentric parallax, the ΔT segments from 1900 to 2150,
  and the Yallop q and Odeh V formulas with their thresholds.
- **Pranata mangsa:** month lengths add to 365, Kawolu takes the leap day,
  seasons and phases map correctly.
- **Prayer times in Jakarta, 1 March 2025 (Kemenag):** Imsak 04:33, Subuh
  04:43, Zuhur 12:08, Asar 15:11, Magrib 18:15, Isya 19:24, in line with the
  Ramadan 1446 schedules for Jakarta; the suite's own Kemenag schedules
  pass too.
- **Hilal:** MABIMS is met at Banda Aceh on the evening of 28 February 2025
  (altitude 4.51°, elongation 6.40°), consistent with 1 Ramadan 1446 on
  1 March 2025.
- **Input checks:** `CivilDate` refuses impossible days and months; the
  Javanese, Chinese, Hijri and pranata mangsa calendars refuse dates out of
  their ranges.
- `stars.dart`, `planets.dart`, `close_approaches.dart` and `light.dart` were
  only skimmed; their tests check them against JPL Horizons and NASA.
