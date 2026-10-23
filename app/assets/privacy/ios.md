# Candra privacy policy: iPhone

Last updated: 23 October 2026

This is the policy for Candra on iPhone. The Android one is published
beside it; the two apps do the same things, and this page says how the
iPhone does them.

## The short version

- Candra has no accounts, no ads, no analytics and no trackers.
- The people who make Candra never receive anything you write. There is
  no Candra server.
- Everything is kept on your iPhone, in the app's own storage.
- Data leaves your iPhone only when you make it leave: by exporting a
  copy, or by turning on sync with a GitHub repository that you own.
- **Your journal is kept out of iCloud and computer backups.**

## What is kept on your iPhone

- **Journal entries:** their text, title, category, date and time, and,
  for an entry timed as a practice, how long it went on.
- **Categories, tags and reminders** that you make. Tags are plain names you put on entries and reminders, used only by the search.
- **Geotags, only if you add one.** When you press the geotag button on
  an entry, Candra asks your iPhone where it is, once. The position is
  rounded to about 100 metres before it is saved; the exact position is
  never stored. You can also give the place a name. Candra never looks
  up your location in the background, and outside the times described
  here. It asks only for location "While Using the App".
- **One place, only if you set it,** for sunrise, sunset and the moon's
  times, the sky and the prayer times, and for counting an evening as
  the next day in the search. You can set it by hand, or have Candra
  ask your iPhone once. It is kept rounded to a tenth of a degree of
  latitude and of longitude, which is about 11 kilometres: a tenth of a
  degree from north to south is 11.1 km anywhere on Earth, and from east
  to west it is 11.1 km at the equator and less towards the poles (about
  11 km anywhere in Indonesia). If you have already let Candra use your
  location, it also brings this
  place up to date when you press Today or open one of its tools (the
  sky, the planets, the stars, prayer times, the crescent, Light), so
  that what they show is for where you are. It never asks for
  permission to do this: without it, the place simply stays as it was.
- **Settings:** your language, dark or light, which calendar and view
  you locked, and a practice that is under way.

**The search keeps nothing.** It looks through your journal and
reminders on the iPhone; what you search for is not saved and not sent.
- **A GitHub access token,** only if you set up sync. It is kept in the
  iPhone's Keychain, for this iPhone alone: it is not synced through
  iCloud Keychain and is not restored onto another device.

**The bazi chart keeps nothing.** A date, time, place and sex put into
it are used to draw the chart and are gone when you leave the screen.

## Backups

iPhones back apps up to iCloud, or to a computer, unless an app says
otherwise. Candra says otherwise for everything you write:

- **Left out of backups:** the journal, the categories, the reminders,
  and everything else in the app's storage folder. If you restore your
  iPhone from a backup, or move to a new one, **the journal does not
  come with it.** Use "Save a copy" or sync to carry it over.
- **Included in backups, because iOS gives an app no way to leave them
  out:** the small settings listed above, and what the widgets show for
  the coming month: each day in the five calendars, the moon, and the
  colours of the categories that have a reminder that day (their
  colours only, never their names). Of these the only one that says
  anything about you is the place you set, already rounded to a tenth
  of a degree, about 11 kilometres.

## The Dynamic Island, the lock screen and widgets

- **The Dynamic Island and its lock screen banner** show one thing
  only: a practice under way, with the name of its category and its
  clock. Nothing from your journal and none of your reminders appear
  there. Switch it off in Settings → Candra → Live Activities.
- **Widgets** show the day in each calendar and the moon. They show
  nothing from your journal and none of your reminders' titles.
- Both are drawn on your iPhone from what the app works out. Nothing is
  sent anywhere to make them.

## When data leaves your iPhone

Only in these three cases, each of which you start yourself:

1. **Export.** "Share a copy" and "Save a copy" make a zip file of your
   journal as plain Markdown text. It holds your entries, categories,
   tags and reminders, and for each entry and reminder the moment it was
   first saved, with your time zone's offset from UTC. It goes wherever
   you send or save it. The file is not encrypted.
2. **Sync with GitHub (optional, off by default).** If you connect a
   GitHub repository, Candra sends your journal, categories, tags and
   reminders to that repository over an encrypted connection (HTTPS),
   and reads them back. Each sync is recorded in the repository with a
   short note naming the kind of phone it came from (Android or iOS). They are stored there as plain text, not
   encrypted. Whoever can read that repository, and GitHub itself, can
   read them. GitHub's handling of your data is covered by
   [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
3. **Opening a place in Maps.** Tapping a geotag hands its rounded
   coordinates and its name to Apple Maps.

Candra uses the network for nothing else. A link you tap in the app,
such as GitHub's privacy statement or the feedback address, opens in
your browser or mail app.

## Permissions

| Permission | Why |
|---|---|
| Notifications | To show your reminders, and the end of a practice timed down. |
| Location, While Using the App | Only when you press for it: the geotag button, the place for rise and set times, or the place of a bazi chart; and, if you have already allowed it, when you press Today or open a tool, to bring the sky's place up to date. Never asked for by these. |
| Photos, add only | To save a picture of a day's reading when you ask. Candra cannot see your photos. |
| Live Activities | The Dynamic Island and its lock screen banner, while a practice runs. |
| Background App Refresh | Now and then, when iOS allows, to set your coming reminders in place again so they keep coming with the app closed. It reads your reminders on the iPhone and sends nothing. |

Every one of these is optional. Candra works fully without any of them.

## Deleting your data

- Delete any entry, category or reminder in the app.
- Deleting Candra from your iPhone removes everything it kept there.
- A copy you exported, or a GitHub repository you synced to, is yours:
  delete the file or the repository to remove it.

There is nothing for us to delete, because we hold nothing.

## Children

Candra is not directed at children and collects no data from anyone.

## Changes

If this policy changes, the new version will be published at this address
with a new date.

## Contact

takaya@suryamajapahit.com
