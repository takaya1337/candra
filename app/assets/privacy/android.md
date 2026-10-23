# Candra privacy policy

Last updated: 23 October 2026

Candra is a calendar and journal app. It is built so that what you write
stays with you. This page says exactly what the app does with your data.

## The short version

- Candra has no accounts, no ads, no analytics and no trackers.
- The people who make Candra never receive anything you write. There is
  no Candra server.
- Everything is kept on your device, in the app's own storage.
- Data leaves your device only when you make it leave: by exporting a
  copy, or by turning on sync with a GitHub repository that you own.

## What is kept on your device

- **Journal entries:** their text, title, category, date and time, and,
  for an entry timed as a practice, how long it went on.
- **Categories, tags and reminders** that you make. Tags are plain names you put on entries and reminders, used only by the search.
- **Geotags, only if you add one.** When you press the geotag button on
  an entry, Candra asks your phone where it is, once. The position is
  rounded to about 100 metres before it is saved; the exact position is
  never stored. You can also give the place a name. Candra never looks up
  your location in the background, and outside the times described here.
- **One place, only if you set it,** for sunrise, sunset and the moon's
  times, the sky and the prayer times, and for counting an evening as
  the next day in the search. You can set it by hand, or have Candra ask
  your phone once. It is kept rounded to a tenth of a degree of latitude
  and of longitude, which is about 11 kilometres: a tenth of a degree
  from north to south is 11.1 km anywhere on Earth, and from east to
  west it is 11.1 km at the equator and less towards the poles (about
  11 km anywhere in Indonesia). If you have already let Candra use your
  location, it also brings this place up to
  date when you press Today or open one of its tools (the sky, the
  planets, the stars, prayer times, the crescent, Light), so that what
  they show is for where you are. It never asks for permission to do
  this: without it, the place simply stays as it was.
- **Settings:** your language, dark or light, which calendar and view
  you locked, and a practice that is under way.

**The search keeps nothing.** It looks through your journal and
reminders on the device; what you search for is not saved and not sent.
- **A GitHub access token,** only if you set up sync. It is stored
  encrypted on the device and is sent to GitHub and nowhere else.

**The bazi chart keeps nothing.** A date, time, place and sex put into
it, whether your own birth's or anyone else's, are used to draw the
chart and are gone when you leave the screen. They are never written to
the device and never sent anywhere.

About every twelve hours Android lets Candra run briefly in the
background, to set your coming reminders in place again so they keep
coming however long the app stays closed. It reads your reminders and
settings on the device and sends nothing anywhere.

Android's cloud backup is switched off for Candra, so your journal is not
copied to your Google account.

## When data leaves your device

Only in these four cases, each of which you start yourself:

1. **Export.** "Share a copy" and "Save a copy" make a zip file of your
   journal as plain Markdown text. It holds your entries, categories,
   tags and reminders, and for each entry and reminder the moment it was
   first saved, with your time zone's offset from UTC. It goes wherever
   you send or save it. The file is not encrypted.
2. **Sync with GitHub (optional, off by default).** If you connect a
   GitHub repository, Candra sends your journal, categories, tags and
   reminders to that repository over an encrypted connection (HTTPS),
   and reads them back. Each sync is recorded in the repository with a
   short note naming the kind of phone it came from (Android or iOS). They are stored there as plain text, not encrypted.
   Whoever can read that repository, and GitHub itself, can read them.
   GitHub's handling of your data is covered by
   [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).
3. **Opening a place in a maps app.** Tapping a geotag hands its rounded
   coordinates and its name to the maps app you choose.
4. **Saving a picture of a day's reading.** It is saved to the
   Pictures/Candra folder on your phone, where your gallery, other apps
   with access to your pictures, and any photo backup you use (Google
   Photos among them) can see it.

Candra uses the network for nothing else. A link you tap in the app,
such as GitHub's privacy statement or the feedback address, opens in
your browser or mail app.

## Permissions

| Permission | Why |
|---|---|
| Notifications | To show your reminders, the end of a practice timed down, and the clock of a practice under way. |
| Alarms at an exact time | So a reminder sounds at the minute you set. |
| Start after the phone restarts | To put your reminders back in place. |
| Location (precise or approximate) | Only when you press for it: the geotag button, the place for rise and set times, or the place of a bazi chart; and, if you have already allowed it, when you press Today or open a tool, to bring the sky's place up to date. Never asked for by these. |
| Internet | Only for GitHub sync, if you turn it on. |

The parts Candra uses to schedule reminders and show notifications also
ask Android for: vibration (for a reminder's alert), keeping the phone
awake briefly and checking the network state (while a reminder is being
put back in place), and a short foreground service (so that job can
finish). None of them reads or sends your data.

Every one of these is optional except Internet, which does nothing until
sync is set up. Candra works fully without location and without
notifications.

## Deleting your data

- Delete any entry, category or reminder in the app.
- Uninstalling Candra removes everything it kept on the device.
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
