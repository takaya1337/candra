import 'bazi/bazi_tables.dart';

import 'package:flutter/widgets.dart';
import 'package:sacred_time/sacred_time.dart';
import 'package:sm_design/sm_design.dart';

import 'calendar_system.dart';
import 'iching/iching_pack.dart';
import 'iching/iching_reading_screen.dart';
import 'iching/iching_record.dart';
import 'colour_schemes.dart';
import 'menu/notes_text.dart';
import 'reminders/reminder.dart';
import 'search/query.dart';
import 'utilities.dart';

enum AppLanguage {
  en('EN'),
  id('ID');

  final String code;

  const AppLanguage(this.code);
}

/// The app's language, persisted when it changes.
class LanguageController extends ValueNotifier<AppLanguage> {
  /// Called when the language changes, to persist it.
  final void Function(AppLanguage language)? onChange;

  LanguageController({AppLanguage? saved, this.onChange})
    : super(saved ?? AppLanguage.en);

  void select(AppLanguage language) {
    if (language == value) return;
    value = language;
    onChange?.call(language);
  }
}

/// Gives the subtree the [LanguageController]. Widgets that read
/// [Strings.of] rebuild when the language changes.
class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController super.notifier,
    required super.child,
  });

  static LanguageController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()!.notifier!;
}

/// Every piece of text the app shows, in one language.
///
/// English is used wherever an English form exists (month names, moon
/// phases, the zodiac). Words that are names in their own tradition stay as
/// they are in both languages: weton, pasaran, neptu and the Javanese
/// months and years.
class Strings {
  final AppLanguage language;

  const Strings(this.language);

  static Strings of(BuildContext context) =>
      Strings(LanguageScope.of(context).value);

  bool get _en => language == AppLanguage.en;

  // Chrome.

  String get done => _en ? 'Done' : 'Selesai';
  String get save => _en ? 'Save' : 'Simpan';
  String get titlePlaceholder => _en ? 'Title' : 'Judul';
  String get contentPlaceholder => _en ? 'Write here' : 'Tulis di sini';
  String get deleteEntryQuestion =>
      _en ? 'Delete this entry?' : 'Hapus catatan berikut?';
  String get entryChangedElsewhere => _en
      ? 'This entry was changed by a sync while it was open, so yours is '
            'kept beside it'
      : 'Catatan ini diubah oleh sinkronisasi saat sedang dibuka, jadi '
            'milik Anda disimpan di sampingnya';

  // What to copy of a selection in an entry being read.
  String get copyWord => _en ? 'Word' : 'Kata';
  String get copySentence => _en ? 'Sentence' : 'Kalimat';
  String get copyParagraph => _en ? 'Paragraph' : 'Paragraf';
  String get copyAll => _en ? 'All' : 'Semua';

  // The selection toolbar.
  String get cut => _en ? 'Cut' : 'Potong';
  String get copy => _en ? 'Copy' : 'Salin';
  String get paste => _en ? 'Paste' : 'Tempel';
  String get selectAll => _en ? 'Select all' : 'Pilih semua';

  // Categories.
  String get categoriesTitle => _en ? 'Categories' : 'Kategori';
  String get categoryNew => _en ? 'New category' : 'Kategori baru';
  String get categoryNamePlaceholder => _en ? 'Category name' : 'Nama kategori';
  String get categoryNeedsName =>
      _en ? 'Give it a name first.' : 'Beri nama terlebih dahulu.';
  String get categoryLimit => _en
      ? '24 categories is the limit.'
      : 'Batas maksimal kategori adalah 24.';
  String get swap => _en ? 'Swap' : 'Tukar';

  /// The first question asked before a category is deleted.
  String deleteCategoryQuestion(String category) =>
      _en ? 'Delete the category $category?' : 'Hapus kategori $category?';

  /// The second, asked only when the category still has entries or
  /// reminders.
  String deleteCategoryEntriesQuestion(
    String category,
    int entries, {
    int reminders = 0,
  }) {
    final one = entries + reminders == 1;
    if (_en) {
      final things = [
        if (entries > 0) entries == 1 ? '1 entry' : '$entries entries',
        if (reminders > 0)
          reminders == 1 ? '1 reminder' : '$reminders reminders',
      ].join(' and ');
      return '$category has $things. Delete ${one ? 'it' : 'them all'} '
          'along with the category?';
    }
    final things = [
      if (entries > 0) '$entries catatan',
      if (reminders > 0) '$reminders pengingat',
    ].join(' dan ');
    return '$category memiliki $things. Hapus '
        '${!one
            ? 'semuanya'
            : entries == 1
            ? 'catatan itu'
            : 'pengingat itu'} '
        'beserta kategorinya?';
  }

  /// Asked on saving a category with a colour [owner] already has.
  String colorTaken(String owner) => _en
      ? '$owner already has this colour, and a colour belongs to one '
            'category only. To swap, choose a new colour for $owner.'
      : '$owner sudah memakai warna ini, dan satu warna hanya untuk satu '
            'kategori. Untuk menukar, pilih warna baru untuk $owner.';
  String get delete => _en ? 'Delete' : 'Hapus';

  /// "5 / 24".
  String categoryCount(int count, int limit) => '$count / $limit';

  /// What a category being edited holds, under its preview: "3 entries ·
  /// 1 reminder".
  String categoryHolds(int entries, int reminders) => _en
      ? '${entries == 1 ? '1 entry' : '$entries entries'} · '
            '${reminders == 1 ? '1 reminder' : '$reminders reminders'}'
      : '$entries catatan · $reminders pengingat';

  // Sync.
  String get syncHeading => _en ? 'Sync' : 'Sinkronisasi';
  String get syncSetUp =>
      _en ? 'Sync with GitHub' : 'Sinkronisasi dengan GitHub';
  String get syncSetUpHint => _en
      ? 'Keep several devices in sync with your own private repository.'
      : 'Samakan beberapa perangkat lewat repositori pribadi milik Anda.';
  String get syncNow => _en ? 'Sync now' : 'Sinkronisasi sekarang';
  String get syncOff => _en ? 'Turn off sync' : 'Matikan sinkronisasi';
  String get syncOffHint => _en
      ? 'This device stops syncing. The repository keeps its copy.'
      : 'Perangkat ini tidak lagi melakukan sinkronisasi. Repositori tetap menyimpan salinannya.';
  String syncResolve(int count) => _en
      ? 'Settle $count ${count == 1 ? 'conflict' : 'conflicts'}'
      : 'Selesaikan $count konflik';
  String get syncResolveHint => _en
      ? 'Changed on two devices; choose what to keep'
      : 'Diubah di dua perangkat; pilih yang akan disimpan';
  String get syncing => _en ? 'Syncing…' : 'Sinkronisasi…';
  String syncedAt(String time) =>
      _en ? 'In step as of $time' : 'Sudah sama per $time';
  String get syncNever => _en ? 'Not synced yet' : 'Belum disinkronkan';
  String get syncOffline => _en
      ? 'GitHub cannot be reached. It will try again.'
      : 'GitHub tidak terjangkau. Akan dicoba lagi.';
  String get syncDenied => _en
      ? 'GitHub refused the token. It may have expired, or lack write '
            'access to this repository.'
      : 'GitHub menolak token. Mungkin sudah kedaluwarsa, atau tidak punya '
            'akses tulis ke repositori ini.';
  String get syncNotFound => _en
      ? 'No such repository, or the token cannot see it.'
      : 'Repositori tidak ada, atau token tidak dapat melihatnya.';
  String syncFailed(String? detail) => _en
      ? 'Sync failed${detail == null ? '.' : ': $detail'}'
      : 'Sinkronisasi gagal${detail == null ? '.' : ': $detail'}';
  String syncRateLimited(String? time) => _en
      ? 'GitHub has had too many requests for now. '
            '${time == null ? 'It will try again later.' : 'It will try again after $time.'}'
      : 'GitHub sedang menerima terlalu banyak permintaan. '
            '${time == null ? 'Akan dicoba lagi nanti.' : 'Akan dicoba lagi setelah $time.'}';
  String get syncDamaged => _en
      ? 'The saved sync details could not be read. Turn sync off, then set '
            'it up again.'
      : 'Data sinkronisasi yang tersimpan tidak bisa dibaca. Matikan '
            'sinkronisasi, lalu atur lagi.';

  String get syncSetupTitle => _en ? 'Sync with GitHub' : 'Sinkron GitHub';
  String get syncToken => _en ? 'Access token' : 'Token akses';
  String get syncConnect => _en ? 'Connect' : 'Hubungkan';
  String get syncNeedsBoth => _en
      ? 'Both the repository and the token are needed.'
      : 'Repositori dan token diperlukan.';
  String get syncRepository =>
      _en ? 'owner/repository, or its URL' : 'pemilik/repositori, atau URL';

  /// How to get what the two fields want, step by step. The names of
  /// things on GitHub's own pages are between backticks and are always
  /// as GitHub writes them, in English, whatever language the app is in.
  String get syncHowTo => _en
      ? 'On github.com, signed in:\n\n'
            '1. Make the repository. The `+` at the top right, then '
            '`New repository`. Choose `Private`. Leave it empty: no '
            'README, no .gitignore, no license.\n\n'
            '2. Your profile picture at the top right, then `Settings`.\n\n'
            '3. At the bottom of the left sidebar, `Developer settings`.\n\n'
            '4. `Personal access tokens`, then `Fine-grained tokens`, then '
            '`Generate new token`.\n\n'
            '5. `Token name`: anything. `Expiration`: as you like; when '
            'it runs out, sync stops until a new token is put in here.\n\n'
            '6. `Resource owner`: your own account. `Repository access`: '
            '`Only select repositories`, and select the journal\'s '
            'repository.\n\n'
            '7. `Permissions`, `Repository permissions`, `Contents`: '
            '`Read and write`. Nothing else. `Metadata` sets itself to '
            '`Read-only`.\n\n'
            '8. `Generate token`, and copy it at once: GitHub shows it '
            'only that one time.\n\n'
            '9. Here, put in the repository, as owner/repository or as '
            'its web address, and the token.\n\n'
            'It is a fine-grained personal access token that is wanted: '
            'not a deploy key, and not a classic token.\n\n'
            'The journal is kept on GitHub as plain Markdown, not '
            'encrypted: GitHub, and anyone you give the repository to, '
            'can read it. The token is kept on this device, encrypted, '
            'and is sent only to GitHub. Syncing uses the network; '
            'nothing else in Candra does.'
      : 'Di github.com, sesudah masuk:\n\n'
            '1. Buat repositorinya. Tanda `+` di kanan atas, lalu '
            '`New repository`. Pilih `Private`. Biarkan kosong: tanpa '
            'README, tanpa .gitignore, tanpa license.\n\n'
            '2. Foto profil di kanan atas, lalu `Settings`.\n\n'
            '3. Di paling bawah bilah kiri, `Developer settings`.\n\n'
            '4. `Personal access tokens`, lalu `Fine-grained tokens`, '
            'lalu `Generate new token`.\n\n'
            '5. `Token name`: bebas. `Expiration`: terserah Anda; begitu '
            'habis, sinkronisasi berhenti sampai token baru dimasukkan '
            'di sini.\n\n'
            '6. `Resource owner`: akun Anda sendiri. `Repository access`: '
            '`Only select repositories`, lalu pilih repositori jurnal.\n\n'
            '7. `Permissions`, `Repository permissions`, `Contents`: '
            '`Read and write`. Yang lain tidak perlu. `Metadata` otomatis '
            'menjadi `Read-only`.\n\n'
            '8. `Generate token`, dan langsung salin: GitHub hanya '
            'menampilkannya satu kali itu.\n\n'
            '9. Di sini, masukkan repositori, sebagai pemilik/repositori '
            'atau alamat webnya, dan tokennya.\n\n'
            'Yang diperlukan adalah fine-grained personal access token: '
            'bukan deploy key, dan bukan classic token.\n\n'
            'Jurnal disimpan di GitHub sebagai Markdown biasa, tidak '
            'dienkripsi: GitHub, dan siapa pun yang Anda beri akses ke '
            'repositori, dapat membacanya. Token disimpan di perangkat '
            'ini, terenkripsi, dan hanya dikirim ke GitHub. Sinkronisasi '
            'memakai jaringan; bagian lain Candra tidak.';

  String conflictTitle(int at, int of) =>
      _en ? 'Conflict $at of $of' : 'Konflik $at dari $of';
  String get conflictIntro => _en
      ? 'This entry was changed on two devices. Which is kept?'
      : 'Catatan ini diubah di dua perangkat. Mana yang akan disimpan?';
  String get conflictMine => _en ? 'On this device' : 'Di perangkat ini';
  String get conflictTheirs => _en ? 'On GitHub' : 'Di GitHub';
  String get conflictDeleted => _en ? 'Deleted' : 'Dihapus';
  String get keepMine => _en ? 'This device' : 'Perangkat ini';
  String get keepTheirs => 'GitHub';
  String get keepBoth => _en ? 'Both' : 'Keduanya';

  /// The row of the day's pillars. A name of its own in both languages.
  String get bazi => 'Bazi';

  // Reminders.
  String get remindersTitle => _en ? 'Reminders' : 'Pengingat';
  String get noReminders => _en ? 'No reminders yet.' : 'Belum ada pengingat.';
  String get reminderPlaceholder =>
      _en ? 'Remind me of' : 'Ingatkan saya tentang';
  String get newReminder => _en ? 'New reminder' : 'Pengingat baru';
  String get editReminder => _en ? 'Edit reminder' : 'Ubah pengingat';
  String get reminderCategory => _en ? 'Category' : 'Kategori';
  String get reminderStarts => _en ? 'Starts' : 'Mulai';
  String get reminderTime => _en ? 'Time' : 'Waktu';
  String get reminderRepeats => _en ? 'Repeats' : 'Berulang';
  String get reminderRow => _en ? 'Reminder' : 'Pengingat';
  String get reminderOff => _en ? 'off' : 'mati';
  String reminderNext(String date) => _en ? 'next $date' : 'berikutnya $date';
  String get reminderOver => _en ? 'no more to come' : 'sudah lewat';
  String deleteReminderQuestion(String title) =>
      _en ? 'Delete the reminder $title?' : 'Hapus pengingat $title?';

  /// The question asked before all of a category's reminders are deleted.
  ///
  /// It says outright how much goes: every reminder in the category, on
  /// whatever day it falls, not only the day on screen.
  String deleteRemindersQuestion(int count, String category) => _en
      ? 'This deletes EVERY reminder in $category, on every date: '
            '${count == 1 ? '1 reminder' : 'all $count reminders'}. '
            'To delete only one, swipe it left.'
      : 'Ini menghapus SEMUA pengingat $category, pada semua tanggal: '
            '$count pengingat. Untuk menghapus satu saja, geser ke kiri.';
  String get notificationsOff => _en
      ? 'Saved, but notifications are off for Candra, so it will not '
            "sound. Allow them in the phone's settings."
      : 'Tersimpan, tetapi notifikasi untuk Candra tidak diaktifkan, jadi tidak '
            'akan berbunyi. Izinkan di pengaturan ponsel.';

  /// The days of the week by name, Monday first.
  String weekdayName(Weekday weekday) => _en
      ? const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ][weekday.index]
      : weekday.label;

  /// How a reminder starting on [start] comes round, in words: "Every
  /// Minggu Legi", "Javanese: every 28 Bakdamulud".
  String repeatLabel(Repeat repeat, CivilDate start, Duration utcOffset) {
    final weton = Weton.of(start);
    String every(String what) => _en ? 'Every $what' : 'Setiap $what';
    String monthly(CalendarSystem system, int day) =>
        '${systemLabel(system)}: '
        '${_en ? 'day $day of every month' : 'tanggal $day setiap bulan'}';
    String yearly(CalendarSystem system, String date) =>
        '${systemLabel(system)}: ${_en ? 'every' : 'setiap'} $date';

    switch (repeat) {
      case Repeat.once:
        return _en ? 'Once' : 'Sekali';
      case Repeat.daily:
        return _en ? 'Every day' : 'Setiap hari';
      case Repeat.weekday:
        return _en
            ? 'Every ${weekdayName(weton.weekday)}'
            : 'Setiap hari ${weton.weekday.label}';
      case Repeat.pasaran:
        return every(weton.pasaran.label);
      case Repeat.weton:
        return every('$weton');
      case Repeat.gregorianMonth:
        return _en
            ? 'Day ${start.day} of every month'
            : 'Tanggal ${start.day} setiap bulan';
      case Repeat.gregorianYear:
        return every(dayMonth(start));
      case Repeat.javaneseMonth:
        return monthly(CalendarSystem.javanese, JavaneseDate.of(start).day);
      case Repeat.javaneseYear:
        final date = JavaneseDate.of(start);
        return yearly(
          CalendarSystem.javanese,
          '${date.day} ${date.month.label}',
        );
      case Repeat.hijriMonth:
        return monthly(CalendarSystem.hijri, HijriDate.of(start).day);
      case Repeat.hijriYear:
        final date = HijriDate.of(start);
        return yearly(
          CalendarSystem.hijri,
          '${date.day} ${hijriMonth(date.month)}',
        );
      case Repeat.chineseMonth:
        return monthly(CalendarSystem.chinese, ChineseDate.of(start).day);
      case Repeat.chineseYear:
        final date = ChineseDate.of(start);
        return yearly(CalendarSystem.chinese, '${date.day} ${date.monthLabel}');
      case Repeat.moon:
        return every(moonPhase(Moon.of(start, utcOffset: utcOffset).phase));
    }
  }

  // Export and import.
  String get journalFileTitle => _en ? 'Export and import' : 'Ekspor dan impor';

  String journalSummary(int entries, int categories) => _en
      ? '$entries ${entries == 1 ? 'entry' : 'entries'} in $categories '
            '${categories == 1 ? 'category' : 'categories'}'
      : '$entries catatan dalam $categories kategori';

  String get shareCopy => _en ? 'Share a copy' : 'Bagikan salinan';
  String get shareCopyHint =>
      _en ? 'Send the journal to another app' : 'Kirim jurnal ke aplikasi lain';
  String get saveCopy => _en ? 'Save a copy' : 'Simpan salinan';
  String get saveCopyHint =>
      _en ? 'Choose where on this device' : 'Pilih tempat di perangkat ini';
  String get importFile => _en ? 'Import a file' : 'Impor berkas';
  String get importFileHint => _en
      ? 'Adds to this journal, nothing here is replaced.'
      : 'Menambah ke jurnal ini, tidak ada yang diganti.';

  String get exportNote => _en
      ? 'A copy is a zip of plain (unencrypted) Markdown files, one per entry.'
      : 'Salinan berupa zip berisi berkas Markdown biasa (tidak dienkripsi), satu per catatan.';

  // The actions on the action strip, in a word each.
  String get fileShare => _en ? 'Share' : 'Bagikan';
  String get fileImport => _en ? 'Import' : 'Impor';
  String get fileSync => _en ? 'Sync' : 'Sinkron';
  String get fileResolve => _en ? 'Resolve' : 'Selesaikan';
  String get fileTurnOff => _en ? 'Turn off' : 'Matikan';
  String get inJournal => _en ? 'In this journal' : 'Isi jurnal ini';

  String get packing => _en ? 'Packing…' : 'Mengemas…';
  String get reading => _en ? 'Reading the file…' : 'Membaca berkas…';
  String importing(int done, int total) =>
      _en ? 'Importing $done / $total' : 'Mengimpor $done / $total';
  String get copySaved => _en ? 'Copy saved.' : 'Salinan tersimpan.';
  String get exportFailed =>
      _en ? 'Could not make the copy.' : 'Salinan tidak dapat dibuat.';
  String get notJournalFile =>
      _en ? 'That is not a journal file.' : 'Itu bukan berkas jurnal.';
  String get importFailed =>
      _en ? 'Could not read that file.' : 'Berkas itu tidak dapat dibaca.';
  String tooManyCategories(int count) => _en
      ? 'That would make $count categories; 24 is the limit.'
      : 'Itu akan menjadi $count kategori; batas maksimal adalah 24.';

  /// What an import did, in a sentence or two.
  String importDone({
    required int entries,
    required int categories,
    required int alreadyHere,
    required int unreadable,
  }) {
    final parts = <String>[];
    if (entries == 0 && categories == 0) {
      parts.add(_en ? 'Nothing new in that file.' : 'Tidak ada yang baru.');
    } else if (_en) {
      parts.add(
        'Added $entries ${entries == 1 ? 'entry' : 'entries'}'
        '${categories == 0 ? '' : ' and $categories '
                  '${categories == 1 ? 'category' : 'categories'}'}.',
      );
    } else {
      parts.add(
        'Menambahkan $entries catatan'
        '${categories == 0 ? '' : ' dan $categories kategori'}.',
      );
    }
    if (alreadyHere > 0) {
      parts.add(
        _en
            ? '$alreadyHere ${alreadyHere == 1 ? 'was' : 'were'} already here.'
            : '$alreadyHere sudah ada.',
      );
    }
    if (unreadable > 0) {
      parts.add(
        _en
            ? '$unreadable could not be read.'
            : '$unreadable tidak dapat dibaca.',
      );
    }
    return parts.join(' ');
  }

  /// The question asked before a whole card is deleted.
  ///
  /// It says outright how much goes: every entry of the card, on that
  /// day. One entry alone is deleted by drawing it to the left.
  String deleteCardQuestion(int entries, String category, String date) => _en
      ? 'This deletes EVERY entry in $category on $date: '
            '${entries == 1 ? '1 entry' : 'all $entries entries'}. '
            'To delete only one, swipe it left.'
      : 'Ini menghapus SEMUA catatan $category pada $date: '
            '$entries catatan. Untuk menghapus satu saja, geser ke kiri.';

  String get nothingLogged =>
      _en ? 'Nothing logged on this day.' : 'Belum ada catatan pada hari ini.';

  String get moon => _en ? 'Moon' : 'Bulan';
  // Geotags.

  /// Said for as long as a geotag is being looked at or named.
  String get placePrecision => _en
      ? 'Rounded to about 100 m before it is saved: the exact spot is '
            'never kept. It is written in the entry as plain text and goes '
            'wherever the journal goes.'
      : 'Dibulatkan hingga sekitar 100 m sebelum disimpan: titik persisnya '
            'tidak pernah disimpan. Ditulis di catatan sebagai teks biasa '
            'dan ikut ke mana pun jurnal pergi.';
  String get placeNamePlaceholder =>
      _en ? 'Name this place' : 'Nama tempat ini';
  String get placeNearby => _en ? 'Nearby' : 'Di dekat sini';
  String get placeDenied => _en
      ? "Candra is not allowed to use location. Allow it in the phone's "
            'settings to tag an entry.'
      : 'Candra tidak diizinkan memakai lokasi. Izinkan di pengaturan '
            'ponsel untuk menandai catatan.';
  String get placeOff => _en
      ? 'Location is switched off on this phone.'
      : 'Lokasi dimatikan di ponsel ini.';

  /// Said from the start of a search: it can be stopped.
  String get placeFindingStop => _en
      ? 'Finding where you are… Tap the pin again to stop.'
      : 'Mencari posisi Anda… Ketuk pin lagi untuk berhenti.';

  /// Said when a search has gone on a while.
  String get placeStillFinding => _en
      ? 'Still looking. GPS needs open sky; indoors it may not find you.'
      : 'Masih mencari. GPS perlu langit terbuka; di dalam ruangan bisa '
            'gagal.';
  String get placeTimeout => _en
      ? 'Could not find where you are. Try again outdoors or by a window.'
      : 'Posisi Anda tidak ditemukan. Coba lagi di luar ruangan atau dekat '
            'jendela.';

  /// Said when the search failed and the phone had only GPS to go by.
  String get placeNeedsSky => _en
      ? 'Could not find where you are. This phone is using GPS only, which '
            'needs open sky: try outdoors or by a window, or turn on '
            "Location Accuracy in the phone's location settings."
      : 'Posisi Anda tidak ditemukan. Ponsel ini hanya memakai GPS, yang '
            'perlu langit terbuka: coba di luar ruangan atau dekat jendela, '
            'atau aktifkan Location Accuracy di pengaturan lokasi ponsel.';
  String get placeUnavailable => _en
      ? 'This phone cannot say where it is.'
      : 'Ponsel ini tidak dapat menentukan posisinya.';

  /// Said when the phone would only give an approximate position.
  String placeRough(int kilometres) => _en
      ? 'Tagged, but the phone only gave an approximate position: it may '
            'be off by about $kilometres km.'
      : 'Ditandai, tetapi ponsel hanya memberi posisi perkiraan: bisa '
            'meleset sekitar $kilometres km.';
  String get noMapsApp => _en
      ? 'No maps app on this phone.'
      : 'Tidak ada aplikasi peta di ponsel ini.';

  String get copied => _en ? 'Copied.' : 'Disalin.';
  // The bazi chart.
  // The menu.
  String get menuTitle => 'Menu';
  String get menuYourData => _en ? 'Your data' : 'Data Anda';
  String get menuLook => _en ? 'Look' : 'Tampilan';
  String get menuColours => _en ? 'Colours' : 'Warna';
  String get menuColoursSummary =>
      _en ? 'Each calendar\'s colour scheme' : 'Skema warna setiap kalender';

  // The colours of the calendar systems.
  String get coloursTitle => _en ? 'Colours' : 'Warna';
  String get coloursScheme => _en ? 'Colour scheme' : 'Skema warna';
  String get coloursCalendar => _en ? 'Calendar' : 'Kalender';
  String get coloursRestore => _en ? 'Restore defaults' : 'Kembalikan bawaan';
  String get coloursRestoreAsk => _en
      ? 'Put every calendar back in its own colours?'
      : 'Kembalikan setiap kalender ke warnanya sendiri?';
  String colourSchemeName(ColourScheme scheme) => switch (scheme) {
    ColourScheme.amber => _en ? 'Amber' : 'Ambar',
    ColourScheme.moss => _en ? 'Moss' : 'Lumut',
    ColourScheme.vermilion => _en ? 'Vermilion' : 'Merah',
    ColourScheme.teal => _en ? 'Teal' : 'Toska',
    ColourScheme.night => _en ? 'Night' : 'Malam',
    ColourScheme.slate => _en ? 'Slate' : 'Kelabu',
    ColourScheme.indigo => _en ? 'Indigo' : 'Nila',
    ColourScheme.plum => _en ? 'Plum' : 'Ungu',
    ColourScheme.rose => _en ? 'Rose' : 'Mawar',
    ColourScheme.ocean => _en ? 'Ocean' : 'Samudra',
    ColourScheme.stone => _en ? 'Stone' : 'Batu',
  };
  String get menuHelp => _en ? 'Help' : 'Bantuan';
  String get menuAbout => _en ? 'About' : 'Tentang';
  String get menuData => _en ? 'Journal file' : 'Berkas jurnal';
  String get menuDataSummary => _en
      ? 'Export, import, share and sync'
      : 'Ekspor, impor, bagikan dan sinkron';
  String get menuManual => _en ? 'Manual' : 'Panduan';
  String get menuManualSummary => _en
      ? 'Every feature, and what it is for'
      : 'Setiap fitur dan kegunaannya';
  String get menuFeedback => _en ? 'Send feedback' : 'Kirim masukan';
  String get menuReckoning =>
      _en ? 'How the dates are reckoned' : 'Cara tanggal dihitung';
  String get menuReckoningSummary => _en
      ? 'Rules, sources, and where they differ'
      : 'Aturan, sumber, dan di mana berbeda';
  String get menuStanceSummary => _en
      ? 'A stance, signed, with its sources'
      : 'Sikap, bertanda tangan, beserta sumbernya';
  String get reckoningSources => _en ? 'Sources' : 'Sumber';
  String get reckoningNoSources => _en
      ? 'This chapter states the app\'s own practice; it rests on no source.'
      : 'Bab ini menyatakan cara aplikasi sendiri; tidak bersandar pada sumber.';

  /// What a source is to its chapter. In English in both languages, as
  /// the chapters are for now (owner, 23 October 2026).
  String sourceStanding(Source source) => switch (source.standing) {
    SourceStanding.read => 'Primary source',
    SourceStanding.cited =>
      source.via == null
          ? 'Secondary source'
          : 'Secondary source, through ${source.via}',
    SourceStanding.compared => 'Control: the results were checked against it',
  };

  String get menuPrivacy => _en ? 'Privacy policy' : 'Kebijakan privasi';
  String get menuPrivacySummary =>
      _en ? 'Opens in the browser' : 'Dibuka di peramban';
  String get menuLicences => _en ? 'Licences' : 'Lisensi';
  String get menuLicencesSummary => _en
      ? 'The open-source software inside'
      : 'Perangkat lunak sumber terbuka di dalamnya';
  String menuVersion(String version) =>
      _en ? 'Version $version' : 'Versi $version';

  // The manual (owner, 22 October 2026). Its words are in
  // assets/samples/showcase-strings.json, under manual.*.
  String get manualGotIt => _en ? 'Got it' : 'Mengerti';

  // The I Ching.
  String get ichingTitle => 'I Ching';
  String get ichingSubtitle => _en
      ? 'Cast a hexagram, or read the book'
      : 'Buang undi, atau baca heksagram';
  String get ichingCoins => _en ? 'Coins' : 'Koin';
  String get ichingStalks => _en ? 'Stalks' : 'Batang';
  String get ichingRead => _en ? 'Read' : 'Baca';
  String get ichingManual => 'Manual';
  String get ichingManualLine =>
      _en ? 'Six lines, set by hand' : 'Enam garis, diisi sendiri';
  String get ichingManualAsk => _en
      ? 'Set the six lines, from the bottom.'
      : 'Isi keenam garis, dari bawah.';
  String get ichingManualNote => _en
      ? '6 is old yin and 9 old yang, the lines that change; 7 is young '
            'yang and 8 young yin, at rest.'
      : '6 yin tua dan 9 yang tua, garis yang berubah; 7 yang muda dan 8 '
            'yin muda, diam.';
  String get ichingCoinsLine =>
      _en ? 'Three coins, six throws' : 'Tiga koin, enam lemparan';
  String get ichingStalksLine => _en
      ? 'Forty-nine stalks, the old way'
      : 'Empat puluh sembilan batang, cara lama';
  String get ichingReadLine =>
      _en ? 'The sixty-four, one by one' : 'Keenam puluh empat, satu per satu';
  String get ichingCoinsNote => _en
      ? 'Three coins, six throws. A changing line comes once in four '
            'throws, yin and yang alike.'
      : 'Tiga koin, enam lemparan. Garis berubah muncul sekali dalam '
            'empat lemparan, yin dan yang sama seringnya.';
  String get ichingStalksNote => _en
      ? 'Forty-nine stalks, counted three times for each line. A changing '
            'yang comes three times in sixteen, a changing yin once.'
      : 'Empat puluh sembilan batang, dihitung tiga kali untuk tiap garis. '
            'Yang berubah muncul tiga kali dalam enam belas, yin berubah '
            'sekali.';
  String ichingLineOf(int line) =>
      _en ? 'Line $line of 6' : 'Garis $line dari 6';
  String get ichingAsk => _en
      ? 'Hold the question, then cast.'
      : 'Pegang pertanyaannya, lalu buang undi.';
  String ichingLineValue(LineValue value) => switch (value) {
    LineValue.oldYin => _en ? '6 · yin, changing' : '6 · yin, berubah',
    LineValue.youngYang => _en ? '7 · yang' : '7 · yang',
    LineValue.youngYin => _en ? '8 · yin' : '8 · yin',
    LineValue.oldYang => _en ? '9 · yang, changing' : '9 · yang, berubah',
  };

  // The cast and the journal.
  String get ichingSave => _en ? 'Save' : 'Simpan';
  String get ichingLoad => _en ? 'Load' : 'Muat';
  String get ichingSaveHere => _en ? 'Save here' : 'Simpan di sini';
  String get ichingSaveNew =>
      _en ? 'Save as new entry' : 'Simpan sebagai catatan baru';
  String get ichingDiscard => _en ? 'Discard' : 'Buang';
  String get ichingSaveTo =>
      _en ? 'Save under which category?' : 'Simpan di kategori mana?';
  String get ichingLoadNone => _en
      ? 'No cast has been saved to the journal yet. Casts saved from here '
            'can be loaded back.'
      : 'Belum ada undian yang disimpan di jurnal. Undian yang '
            'disimpan dari sini bisa dimuat kembali.';
  String get ichingLoadUnusable =>
      _en ? 'Cannot be read back' : 'Tidak bisa dibaca kembali';
  String ichingLoadCast(String day) => _en ? 'Cast $day' : 'Diundi $day';
  String ichingLoaded(String title) =>
      _en ? 'Cast from $title loaded' : 'Undian dari $title dimuat';
  String get ichingDiscarded => _en ? 'Changes discarded' : 'Perubahan dibuang';
  String ichingSaveAsk(String title) => _en
      ? 'Save this cast to "$title", or as a new entry?'
      : 'Simpan undian ini ke "$title", atau sebagai catatan baru?';
  String ichingSavedAsk(String title) => _en
      ? 'This cast is already in the journal, as "$title". Save it again '
            'as a new entry?'
      : 'Undian ini sudah ada di jurnal, sebagai "$title". Simpan lagi '
            'sebagai catatan baru?';
  String ichingDiscardAsk(String title) => _en
      ? 'Discard the new cast, and go back to the one in "$title"?'
      : 'Buang undian baru, dan kembali ke undian di "$title"?';
  String get ichingRewritten =>
      _en ? 'The entry was changed.' : 'Catatan diubah.';
  String get ichingCardOpen => _en ? 'Open the cast' : 'Buka undian';
  String get ichingCardIncomplete => _en
      ? 'This cast cannot be read back.'
      : 'Undian ini tidak bisa dibaca kembali.';
  String ichingMethod(CastMethod method) => switch (method) {
    CastMethod.coins => ichingCoins,
    CastMethod.stalks => ichingStalks,
    CastMethod.manual => ichingManual,
  };

  // A hexagram read.
  String get ichingLines => _en ? 'Lines' : 'Garis';
  String get ichingNotes => _en ? 'Notes' : 'Catatan';
  String get ichingReadings => _en ? 'Readings' : 'Tafsir';
  String get ichingCredit => _en ? 'Credit' : 'Kredit';
  String get ichingJudgment => _en ? 'Judgment' : 'Putusan';
  String get ichingImage => _en ? 'Image' : 'Citra';
  String get ichingLater =>
      _en ? 'a later layer of the book' : 'lapisan kitab yang lebih muda';
  String ichingAsRead(String who) =>
      _en ? 'As $who reads it' : 'Menurut bacaan $who';
  String get ichingChanges => _en ? 'changes' : 'berubah';
  String get ichingPinyin => 'Pinyin';
  String ichingPage(ReadingPage page) => switch (page) {
    ReadingPage.main => _en ? 'Main' : 'Utama',
    ReadingPage.wilhelm => 'Wilhelm',
    ReadingPage.legge => 'Legge',
    ReadingPage.notes => ichingNotes,
    ReadingPage.readings => ichingReadings,
    ReadingPage.credit => ichingCredit,
  };
  String ichingBecomesTo(int number, String name) =>
      _en ? 'Becomes $number $name' : 'Menjadi $number $name';
  String ichingBackTo(int number, String name) =>
      _en ? 'Back to $number $name' : 'Kembali ke $number $name';

  /// The translator's page: the year of his book after his name in its
  /// title, and a quiet line where his text is not in the pack yet.
  String ichingTranslatorYear(ReadingPage page) => switch (page) {
    ReadingPage.wilhelm => '1924',
    ReadingPage.legge => '1882',
    _ => '',
  };
  String ichingTranslatorNotYet(ReadingPage page) => _en
      ? '${ichingPage(page)}\'s text of this hexagram is not in yet.'
      : 'Teks ${ichingPage(page)} untuk heksagram ini belum dimuat.';
  String get ichingNoReadings => _en
      ? 'No reading of this hexagram is in dispute.'
      : 'Tak ada bacaan heksagram ini yang diperdebatkan.';
  String get ichingNoLineChanges => _en
      ? 'No line changes: the judgment and the Image are read.'
      : 'Tak ada garis berubah: yang dibaca putusan dan citranya.';
  String get ichingBecomesLines => _en
      ? 'What the cast becomes: its judgment and its Image are read. The '
            'lines that change are read in the hexagram cast.'
      : 'Yang dijadikan undian: putusan dan citranya yang dibaca. Garis '
            'yang berubah dibaca pada heksagram yang diundi.';
  String get ichingNotYet => _en
      ? 'Our translation of this hexagram is not finished. The Chinese is '
            'given as it stands.'
      : 'Terjemahan kami untuk heksagram ini belum selesai. Teks Tionghoanya '
            'ditampilkan apa adanya.';
  String get ichingNoIndonesian => _en
      ? 'The Indonesian is not done yet; this is the English.'
      : 'Terjemahan bahasa Indonesia belum selesai; ini versi bahasa '
            'Inggrisnya.';
  String get ichingAllChange => _en
      ? 'All six lines change: this is the text to read.'
      : 'Keenam garis berubah: inilah teks yang dibaca.';
  String ichingTrigram(Trigram trigram) => switch (trigram) {
    Trigram.qian => _en ? 'Heaven' : 'Langit',
    Trigram.dui => _en ? 'Lake' : 'Danau',
    Trigram.li => _en ? 'Fire' : 'Api',
    Trigram.zhen => _en ? 'Thunder' : 'Guntur',
    Trigram.xun => _en ? 'Wind' : 'Angin',
    Trigram.kan => _en ? 'Water' : 'Air',
    Trigram.gen => _en ? 'Mountain' : 'Gunung',
    Trigram.kun => _en ? 'Earth' : 'Bumi',
  };
  String ichingBelowAbove(Trigram lower, Trigram upper) => _en
      ? '${lower.name} ${ichingTrigram(lower)} below · '
            '${upper.name} ${ichingTrigram(upper)} above'
      : '${lower.name} ${ichingTrigram(lower)} di bawah · '
            '${upper.name} ${ichingTrigram(upper)} di atas';

  // The book, the sixty-four.
  String get ichingLibrary => _en ? 'The sixty-four' : 'Enam puluh empat';
  String get ichingByNumber => _en ? 'Number' : 'Nomor';
  String get ichingByTrigrams => _en ? 'Trigrams' : 'Trigram';
  String get ichingUpper => _en ? 'Upper' : 'Atas';
  String get ichingLower => _en ? 'Lower' : 'Bawah';
  String get ichingOpen => _en ? 'Open' : 'Buka';

  // Utilities: what a system can do beyond naming the day.
  String utilityName(Utility utility) => switch (utility) {
    Utility.bazi => baziTitle,
    Utility.mangsa => mangsaTitle,
    Utility.iching => ichingTitle,
    Utility.sky => skyTitle,
    Utility.stars => starsTitle,
    Utility.lintang => lintangTitle,
    Utility.light => lightTitle,
    Utility.salat => salatTitle,
    Utility.hilal => hilalTitle,
    Utility.planets => planetsTitle,
  };

  String utilitySummary(Utility utility) => switch (utility) {
    Utility.bazi =>
      _en ? 'The four pillars of a moment' : 'Empat pilar suatu saat',
    Utility.mangsa =>
      _en ? 'The Javanese year of seasons' : 'Tahun musim orang Jawa',
    Utility.iching =>
      _en ? 'Cast and read a hexagram' : 'Buang undi dan baca heksagram',
    Utility.sky =>
      _en ? 'Where the sun and moon stand' : 'Letak matahari dan bulan',
    Utility.stars =>
      _en
          ? 'The sky as it stands, star by star'
          : 'Langit apa adanya, bintang demi bintang',
    Utility.light => _en ? 'Planning photographs' : 'Merencanakan foto',
    Utility.lintang =>
      _en ? 'The stars the seasons were read by' : 'Bintang penanda musim',
    Utility.salat =>
      _en ? 'The five prayers on the clock' : 'Lima waktu salat di jam',
    Utility.hilal =>
      _en
          ? 'The young crescent after the new moon'
          : 'Bulan sabit muda selepas ijtimak',
    Utility.planets =>
      _en ? 'The planets, their hours and lore' : 'Planet, jam dan ajarannya',
  };

  // Pranata mangsa. The mangsa keep their Javanese names, and each its
  // candra as the primbon has it; what is translated is what they say.
  String get mangsaTitle => 'Pranata mangsa';
  String get mangsa => 'Mangsa';
  String mangsaDay(PranataMangsa date) => _en
      ? 'Day ${date.day} of ${date.length}'
      : 'Hari ke-${date.day} dari ${date.length}';
  String mangsaDays(int days) => _en ? '$days days' : '$days hari';
  String mangsaYear(int year) => _en ? 'Year $year' : 'Tahun $year';
  String get mangsaDates => _en ? 'Dates' : 'Tanggal';
  String get mangsaSeasonLabel => _en ? 'Season' : 'Musim';
  String get mangsaMeans => _en ? 'Stands for' : 'Maksudnya';
  String get mangsaSigns => _en ? 'Signs' : 'Tanda alam';
  String get mangsaWork => _en ? 'In the field' : 'Di sawah';
  String get mangsaShadow => _en ? 'Noon shadow' : 'Bayangan tengah hari';
  String get mangsaShadowNow => _en ? 'Measured this day' : 'Terukur hari ini';

  /// The date range of a mangsa, days and short months.
  String mangsaRange(CivilDate from, CivilDate to) {
    String short(CivilDate date) =>
        '${date.day} ${monthNames[date.month - 1].substring(0, 3)}';
    return '${short(from)} – ${short(to)}';
  }

  String mangsaSeason(MangsaSeason season) => switch (season) {
    MangsaSeason.katiga => _en ? 'dry season' : 'kemarau',
    MangsaSeason.labuh => _en ? 'turn to the rains' : 'menjelang hujan',
    MangsaSeason.rendheng => _en ? 'the rains' : 'musim hujan',
    MangsaSeason.mareng => _en ? 'turn to the dry' : 'menjelang kemarau',
  };

  String mangsaPhase(MangsaPhase phase) => switch (phase) {
    MangsaPhase.terang => _en ? 'clear skies' : 'langit cerah',
    MangsaPhase.semplah => _en ? 'hardship' : 'masa susah',
    MangsaPhase.udan => _en ? 'rain' : 'hujan',
    MangsaPhase.pangarepArep => _en ? 'hope' : 'penuh harap',
  };

  /// The court's shadow for the day a mangsa opens: a person's noon
  /// shadow in their own feet (pecak), and the way it falls.
  String mangsaPecak(Mangsa mangsa) {
    final south = mangsa.shadowSouth;
    if (south == null) {
      return _en
          ? 'None: the sun is overhead'
          : 'Tidak ada: matahari di atas kepala';
    }
    final way = south
        ? (_en ? 'to the south' : 'ke selatan')
        : (_en ? 'to the north' : 'ke utara');
    return _en
        ? '${mangsa.pecak} ${mangsa.pecak == 1 ? 'foot' : 'feet'} (pecak) $way'
        : '${mangsa.pecak} pecak $way';
  }

  /// A measured noon shadow, as a share of the height of what casts it.
  String mangsaMeasured(double shadow) {
    final share = shadow.abs().toStringAsFixed(2);
    if (shadow.abs() < 0.005) {
      return _en ? 'none' : 'tidak ada';
    }
    final way = shadow > 0
        ? (_en ? 'to the south' : 'ke selatan')
        : (_en ? 'to the north' : 'ke utara');
    return _en ? '$share of your height, $way' : '$share tinggi badan, $way';
  }

  /// The candra put into words, as near the Javanese as they go.
  String candra(Mangsa mangsa) => switch (mangsa) {
    Mangsa.kasa =>
      _en ? 'A jewel slips from its setting' : 'Permata lepas dari embanannya',
    Mangsa.karo => _en ? 'The earth cracks' : 'Tanah merekah',
    Mangsa.katelu =>
      _en ? 'The child follows the father' : 'Anak menurut pada bapaknya',
    Mangsa.kapat =>
      _en ? 'Tears well up in the heart' : 'Air mata menggenang di dalam kalbu',
    Mangsa.kalima =>
      _en
          ? 'A golden fountain scatters over the world'
          : 'Pancuran emas tersebar di jagad',
    Mangsa.kanem => _en ? 'The taste of noble purity' : 'Rasa mulia kesucian',
    Mangsa.kapitu =>
      _en ? 'Venom drifts on the wind' : 'Bisa hanyut terbawa angin',
    Mangsa.kawolu =>
      _en ? 'Spreading through desire' : 'Merata di dalam keinginan',
    Mangsa.kasanga =>
      _en ? 'Noble speech unfolds' : 'Terurainya kata-kata mulia',
    Mangsa.kasadasa =>
      _en
          ? 'A storehouse shut within the heart'
          : 'Gedung tertutup di dalam kalbu',
    Mangsa.desta => _en ? 'A jewel cut and polished' : 'Permata yang digosok',
    Mangsa.sada => _en ? 'Water leaves its seat' : 'Air pergi dari tempatnya',
  };

  /// What the candra stands for, as the court's own gloss has it.
  String candraMeans(Mangsa mangsa) => switch (mangsa) {
    Mangsa.kasa =>
      _en ? 'Leaves fall from the trees.' : 'Daun-daun gugur dari pohonnya.',
    Mangsa.karo =>
      _en ? 'The ground dries and splits.' : 'Tanah mengering dan retak.',
    Mangsa.katelu =>
      _en
          ? 'Climbing plants follow their stakes.'
          : 'Tanaman merambat mengikuti lanjarannya.',
    Mangsa.kapat =>
      _en
          ? 'The springs: stopped up in some tellings, starting to fill in '
                'others.'
          : 'Mata air: mampat menurut sebagian sumber, mulai terisi menurut '
                'yang lain.',
    Mangsa.kalima => _en ? 'The first rains.' : 'Hujan pertama.',
    Mangsa.kanem =>
      _en
          ? 'Fruit is ripe everywhere.'
          : 'Buah-buahan sedang banyak-banyaknya.',
    Mangsa.kapitu => _en ? 'A time of much sickness.' : 'Masa banyak penyakit.',
    Mangsa.kawolu => _en ? 'Cats mate.' : 'Musim kucing kawin.',
    Mangsa.kasanga =>
      _en
          ? 'Crickets and cicadas begin to sound.'
          : 'Jangkrik dan tonggeret mulai bersuara.',
    Mangsa.kasadasa => _en ? 'Animals carry young.' : 'Masa hewan bunting.',
    Mangsa.desta =>
      _en ? 'Birds feed their young.' : 'Burung menyuapi anaknya.',
    Mangsa.sada =>
      _en
          ? 'No one sweats in the cold.'
          : 'Orang jarang berkeringat karena dingin.',
  };

  String mangsaSignsOf(Mangsa mangsa) => switch (mangsa) {
    Mangsa.kasa =>
      _en
          ? 'Leaves fall, wood dries, grasshoppers go into the ground.'
          : 'Daun berguguran, kayu mengering, belalang masuk ke tanah.',
    Mangsa.karo =>
      _en
          ? 'Soil cracks; kapok and mango trees flower.'
          : 'Tanah retak-retak; randu dan mangga mulai berbunga.',
    Mangsa.katelu =>
      _en
          ? 'Vines climb, bamboo shoots come up, wells run low.'
          : 'Tanaman merambat naik, rebung bermunculan, sumur mulai kering.',
    Mangsa.kapat =>
      _en
          ? 'Kapok trees fruit; small birds nest and lay.'
          : 'Randu berbuah; burung-burung kecil bersarang dan bertelur.',
    Mangsa.kalima =>
      _en
          ? 'Rain begins; tamarind puts out young leaves; flying termites '
                'leave their holes.'
          : 'Hujan mulai turun; asam jawa berdaun muda; laron keluar dari '
                'liang.',
    Mangsa.kanem =>
      _en
          ? 'Durian, rambutan and mangosteen ripen; whistling ducks appear '
                'on the water.'
          : 'Durian, rambutan dan manggis bermunculan; belibis terlihat di '
                'perairan.',
    Mangsa.kapitu =>
      _en
          ? 'Heavy rain, rivers in flood, strong wind.'
          : 'Hujan lebat, sungai banjir, angin kencang.',
    Mangsa.kawolu =>
      _en
          ? 'Rice greens and swells; grubs come up.'
          : 'Padi menghijau dan berisi; uret bermunculan.',
    Mangsa.kasanga =>
      _en
          ? 'Rice flowers; mole crickets call; the last floods.'
          : 'Padi berbunga; gangsir berbunyi; banjir penghabisan.',
    Mangsa.kasadasa =>
      _en
          ? 'Rice yellows; small birds hatch.'
          : 'Padi menguning; telur burung-burung kecil menetas.',
    Mangsa.desta => _en ? 'Kapok pods split open.' : 'Buah randu merekah.',
    Mangsa.sada =>
      _en
          ? 'Cold, dry nights (bediding).'
          : 'Malam dingin dan kering (bediding).',
  };

  /// The court's guidance for the farmer, from when wet rice was grown
  /// once a year. A dash where it gives none.
  String mangsaWorkOf(Mangsa mangsa) => switch (mangsa) {
    Mangsa.kasa =>
      _en
          ? 'Burn the stubble; begin planting palawija (dry-season crops).'
          : 'Membakar jerami; mulai menanam palawija.',
    Mangsa.karo =>
      _en
          ? 'The palawija comes up; a lean time.'
          : 'Palawija mulai tumbuh; masa paceklik.',
    Mangsa.katelu =>
      _en
          ? 'Harvest the palawija; the fields lie unplanted in the heat.'
          : 'Panen palawija; lahan tidak ditanami karena panas.',
    Mangsa.kapat =>
      _en
          ? 'Work the land for dry rice (padi gaga).'
          : 'Menggarap lahan untuk padi gaga.',
    Mangsa.kalima =>
      _en
          ? 'Mend the ditches and channels; sow dry rice.'
          : 'Memperbaiki selokan dan saluran air; menyebar padi gaga.',
    Mangsa.kanem =>
      _en ? 'Sow rice in the seedbed.' : 'Menyebar benih padi di persemaian.',
    Mangsa.kapitu =>
      _en
          ? 'Move the seedlings to the field.'
          : 'Memindahkan bibit padi ke sawah.',
    Mangsa.kawolu || Mangsa.kasanga => '–',
    Mangsa.kasadasa =>
      _en ? 'Early rice begins to be cut.' : 'Mulai panen padi genjah.',
    Mangsa.desta =>
      _en ? 'The main harvest of early rice.' : 'Panen raya padi genjah.',
    Mangsa.sada =>
      _en
          ? 'Dry and store the rice; plant soybean, indigo and cotton; ready '
                'the dry fields for maize.'
          : 'Menjemur padi dan menyimpannya di lumbung; menanam kedelai, nila '
                'dan kapas; menggarap tegalan untuk jagung.',
  };

  String get baziFourPillars => _en ? 'Four pillars' : 'Empat pilar';
  String get baziExportTo => _en
      ? 'Save this chart to the journal, in'
      : 'Simpan bagan ini ke jurnal, di';
  String baziEntryTitle(String when) =>
      _en ? 'Bazi chart · $when' : 'Bagan Bazi · $when';
  String get baziCardIncomplete => _en
      ? 'This chart is missing what it needs to be drawn.'
      : 'Bagan ini kurang lengkap untuk digambar.';
  String get baziCardOpen => _en ? 'Open in bazi' : 'Buka di bazi';
  String baziLoaded(String title) =>
      _en ? 'Bazi entry for $title loaded' : 'Catatan bazi untuk $title dimuat';
  String get baziDiscarded => _en ? 'Changes discarded' : 'Perubahan dibuang';
  String baziSaveAsk(String title) => _en
      ? 'Save these changes to "$title", or as a new entry?'
      : 'Simpan perubahan ini ke "$title", atau sebagai catatan baru?';
  String get baziSaveHere => _en ? 'Save changes' : 'Simpan perubahan';
  String get baziSaveNew =>
      _en ? 'Save as new entry' : 'Simpan sebagai catatan baru';
  String get cancel => _en ? 'Cancel' : 'Batal';
  String baziDiscardAsk(String title) => _en
      ? 'Discard every change made to "$title"?'
      : 'Buang semua perubahan pada "$title"?';
  String get baziDiscard => _en ? 'Discard' : 'Buang';
  String get baziWritten =>
      _en ? 'Written to the journal.' : 'Tersimpan di jurnal.';
  String get baziRewritten =>
      _en ? 'The entry was changed.' : 'Catatan diubah.';
  String baziWriteAsk(String title) => _en
      ? 'This chart already has an entry, "$title". Change that entry, or '
            'add a new one?'
      : 'Bagan ini sudah punya catatan, "$title". Ubah catatan itu, atau '
            'tambah yang baru?';
  String get baziWriteEdit => _en ? 'Edit existing entry' : 'Ubah catatan';
  String get baziWriteNew => _en ? 'Add new entry' : 'Tambah catatan baru';
  String get baziReadNone => _en
      ? 'No chart has been written to the journal yet. Charts written from '
            'here can be read back.'
      : 'Belum ada bagan yang disimpan di jurnal. Bagan yang disimpan dari '
            'sini bisa dibaca kembali.';
  String get baziReadIncomplete => _en
      ? 'Missing what the chart needs, or written before charts could be '
            'read back'
      : 'Tidak lengkap untuk bagan, atau disimpan sebelum bagan bisa '
            'dibaca kembali';
  String baziReadWritten(String day) => _en ? 'Written $day' : 'Disimpan $day';
  String baziSavedAt(String when) => _en
      ? 'Saved from the bazi chart on $when.'
      : 'Disimpan dari bagan bazi pada $when.';
  String get baziTitle => _en ? 'Bazi chart' : 'Bagan Bazi';
  String get baziOpen => _en ? 'Bazi chart' : 'Bagan Bazi';
  String get baziDate => _en ? 'Date' : 'Tanggal';
  String get baziTime => _en ? 'Time' : 'Jam';
  String get baziPlace => _en ? 'Place' : 'Tempat';
  String get baziSex => _en ? 'Sex' : 'Kelamin';
  String get baziRules => _en ? 'Rules' : 'Aturan';
  String get baziOptions => _en ? 'Options' : 'Pilihan';
  String get baziToJournal => _en ? 'To the journal' : 'Ke jurnal';
  String get baziToJournalLine =>
      _en ? 'Write this chart into the journal' : 'Tulis bagan ini ke jurnal';
  String get baziFromJournal => _en ? 'From the journal' : 'Dari jurnal';
  String get baziFromJournalLine => _en
      ? 'Open a chart written into the journal'
      : 'Buka bagan yang tersimpan di jurnal';
  String get baziSaveLine => _en
      ? 'Save the changes to the entry, or as a new one'
      : 'Simpan perubahan ke catatan, atau sebagai yang baru';
  String get baziDiscardLine => _en
      ? 'Let go of every change made here'
      : 'Lepaskan semua perubahan di sini';
  String get baziMale => _en ? 'Male' : 'Laki-laki';
  String get baziFemale => _en ? 'Female' : 'Perempuan';
  String get baziNoSex => _en ? 'Not given' : 'Tidak diisi';
  String get baziLongitude => _en ? 'Longitude' : 'Bujur';
  String get baziNoLongitude => _en ? 'none' : 'tidak ada';
  String get baziUseHere => _en ? 'Here' : 'Di sini';

  /// "Clock 23:14 is 23:21 by the sun here (+7 min)."
  String baziSolar(String clock, String sun, int minutes) => _en
      ? 'Clock $clock is $sun by the sun there '
            '(${minutes >= 0 ? '+' : '−'}${minutes.abs()} min). '
            'The day and hour are read from the sun.'
      : 'Jam $clock adalah $sun menurut matahari di sana '
            '(${minutes >= 0 ? '+' : '−'}${minutes.abs()} mnt). '
            'Hari dan jam dibaca dari matahari.';
  String get baziNoPlace => _en
      ? 'No longitude given, so the day and hour are read from the clock. '
            'Bazi was made for sun time: give a place for a true reading.'
      : 'Bujur tidak diisi, jadi hari dan jam dibaca dari jam biasa. Bazi '
            'dibuat untuk waktu matahari: isi tempat untuk bacaan sejati.';
  String get baziByClock => _en
      ? 'Read from the clock, by your choice of rule.'
      : 'Dibaca dari jam biasa, sesuai aturan yang Anda pilih.';

  /// Said when the chart is in the hour before midnight.
  String baziLateZi(String thisDay, String otherDay) => _en
      ? 'This is the hour before midnight, where schools differ on the '
            'day. By this rule the day is $thisDay; by the other it is '
            '$otherDay, a different day master. Tap to see the other.'
      : 'Ini jam sebelum tengah malam, dan aliran berbeda pendapat soal '
            'harinya. Menurut aturan ini harinya $thisDay; menurut yang '
            'lain $otherDay, tuan hari yang berbeda. Ketuk untuk melihat '
            'yang lain.';

  /// Said under a chart placed by a zone: what its clocks kept then.
  String baziZone(String city, String offset) => _en
      ? 'Clocks in $city kept UTC$offset then.'
      : 'Jam di $city saat itu UTC$offset.';
  String get baziMonthOpened => _en ? 'Month opened' : 'Bulan dibuka';
  String get baziMonthCloses => _en ? 'Month closes' : 'Bulan ditutup';
  String get baziRelations => _en ? 'Relations' : 'Hubungan';
  String get baziElements => _en ? 'Elements' : 'Unsur';

  /// What the day's void branches touch: "none here", or the pillars.
  String baziVoidIn(List<String> pillars) => pillars.isEmpty
      ? (_en ? 'none in this chart' : 'tidak ada di bagan ini')
      : pillars.join(', ').toLowerCase();
  String get baziNoRelations =>
      _en ? 'none among these four' : 'tidak ada di antara keempatnya';
  String get baziLuck => _en ? 'Luck pillars' : 'Pilar keberuntungan';
  String get baziLuckNeedsSex => _en
      ? 'Luck pillars run forward or back by sex and the year. Choose '
            'one under Sex to see them.'
      : 'Pilar keberuntungan berjalan maju atau mundur menurut kelamin '
            'dan tahun. Pilih di Kelamin untuk melihatnya.';
  String baziLuckStart(bool forward, int years, int months, int days) => _en
      ? '${forward ? 'Forward' : 'Backward'}, from age $years y $months m '
            '$days d, ten years each'
      : '${forward ? 'Maju' : 'Mundur'}, mulai umur $years th $months bl '
            '$days hr, masing-masing sepuluh tahun';
  String baziLuckStartYears(bool forward, int years, bool nearest) => _en
      ? '${forward ? 'Forward' : 'Backward'}, from '
            '${nearest ? 'about age' : 'age'} $years, ten years each'
      : '${forward ? 'Maju' : 'Mundur'}, mulai '
            '${nearest ? 'sekitar umur' : 'umur'} $years, masing-masing '
            'sepuluh tahun';
  String baziAge(int age) => _en ? 'age $age' : 'umur $age';

  /// Said under every chart: whose tables these are.
  String baziLineage(TableSource hidden, TableSource relations) {
    final unchecked = _en
        ? ' (not checked against the text)'
        : ' (belum diperiksa terhadap naskahnya)';
    String of(TableSource table) =>
        '${table.lineage}${table.verified ? '' : unchecked}';
    return _en
        ? 'The pillars are astronomy and are the same for every school. '
              'Hidden stems are not: these follow ${of(hidden)}. Nor are '
              'punishments and harms: these follow ${of(relations)}. '
              'Other tables are under Rules. Nothing here is kept.'
        : 'Pilar adalah astronomi dan sama untuk semua aliran. Batang '
              'tersembunyi tidak: yang ini mengikuti ${of(hidden)}. '
              'Hukuman dan celaka juga tidak: yang ini mengikuti '
              '${of(relations)}. Tabel lain ada di Aturan. Tidak ada yang '
              'disimpan.';
  }

  /// A table's own short name.
  String baziTable(TableSource table) => _en ? table.english : table.indonesian;

  /// The tables a chart in the journal follows, in a line, in the
  /// chart's own words.
  String baziCardTables(TableSource hidden, TableSource relations) =>
      '${baziTerm(BaziTerms.hiddenStems)}: ${hidden.lineage}. '
      '${baziTerm(BaziTerms.punishment)}, ${baziTerm(BaziTerms.harm)}: '
      '${relations.lineage}.';
  String get baziRuleHidden => _en ? 'Hidden' : 'Batang';
  String get baziRulePunish => _en ? 'Punish' : 'Hukuman';

  /// How far into the month the chart is: "day 5".
  String baziMonthDay(int day) => _en ? 'day $day' : 'hari ke-$day';

  String baziTimeMode(TimeMode mode) => switch (mode) {
    TimeMode.trueSolar => _en ? 'True solar time' : 'Waktu matahari sejati',
    TimeMode.trueSolarLongitudeOnly => _en ? 'Longitude only' : 'Bujur saja',
    TimeMode.clock => _en ? 'Clock time' : 'Jam biasa',
  };
  String baziZiRule(ZiHourRule rule) => switch (rule) {
    ZiHourRule.split => _en ? '23:00 keeps the day' : '23:00 masih hari itu',
    ZiHourRule.unified =>
      _en ? '23:00 starts the next day' : '23:00 sudah hari berikutnya',
    ZiHourRule.trueSolarMidnight =>
      _en ? 'Day turns at sun midnight' : 'Hari berganti tengah malam matahari',
  };
  String baziYearBoundary(YearBoundary boundary) => switch (boundary) {
    YearBoundary.lichun =>
      _en ? 'Year turns at Lichun' : 'Tahun berganti saat Lichun',
    YearBoundary.lunarNewYear =>
      _en ? 'Year turns at lunar new year' : 'Tahun berganti saat Imlek',
  };

  // The rules, as headings on their wheel.
  String get baziRuleTime => _en ? 'Time' : 'Waktu';
  String get baziRuleZi => '23:00';
  String get baziRuleYear => _en ? 'Year' : 'Tahun';
  String get baziRuleLuckFrom => _en ? 'Luck from' : 'Hitung';
  String get baziRuleLuckAge => _en ? 'Luck age' : 'Umur';
  String baziLuckAnchor(LuckAnchor anchor) => switch (anchor) {
    LuckAnchor.termInstant => _en ? 'The term\'s minute' : 'Menit jieqi',
    LuckAnchor.termDay => _en ? 'The term\'s day' : 'Hari jieqi',
  };
  String baziLuckRounding(LuckRounding rounding) => switch (rounding) {
    LuckRounding.exact =>
      _en ? 'Age in years, months, days' : 'Umur dalam tahun, bulan, hari',
    LuckRounding.floorYears => _en ? 'Whole years' : 'Tahun bulat',
    LuckRounding.nearestYear => _en ? 'Nearest year' : 'Tahun terdekat',
  };

  /// A term of the art in the app's language.
  String baziTerm(BaziTerm term) => _en ? term.english : term.indonesian;

  /// How a character is read aloud: Mandarin pinyin, in both
  /// languages. (The Hokkien readings stay in the library, unused.)
  String baziReading(BaziTerm term) => term.pinyin;

  // The sky, in detailed mode.
  String get sun => _en ? 'Sun' : 'Matahari';
  String get sunrise => _en ? 'Sunrise' : 'Terbit';
  String get sunset => _en ? 'Sunset' : 'Terbenam';
  String get daylight => _en ? 'Daylight' : 'Lama siang';
  String get moonHeading => _en ? 'Moon' : 'Bulan';
  String get moonrise => _en ? 'Moonrise' : 'Bulan terbit';
  String get moonset => _en ? 'Moonset' : 'Bulan terbenam';
  String get moonLit => _en ? 'Lit' : 'Bercahaya';
  // The coming ones; "in 14 days" beside the date says so.
  String get nextFullMoon => _en ? 'Full moon' : 'Purnama';
  String get nextNewMoon => _en ? 'New moon' : 'Bulan baru';

  /// Said where a body does not rise or set within the day.
  String get notThatDay => _en ? 'not that day' : 'tidak hari itu';

  /// How long a practice went on: "45 s", "25 min", "1 h 05 min".
  String practiceLength(Duration length) {
    if (length.inMinutes < 1) return '${length.inSeconds} ${_en ? 's' : 'dtk'}';
    final minutes = length.inMinutes % 60;
    final unit = _en ? 'min' : 'mnt';
    if (length.inHours < 1) return '$minutes $unit';
    return '${length.inHours} ${_en ? 'h' : 'j'} '
        '${minutes.toString().padLeft(2, '0')} $unit';
  }

  // The practice timer.
  String get practiceTitle => _en ? 'Practice' : 'Laku';
  String get practiceReady => _en
      ? 'Choose what it is, then start. When you stop, it is written into '
            'the journal with how long it went on.'
      : 'Pilih jenisnya, lalu mulai. Saat berhenti, ia dicatat di jurnal '
            'beserta lamanya.';
  String practiceSince(String time) => _en ? 'Since $time' : 'Sejak $time';
  String practiceUntil(String time) => _en ? 'until $time' : 'sampai $time';
  String get practiceDiscarded => _en
      ? 'Discarded. Nothing was written.'
      : 'Dibuang. Tidak ada yang dicatat.';
  // What a practice writes into its entry.
  String get practiceStart => _en ? 'Start' : 'Mulai';
  String get practiceEnd => _en ? 'End' : 'Selesai';
  String get practiceLog => _en ? 'Log' : 'Catatan';
  String get practiceCounted => _en ? 'Counted' : 'Hitungan';
  String get practiceTime => _en ? 'Time' : 'Waktu';
  String get practiceStopwatch => 'Stopwatch';
  String get practiceCountdown => 'Timer';
  String get practiceStopwatchChosen => _en
      ? 'The stopwatch is chosen. Press start to begin counting.'
      : 'Stopwatch terpilih. Tekan mulai untuk mulai menghitung.';
  String get practiceCountdownChosen => _en
      ? 'The timer is chosen. Set how long above, then press start; it '
            'ends by itself.'
      : 'Timer terpilih. Atur lamanya di atas, lalu tekan mulai; ia '
            'berakhir sendiri.';
  String get practiceTallyChosen => _en
      ? 'The tally is chosen. Touch it to count, and write the count to '
            'the journal here.'
      : 'Penghitung terpilih. Sentuh untuk menghitung, lalu tulis '
            'hitungannya ke jurnal di sini.';
  String get practiceRunning =>
      _en ? 'Press stop when it is done.' : 'Tekan berhenti bila selesai.';
  String get practiceCountingDown => _en
      ? 'It ends by itself; press stop to end it sooner.'
      : 'Ia berakhir sendiri; tekan berhenti untuk mengakhirinya lebih awal.';
  String get practiceAsk => _en
      ? 'Write it into the journal, or discard it?'
      : 'Tulis ke jurnal, atau buang?';
  String get practiceWrite => _en ? 'Write' : 'Tulis';
  String get practiceUnder =>
      _en ? 'Under which category?' : 'Di kategori mana?';
  String get practiceDiscard => _en ? 'Discard' : 'Buang';
  String get practiceTally => _en ? 'Tally' : 'Penghitung';
  String get practiceComplete => _en ? 'Practice complete' : 'Laku selesai';
  String get practiceCountdownNote => _en
      ? 'Set how long. It ends by itself and is written into the journal.'
      : 'Atur lamanya. Ia berakhir sendiri dan dicatat di jurnal.';

  /// "12 h 18 m".
  String hoursMinutes(int minutes) => _en
      ? '${minutes ~/ 60} h ${minutes % 60} m'
      : '${minutes ~/ 60} j ${minutes % 60} m';

  /// "today", "tomorrow", "in 14 days".
  String inDays(int days) => switch (days) {
    0 => _en ? 'today' : 'hari ini',
    1 => _en ? 'tomorrow' : 'besok',
    _ => _en ? 'in $days days' : '$days hari lagi',
  };

  /// How far a day is from today, as a heading: "Today", "In 14 days",
  /// "14 days ago".
  String dayFromToday(int days) => switch (days) {
    0 => _en ? 'Today' : 'Hari ini',
    1 => _en ? 'Tomorrow' : 'Besok',
    -1 => _en ? 'Yesterday' : 'Kemarin',
    > 0 => _en ? 'In $days days' : '$days hari lagi',
    _ => _en ? '${-days} days ago' : '${-days} hari lalu',
  };

  // The rows of the day view's lower panel.
  String get agendaLeft => _en ? 'Left' : 'Sisa';
  String get agendaWeek => _en ? 'Week' : 'Minggu';

  /// "Day 283 of 365".
  String dayOfYear(int day, int days) =>
      _en ? 'Day $day of $days' : 'Hari ke-$day dari $days';
  String daysLeft(int days) =>
      _en ? '$days days in the year' : '$days hari dalam tahun ini';
  String weekOfYear(int week, int year) =>
      _en ? '$week of $year' : 'ke-$week tahun $year';
  String moreReminders(int more) => _en ? '+$more more' : '+$more lagi';

  /// Asks for a place, where the rise and set times need one.
  String get skyNeedsPlace => _en
      ? 'Rise and set times depend on where you are. Tap to use this '
            "phone's position, rounded to about 11 km."
      : 'Waktu terbit dan terbenam bergantung pada lokasi Anda. Ketuk untuk '
            'memakai posisi ponsel ini, dibulatkan hingga sekitar 11 km.';

  /// Says which place the times are for.
  String skyPlace(String coordinates) => _en
      ? 'Times are for $coordinates, a position rounded to about 11 km. '
            'Tap to set it again from where you are now.'
      : 'Waktu dihitung untuk $coordinates, posisi yang dibulatkan hingga '
            'sekitar 11 km. Ketuk untuk mengatur ulang dari posisi Anda '
            'sekarang.';
  String get skyFinding =>
      _en ? 'Finding where you are…' : 'Mencari posisi Anda…';

  // The ephemeris (in code, the sky): where the sun and the moon stand,
  // through a day, a month and a year.
  String get skyTitle => _en ? 'Ephemeris' : 'Efemeris';
  String get skyAltitude => _en ? 'Altitude' : 'Ketinggian';
  String get skyAzimuth => _en ? 'Azimuth' : 'Azimut';
  String get skyHourAngle => _en ? 'Hour angle' : 'Sudut jam';
  String get skyRightAscension => _en ? 'Right ascension' : 'Asensio rekta';
  String get skyDeclination => _en ? 'Declination' : 'Deklinasi';
  String get skyEclipticLongitude =>
      _en ? 'Ecliptic longitude' : 'Bujur ekliptika';
  String get skyEclipticLatitude =>
      _en ? 'Ecliptic latitude' : 'Lintang ekliptika';
  String get skyDistance => _en ? 'Distance' : 'Jarak';
  String get skyDiameter => _en ? 'Apparent diameter' : 'Diameter tampak';
  String get skyRise => _en ? 'Rises' : 'Terbit';
  String get skyTransit => _en ? 'Culminates' : 'Berkulminasi';
  String get skySet => _en ? 'Sets' : 'Terbenam';
  String get skyCivil => _en ? 'Civil twilight' : 'Senja sipil';
  String get skyNautical => _en ? 'Nautical twilight' : 'Senja nautika';
  String get skyAstronomical =>
      _en ? 'Astronomical twilight' : 'Senja astronomis';
  // The star map.
  String get starsTitle => _en ? 'Star map' : 'Peta bintang';
  String get starsStar => _en ? 'Star' : 'Bintang';
  String get starsTouchOne =>
      _en ? 'Touch a star to read it.' : 'Sentuh bintang untuk membacanya.';
  String get starsMagnitude => _en ? 'Magnitude' : 'Magnitudo';
  String get starsConstellation => _en ? 'Constellation' : 'Rasi';
  String get starsBright => _en ? 'Bright stars' : 'Bintang terang';
  String get starsSearch => _en ? 'Search' : 'Cari';
  String get starsSearchPlaceholder =>
      _en ? 'A star, a constellation, a galaxy' : 'Bintang, rasi, galaksi';
  String get starsSearchHint => _en
      ? 'Type a star\'s name or Greek letter, a constellation, or a galaxy '
            '(by name or as M 31).'
      : 'Ketik nama bintang atau huruf Yunaninya, sebuah rasi, atau galaksi '
            '(namanya, atau seperti M 31).';
  String get starsNoneFound =>
      _en ? 'No star by that name.' : 'Tidak ada bintang bernama itu.';
  String get starsDown => _en ? 'down' : 'terbenam';
  String get starsConstellations => _en ? 'Constellations' : 'Rasi';
  String get starsGalaxies => _en ? 'Galaxies' : 'Galaksi';
  String get starsGalaxy => _en ? 'Galaxy' : 'Galaksi';

  // Reminders reckoned by the sun.
  String sunAnchorName(SunAnchor anchor) => switch (anchor) {
    SunAnchor.clock => _en ? 'Clock' : 'Jam',
    SunAnchor.morningBlue => _en ? 'Morning blue' : 'Biru pagi',
    SunAnchor.sunrise => _en ? 'Sunrise' : 'Terbit',
    SunAnchor.eveningGolden => _en ? 'Evening golden' : 'Emas sore',
    SunAnchor.sunset => _en ? 'Sunset' : 'Terbenam',
    SunAnchor.eveningBlue => _en ? 'Evening blue' : 'Biru senja',
    SunAnchor.planetaryHour => _en ? 'Planetary hour' : 'Jam planet',
  };
  String reminderLead(int minutes) => minutes == 0
      ? (_en ? 'At it' : 'Tepat')
      : (_en ? '$minutes min before' : '$minutes menit sebelum');

  /// "Sunset · 20 min before", or the clock time.
  String reminderTimeWords(Reminder reminder) {
    if (!reminder.bySun) return reminder.time;
    final anchor = reminder.sun == SunAnchor.planetaryHour
        ? planetaryHourOf(reminder.planet ?? Body.sun)
        : sunAnchorName(reminder.sun);
    return reminder.lead == 0
        ? anchor
        : '$anchor · ${reminderLead(reminder.lead)}';
  }

  /// "Hour of Venus".
  String planetaryHourOf(Body planet) => _en
      ? 'Hour of ${planet == Body.sun || planet == Body.moon ? 'the ' : ''}'
            '${planetName(planet)}'
      : 'Jam ${planetName(planet)}';
  String get reminderPlanetaryHow => _en
      ? 'The planet\'s first hour of the day, from sunrise at the place set.'
      : 'Jam pertama planet itu dalam sehari, sejak matahari terbit di tempat '
            'yang ditetapkan.';
  String reminderSunOn(String clock) =>
      _en ? 'On the first day, $clock' : 'Pada hari pertama, $clock';
  String get reminderSunNeedsPlace => _en
      ? 'The sun\'s times need a place. Set one in the Place tab of the '
            'prayer times, the ephemeris or Light.'
      : 'Waktu matahari perlu tempat. Tetapkan di tab Tempat pada waktu '
            'salat, efemeris, atau Cahaya.';
  String get reminderSunNone => _en
      ? 'The sun does not do that at this place on the first day.'
      : 'Matahari tidak begitu di tempat ini pada hari pertama.';

  // Light: planning photographs by the sun and the moon.
  String get lightTitle => _en ? 'Light' : 'Cahaya';
  String get lightHours => _en ? 'Hours' : 'Jam';
  String get lightShadow => _en ? 'Shadow' : 'Bayangan';
  String get lightMoon => _en ? 'Moon' : 'Bulan';
  String get lightMilkyWay => _en ? 'Milky Way' : 'Bimasakti';
  String get lightAlign => _en ? 'Line up' : 'Sejajarkan';
  String get lightNow => _en ? 'The light now' : 'Cahaya sekarang';
  String lightBand(LightBand band) => switch (band) {
    LightBand.day => _en ? 'Day' : 'Siang',
    LightBand.golden => _en ? 'Golden hour' : 'Jam emas',
    LightBand.blue => _en ? 'Blue hour' : 'Jam biru',
    LightBand.night => _en ? 'Night' : 'Malam',
  };
  String get lightMorningBlue => _en ? 'Morning blue' : 'Biru pagi';
  String get lightMorningGolden => _en ? 'Morning golden' : 'Emas pagi';
  String get lightEveningGolden => _en ? 'Evening golden' : 'Emas sore';
  String get lightEveningBlue => _en ? 'Evening blue' : 'Biru senja';
  String get lightHoursHow => _en
      ? 'Golden while the sun\'s centre is between 6° above the horizon and '
            '4° below it, blue from 4° to 6° below, the photographers\' '
            'convention. Whether the light is good on the day is the '
            'weather\'s, which the app does not know.'
      : 'Emas selama pusat matahari di antara 6° di atas ufuk dan 4° di '
            'bawahnya, biru dari 4° sampai 6° di bawah, menurut kebiasaan '
            'para fotografer. Bagus tidaknya cahaya hari itu urusan cuaca, '
            'yang tidak diketahui aplikasi ini.';
  String get lightSunHeight => _en ? 'The sun' : 'Matahari';
  String get lightSunDown => _en ? 'the sun is down' : 'matahari terbenam';
  String get lightSunTooHigh =>
      _en ? 'the sun is too high' : 'matahari terlalu tinggi';
  String get lightShadowLength => _en ? 'Shadow length' : 'Panjang bayangan';
  String get lightShadowFalls => _en ? 'Falls toward' : 'Jatuh ke arah';
  String lightTimesHeight(double times) => _en
      ? '${times.toStringAsFixed(times < 10 ? 2 : 1)} × the height'
      : '${times.toStringAsFixed(times < 10 ? 2 : 1)} × tingginya';
  String get lightVeryLong => _en ? 'very long' : 'sangat panjang';
  String get lightRainbow => _en ? 'Rainbow' : 'Pelangi';
  String lightRainbowAt(String top, String bearing) => _en
      ? 'top $top° high, toward $bearing'
      : 'puncak $top°, ke arah $bearing';
  String get lightSecondBow => _en ? 'Second bow' : 'Pelangi kedua';
  String get lightShadowHow => _en
      ? 'For anything standing upright on level ground. On the plan the '
            'inner ring is the thing\'s own height. A rainbow needs the sun '
            'on you and rain opposite it; it is a circle 42° about the point '
            'opposite the sun, so it shows only while the sun is under 42°.'
      : 'Untuk benda tegak di tanah datar. Di denah, lingkaran terdalam '
            'adalah tinggi benda itu sendiri. Pelangi perlu matahari di '
            'belakang Anda dan hujan di depan; ia lingkaran 42° di sekitar '
            'titik di seberang matahari, jadi hanya tampak selama matahari '
            'di bawah 42°.';
  String get lightFullMoons => _en ? 'Coming full moons' : 'Purnama mendatang';
  String get lightNearest => _en ? 'nearest' : 'terdekat';
  String get lightFarthest => _en ? 'farthest' : 'terjauh';
  String get lightLooney => _en
      ? 'To start the exposure on the lit moon, the Looney 11 rule: f/11, '
            'with the shutter one over the ISO (ISO 100, 1/100 s). A starting '
            'point, after NASA\'s guide; take a range around it. The nearer '
            'the full moon, the larger it looks.'
      : 'Untuk mulai memotret bulan yang terang, aturan Looney 11 berlaku '
            'begini. Diafragma f/11, rana satu per ISO (ISO 100, 1/100 detik). '
            'Ini titik awal, mengikuti panduan NASA; ambil beberapa variasi '
            'di sekitarnya. Makin dekat purnama, makin besar tampaknya.';
  String get lightCoreNow => _en ? 'Its heart now' : 'Intinya sekarang';
  String get lightTonight => _en ? 'Tonight' : 'Malam ini';
  String get lightDarkMoonless => _en ? 'Dark, no moon' : 'Gelap, tanpa bulan';
  String get lightDarkMoonUp => _en ? 'Dark, moon up' : 'Gelap, bulan terbit';
  String get lightNone => _en ? 'none' : 'tidak ada';
  String get lightMilkyWayHow => _en
      ? 'The night from this evening: when the Milky Way\'s heart, toward '
            'the galaxy\'s centre in Sagittarius, stands 10° or more (north of '
            'about 51°, where it never climbs so high, within 3° of its '
            'highest) and the sky is fully dark (the sun 18° down), to five minutes. City '
            'light and haze are not known here.'
      : 'Malam mulai petang ini, saat inti Bimasakti, arah pusat galaksi di '
            'Sagitarius, setinggi 10° atau lebih (di utara sekitar 51°, yang '
            'tak pernah setinggi itu, dalam 3° dari puncaknya) dan langit '
            'gelap penuh '
            '(matahari 18° di bawah ufuk), dalam lima menit. Cahaya kota dan '
            'kabut tidak diketahui di sini.';
  String get lightBearing => _en ? 'Bearing' : 'Arah';
  String get lightNight => _en ? 'Night' : 'Malam';
  String lightFacing(String bearing, String declination) => _en
      ? 'Facing $bearing, true north ($declination from the needle)'
      : 'Menghadap $bearing, utara sejati ($declination dari jarum)';
  String get lightCompassRough => _en
      ? 'The compass is unsure: wave the phone in a figure of eight, away '
            'from metal.'
      : 'Kompas belum yakin: gerakkan ponsel membentuk angka delapan, jauh '
            'dari logam.';
  String get lightCompassNone =>
      _en ? 'This phone has no compass.' : 'Ponsel ini tidak punya kompas.';
  String skyStampSun(int height, String point) =>
      _en ? 'sun $height° $point' : 'matahari $height° $point';
  String get lightMeteors => _en ? 'Meteors' : 'Meteor';
  String get lightEclipses => _en ? 'Eclipses' : 'Gerhana';
  String get lightHalo => _en ? '22° halo' : 'Halo 22°';
  String lightHaloAt(String low, String high) => _en
      ? 'a ring 22° round the sun, from $low° to $high° high'
      : 'cincin 22° di sekitar matahari, dari $low° sampai $high°';
  String get lightSundogs => _en ? 'Sundogs' : 'Matahari semu';
  String lightSundogsAt(String left, String right) => _en
      ? 'at the sun\'s height, near $left and $right'
      : 'setinggi matahari, dekat $left dan $right';
  String lightPoleAt({required bool south, required String height}) => _en
      ? 'The sky turns about the ${south ? 'south' : 'north'} celestial '
            'pole, $height° above the ${south ? 'southern' : 'northern'} '
            'horizon: stars near it draw the shortest trails.'
      : 'Langit berputar mengelilingi kutub langit '
            '${south ? 'selatan' : 'utara'}, $height° di atas ufuk '
            '${south ? 'selatan' : 'utara'}: bintang di dekatnya membuat '
            'jejak terpendek.';
  String get lightFocal => _en ? 'Focal length' : 'Panjang fokus';
  String get lightAperture => _en ? 'Aperture' : 'Diafragma';
  String get lightPitch => _en ? 'Pixel pitch' : 'Jarak piksel';
  String get lightSensor => _en ? 'Sensor' : 'Sensor';
  String lightCrop(double crop) => crop == 1.0
      ? (_en ? 'Full frame' : 'Full frame')
      : crop == 2.0
      ? 'Micro 4/3'
      : 'APS-C ×$crop';
  String get lightNpf => _en ? 'NPF rule' : 'Aturan NPF';
  String get lightFiveHundred => _en ? '500 rule' : 'Aturan 500';
  String lightSeconds(double s) => _en
      ? '${s.toStringAsFixed(s < 10 ? 1 : 0)} s'
      : '${s.toStringAsFixed(s < 10 ? 1 : 0).replaceAll('.', ',')} detik';
  String get lightNightHow => _en
      ? 'The longest exposure before the stars smear. The NPF rule '
            '(Frédéric Michaud, Société Astronomique du Havre) weighs the '
            'aperture and the pixels: (35 × f-number + 30 × pixel pitch) ÷ '
            'focal length. The older 500 rule is 500 ÷ (focal length × crop) '
            'and allows more than sharp pixels bear. The focal length is '
            'the lens\'s own.'
      : 'Pencahayaan terlama sebelum bintang tampak memanjang. Aturan NPF '
            '(Frédéric Michaud, Société Astronomique du Havre) memperhitungkan '
            'diafragma dan piksel: (35 × angka-f + 30 × jarak piksel) ÷ '
            'panjang fokus. Aturan 500 yang lebih lama, 500 ÷ (panjang fokus '
            '× faktor crop), membolehkan lebih dari yang sanggup ditanggung '
            'piksel yang tajam. Panjang fokus adalah milik lensanya sendiri.';
  String lightZhr(int zhr) => zhr == 0
      ? (_en ? 'rate varies' : 'laju berubah-ubah')
      : (_en ? 'up to $zhr an hour' : 'hingga $zhr per jam');
  String get lightRadiantDown =>
      _en ? 'radiant down in the dark' : 'radian tak terbit saat gelap';
  String lightRadiantAt(String height, String time) => _en
      ? 'radiant highest $height° at $time'
      : 'radian tertinggi $height° pukul $time';
  String lightMoonLit(int percent) =>
      _en ? 'moon $percent% lit' : 'bulan $percent% terang';
  String get lightActiveNow => _en ? 'active now' : 'sedang aktif';
  String lightRemindMeteors(String name) =>
      _en ? '$name at their best' : '$name di puncaknya';
  String get lightMeteorsHow => _en
      ? 'The IMO\'s working list of visual showers, each peak worked out '
            'for the year from the sun\'s longitude. The rate is for a '
            'perfect dark sky with the radiant overhead; fewer are seen.'
      : 'Daftar kerja hujan meteor visual IMO, tiap puncaknya dihitung untuk '
            'tahun ini dari bujur matahari. Lajunya untuk langit gelap '
            'sempurna dengan radian di atas kepala; yang terlihat lebih sedikit.';
  String lightEclipseKind(EclipseKind kind, {required bool solar}) =>
      switch ((kind, solar, _en)) {
        (EclipseKind.total, true, true) => 'Total solar eclipse',
        (EclipseKind.annular, true, true) => 'Annular solar eclipse',
        (_, true, true) => 'Partial solar eclipse',
        (EclipseKind.total, false, true) => 'Total lunar eclipse',
        (EclipseKind.partial, false, true) => 'Partial lunar eclipse',
        (_, false, true) => 'Penumbral lunar eclipse',
        (EclipseKind.total, true, false) => 'Gerhana matahari total',
        (EclipseKind.annular, true, false) => 'Gerhana matahari cincin',
        (_, true, false) => 'Gerhana matahari sebagian',
        (EclipseKind.total, false, false) => 'Gerhana bulan total',
        (EclipseKind.partial, false, false) => 'Gerhana bulan sebagian',
        (_, false, false) => 'Gerhana bulan penumbra',
      };
  String lightEclipseCentral(EclipseKind kind, String span) =>
      kind == EclipseKind.annular
      ? (_en ? 'the ring $span' : 'cincin $span')
      : (_en ? 'totality $span' : 'total $span');

  /// [height] in whole degrees; below the horizon it reads as down.
  String lightEclipseGreatest(
    String time,
    String amount,
    int height, {
    required bool solar,
  }) => _en
      ? 'greatest at $time, $amount, the ${solar ? 'sun' : 'moon'} '
            '${height.abs()}° ${height < 0 ? 'down' : 'up'}'
      : 'puncak pukul $time, $amount, ${solar ? 'matahari' : 'bulan'} '
            '${height < 0 ? '${-height}° di bawah ufuk' : 'setinggi $height°'}';
  String lightEclipseCovered(int percent) => _en
      ? '$percent% of the sun\'s width covered'
      : '$percent% lebar matahari tertutup';
  String lightEclipseUmbral(double magnitude) => _en
      ? 'umbral magnitude ${magnitude.toStringAsFixed(2)}'
      : 'magnitudo umbra ${magnitude.toStringAsFixed(2).replaceAll('.', ',')}';
  String get lightNoEclipses => _en
      ? 'None to be seen from here in the coming ten years.'
      : 'Tidak ada yang terlihat dari sini dalam sepuluh tahun ke depan.';
  String get lightPairs => _en ? 'Pairs' : 'Berdekatan';
  String lightPair(String a, String b) => _en ? '$a and $b' : '$a dan $b';
  String lightPairNearest(String degrees, String time) => _en
      ? 'nearest $degrees° apart at $time'
      : 'paling dekat $degrees° pukul $time';
  String lightPairSeen(
    String time,
    int height,
    String degrees, {
    String? day,
  }) => _en
      ? 'best seen here${day == null ? '' : ' on $day'} at $time, '
            '$height° up, $degrees° apart'
      : 'paling baik terlihat di sini${day == null ? '' : ' tanggal $day'} '
            'pukul $time, $height° di atas ufuk, berjarak $degrees°';
  String get lightPairNotSeen => _en
      ? 'not seen here: one or both down, or the sky not dark'
      : 'tidak terlihat di sini: salah satu atau keduanya di bawah ufuk, '
            'atau langit belum gelap';
  String get lightNoPairs => _en
      ? 'No close pairs in the coming year.'
      : 'Tidak ada pasangan berdekatan dalam setahun ke depan.';
  String get lightPairsHow => _en
      ? 'The moon within 3° of a planet, and two planets within 2° of each '
            'other, over the coming year: the five the eye sees. Nearest is '
            'from the Earth\'s centre; best seen is from here, with the sun '
            '6° down and both at least 5° up. The moon\'s own nearness shifts '
            'a little with the place.'
      : 'Bulan dalam 3° dari sebuah planet, dan dua planet dalam 2° satu '
            'sama lain, selama setahun ke depan: lima planet yang terlihat '
            'mata. Paling dekat dihitung dari pusat bumi; paling baik terlihat '
            'dari sini, saat matahari 6° di bawah ufuk dan keduanya paling '
            'sedikit 5° di atasnya. Jarak bulan sedikit bergeser menurut '
            'tempat.';
  String get lightEclipsesHow => _en
      ? 'Worked out for this place from the sun and moon themselves, and '
            'checked against NASA\'s catalogue: the coming ten years, those '
            'with the sun or the moon up for some of it. Never look at the '
            'sun without a proper filter, except in totality.'
      : 'Dihitung untuk tempat ini dari matahari dan bulan sendiri, dan '
            'diperiksa terhadap katalog NASA: sepuluh tahun ke depan, yang '
            'matahari atau bulannya terbit untuk sebagian waktunya. Jangan '
            'memandang matahari tanpa filter yang layak, kecuali saat total.';
  String lightRemindSun(SunAnchor anchor) => switch (anchor) {
    SunAnchor.clock => '',
    SunAnchor.morningBlue => _en ? 'Morning blue hour' : 'Jam biru pagi',
    SunAnchor.sunrise => _en ? 'Sunrise' : 'Matahari terbit',
    SunAnchor.eveningGolden => _en ? 'Evening golden hour' : 'Jam emas sore',
    SunAnchor.sunset => _en ? 'Sunset' : 'Matahari terbenam',
    SunAnchor.eveningBlue => _en ? 'Evening blue hour' : 'Jam biru senja',
    SunAnchor.planetaryHour => '',
  };
  String get lightRemindFullMoon =>
      _en ? 'The full moon rises' : 'Purnama terbit';
  String lightRemindMilkyWay({required bool moon}) => moon
      ? (_en
            ? 'The Milky Way, dark, moon up'
            : 'Bimasakti, gelap, bulan terbit')
      : (_en
            ? 'The Milky Way, dark and moonless'
            : 'Bimasakti, gelap tanpa bulan');
  String lightRemindAlign(SunAnchor anchor, String along) =>
      anchor == SunAnchor.sunrise
      ? (_en ? 'The sun rises along $along' : 'Matahari terbit di arah $along')
      : (_en
            ? 'The sun sets along $along'
            : 'Matahari terbenam di arah $along');
  String lightRemindAlignMoon(String along, {required bool rising}) => rising
      ? (_en ? 'The moon rises along $along' : 'Bulan terbit di arah $along')
      : (_en ? 'The moon sets along $along' : 'Bulan terbenam di arah $along');
  String get lightSunRises => _en ? 'Sun rises along it' : 'Matahari terbit';
  String get lightSunSets => _en ? 'Sun sets along it' : 'Matahari terbenam';
  String get lightMoonRises => _en ? 'Moon rises along it' : 'Bulan terbit';
  String get lightMoonSets => _en ? 'Moon sets along it' : 'Bulan terbenam';
  String get lightNotThisYear =>
      _en ? 'not in the coming year' : 'tidak dalam setahun ke depan';
  String get lightAlignHow => _en
      ? 'Touch or draw across the plan to set the bearing toward a landmark. '
            'Listed are the days over the coming year it rises or sets within '
            '1° of it, over a level horizon; behind hills or buildings it '
            'shows later and further along.'
      : 'Sentuh atau geser di denah untuk menetapkan arah ke suatu tengara. '
            'Yang tercantum adalah hari dalam setahun ke depan saat ia terbit '
            'atau terbenam dalam 1° dari arah itu, di atas ufuk yang datar; '
            'di balik bukit atau gedung ia muncul lebih lambat dan bergeser.';

  // Lintang Jawa: the Javanese sky.
  String get lintangTitle => 'Lintang Jawa';
  String get lintangFigures => _en ? 'Lintang' : 'Lintang';
  String get lintangMangsa => _en ? 'Mangsa' : 'Mangsa';
  String get lintangUp => _en ? 'up' : 'terbit';
  String get lintangNotDrawn => _en ? 'not drawn' : 'tidak digambar';
  String lintangAlsoCalled(String names, {bool popular = false}) => _en
      ? 'Also called $names${popular ? ', in popular writing' : ''}'
      : 'Disebut juga $names${popular ? ', dalam tulisan populer' : ''}';
  String get lintangSources => _en
      ? 'The figures and their stars follow Daldjoeni and Hidayat (1987), '
            'Maass (1924) with the Javanese he quotes, Gericke and Roorda\'s '
            'dictionary (1901) and Handayani and others (2023). Waluku opening '
            'Kasa, and Waluku and Wuluh read for the mangsa, are in those '
            'sources; the other figures are tied to no mangsa in them.'
      : 'Rasi dan bintangnya mengikuti Daldjoeni dan Hidayat (1987), Maass '
            '(1924) beserta narasumber Jawa yang dikutipnya, kamus Gericke dan '
            'Roorda (1901), serta Handayani dan kawan-kawan (2023). Waluku '
            'membuka Kasa, serta Waluku dan Wuluh dibaca untuk mangsa, ada '
            'dalam sumber itu; rasi lainnya tidak dikaitkan dengan mangsa mana '
            'pun.';
  String get lintangWorking => _en ? 'Working it out…' : 'Sedang dihitung…';
  String get lintangRises =>
      _en ? 'Waluku first before dawn' : 'Waluku pertama sebelum fajar';
  String get lintangSets =>
      _en ? 'Waluku sets at dawn' : 'Waluku terbenam saat subuh';
  String get lintangKasaOpens => _en ? 'Kasa opens' : 'Kasa dimulai';
  String get lintangKapituOpens => _en ? 'Kapitu opens' : 'Kapitu dimulai';
  String lintangDaysApart(int days) => days == 0
      ? (_en ? 'the same day' : 'hari yang sama')
      : _en
      ? '${days.abs()} ${days.abs() == 1 ? 'day' : 'days'} ${days > 0 ? 'after' : 'before'}'
      : '${days.abs()} hari ${days > 0 ? 'sesudahnya' : 'sebelumnya'}';
  String get lintangHow => _en
      ? 'Reckoned for this place and year: Waluku counts as risen when its '
            'middle Belt star stands 5° above the eastern horizon with the sun '
            '12° below it, and as set when it has sunk to 5° in the west by '
            'then. Other reckonings of first sight move these by some days.'
      : 'Dihitung untuk tempat dan tahun ini: Waluku dihitung terbit bila '
            'bintang tengah sabuknya setinggi 5° di ufuk timur saat matahari '
            '12° di bawah ufuk, dan terbenam bila sudah turun ke 5° di barat '
            'pada saat itu. Cara lain menghitung penampakan pertama menggeser '
            'tanggal ini beberapa hari.';
  String get skyEquationOfTime => _en ? 'Equation of time' : 'Perata waktu';
  String get skyPhase => _en ? 'Phase' : 'Fase';
  String get skyElongation => _en ? 'Elongation' : 'Elongasi';
  String get skyNow => _en ? 'Now' : 'Sekarang';
  String get skyTime => _en ? 'Time' : 'Waktu';
  String get skyDate => _en ? 'Date' : 'Tanggal';

  /// The words of a text field's own toolbar.
  SmTextToolbarLabels get textToolbar => SmTextToolbarLabels(
    cut: cut,
    copy: copy,
    paste: paste,
    selectAll: selectAll,
  );

  String get keep => _en ? 'Keep' : 'Simpan';

  // Tags.
  String get tagsNote => _en
      ? 'Tags are used only in the search. Touch one to put it on or take it off.'
      : 'Tag hanya dipakai dalam pencarian. Sentuh untuk memasang atau melepasnya.';
  String get tagNew => _en ? 'New tag' : 'Tag baru';
  String deleteTagQuestion(String name, int entries, int reminders) => _en
      ? 'Delete the tag "$name"? It comes off $entries '
            '${entries == 1 ? 'entry' : 'entries'} and $reminders '
            '${reminders == 1 ? 'reminder' : 'reminders'}.'
      : 'Hapus tag "$name"? Tag ini dilepas dari $entries catatan dan '
            '$reminders pengingat.';

  // The search.
  String get searchTitle => _en ? 'Search' : 'Cari';
  String searchFound(int count) => _en ? '$count found' : '$count ditemukan';
  String get searchNothing =>
      _en ? 'Nothing found.' : 'Tidak ada yang ditemukan.';
  String get searchLookIn => _en ? 'Look in' : 'Cari di';
  String get searchCategory => _en ? 'Category' : 'Kategori';
  String get searchTags => _en ? 'Tags' : 'Tag';
  String get searchDay => _en ? 'Day' : 'Hari';
  String get searchEvening => _en ? 'Evening' : 'Malam';
  String get searchWords => _en ? 'Words' : 'Kata';
  String get searchWhen => _en ? 'When' : 'Kapan';
  String searchWhenName({required bool byMoment}) => byMoment
      ? (_en ? 'When written' : 'Saat ditulis')
      : (_en ? 'Its day' : 'Harinya');
  String searchWhenNote({required bool byMoment}) => byMoment
      ? (_en
            ? 'The cycles are asked of the moment each was first saved, as its '
                  'hidden record keeps it: an entry about last week written '
                  'today counts as today. Entries and reminders from before '
                  'records were kept are not found this way.'
            : 'Siklus ditanyakan pada saat masing-masing pertama disimpan, '
                  'seperti tercatat dalam rekamannya yang tersembunyi: catatan '
                  'tentang minggu lalu yang ditulis hari ini terhitung hari ini. '
                  'Catatan dan pengingat dari sebelum rekaman disimpan tidak '
                  'ditemukan dengan cara ini.')
      : (_en
            ? 'The cycles are asked of the day each is about: an entry\'s own '
                  'date and time, a reminder\'s days.'
            : 'Siklus ditanyakan pada hari yang dimaksud masing-masing: tanggal '
                  'dan jam catatan itu sendiri, hari-hari pengingat.');
  String get searchEntries => _en ? 'Entries' : 'Catatan';
  String get searchReminders => _en ? 'Reminders' : 'Pengingat';
  String get searchBoth => _en ? 'Both' : 'Keduanya';
  String get searchCategoryNote => _en
      ? 'Any of the categories chosen. None chosen is every category.'
      : 'Salah satu kategori terpilih. Tanpa pilihan berarti semua kategori.';
  String get searchTagsNote => _en
      ? 'Only what has every tag chosen.'
      : 'Hanya yang memiliki semua tag terpilih.';
  String get searchNoTags => _en
      ? 'No tags yet. Tags are given to an entry or a reminder with the tag '
            'button beside its centre button.'
      : 'Belum ada tag. Tag dipasang pada catatan atau pengingat lewat tombol '
            'tag di samping tombol tengahnya.';
  String get searchDayHint =>
      _en ? 'Choose a cycle, then +.' : 'Pilih siklus, lalu +.';
  String get searchAnyDay => _en ? 'Any day' : 'Hari apa saja';
  String get searchWordsPlaceholder =>
      _en ? 'Words to find' : 'Kata yang dicari';
  String get searchWordsNote => _en
      ? 'Every word, in the title or the text.'
      : 'Semua kata, di judul atau isinya.';
  String searchNextOn(String date) =>
      _en ? 'next fitting: $date' : 'berikutnya yang cocok: $date';

  String cycleName(CycleKind kind) => switch (kind) {
    CycleKind.weekday => _en ? 'Weekday' : 'Hari',
    CycleKind.pasaran => 'Pasaran',
    CycleKind.weton => 'Weton',
    CycleKind.moon => _en ? 'Moon phase' : 'Fase bulan',
    CycleKind.javaneseMonth => _en ? 'Javanese month' : 'Bulan Jawa',
    CycleKind.javaneseDay => _en ? 'Javanese day' : 'Tanggal Jawa',
    CycleKind.hijriMonth => _en ? 'Hijri month' : 'Bulan Hijriah',
    CycleKind.hijriDay => _en ? 'Hijri day' : 'Tanggal Hijriah',
    CycleKind.chineseMonth => _en ? 'Chinese month' : 'Bulan Imlek',
    CycleKind.chineseDay => _en ? 'Chinese day' : 'Tanggal Imlek',
    CycleKind.mangsa => 'Mangsa',
    CycleKind.dayElement => _en ? 'Day element' : 'Unsur hari',
    CycleKind.planetaryHour => _en ? 'Planetary hour' : 'Jam planet',
  };

  /// A cycle's value with what cycle it is, where the value alone could
  /// be read two ways ("Hijri day 14").
  String cycleValue(CycleKind kind, int value) => switch (kind) {
    CycleKind.javaneseDay ||
    CycleKind.hijriDay ||
    CycleKind.chineseDay => '${cycleName(kind)} ${kind.label(value, this)}',
    CycleKind.planetaryHour => planetaryHourOf(CycleKind.planets[value]),
    _ => kind.label(value, this),
  };

  String eveningName(Evening evening) => switch (evening) {
    Evening.midnight => _en ? 'Midnight' : 'Tengah malam',
    Evening.sunset => _en ? 'Sunset' : 'Matahari terbenam',
    Evening.six => '18:00',
  };

  String eveningNote(Evening evening) => switch (evening) {
    Evening.midnight =>
      _en ? 'A day runs from midnight to midnight, as the calendar has it.' : 'Hari berjalan dari tengah malam ke tengah malam, seperti di kalender.',
    Evening.sunset =>
      _en
          ? 'From sunset, what was written or set counts as the next day: '
                'Thursday evening is already malam Jumat. Sunset is worked '
                'out for the place set in the ephemeris.'
          : 'Sejak matahari terbenam, yang ditulis atau diatur terhitung hari '
                'berikutnya: Kamis malam sudah malam Jumat. Waktu terbenam '
                'dihitung untuk tempat yang diatur di efemeris.',
    Evening.six =>
      _en
          ? 'From 18:00 it counts as the next day: sunset\'s usual hour in Java.'
          : 'Sejak pukul 18:00 terhitung hari berikutnya: jam terbenam yang '
                'lazim di Jawa.',
  };
  String get eveningNeedsPlace => _en
      ? 'Sunset needs a place: set one in the ephemeris or the prayer times.'
      : 'Matahari terbenam butuh tempat: atur di efemeris atau waktu salat.';
  String get skyPlaceTab => _en ? 'Place' : 'Tempat';

  // Finding a place by name or on the map.
  String placeNear(String name) => _en ? 'near $name' : 'dekat $name';
  String get placeSearchPlaceholder =>
      _en ? 'A town, a kecamatan, a city' : 'Kota, kecamatan, kabupaten';
  String get placeNearPin => _en ? 'Near the pin' : 'Dekat penanda';
  String get placeFound => _en ? 'Found' : 'Ditemukan';
  String get placeNoneFound =>
      _en ? 'No place by that name.' : 'Tidak ada tempat bernama itu.';
  String get placeMapHint => _en
      ? 'Touch the map to put the place there (in Indonesia, the kecamatan '
            'it falls in), or find one by name below. Two fingers move and '
            'zoom the map.'
      : 'Sentuh peta untuk menaruh tempat di sana (di Indonesia, kecamatan '
            'tempat sentuhan itu), atau cari namanya di bawah. Dua jari '
            'menggeser dan memperbesar peta.';
  String get placeFind =>
      _en ? 'Find by name or on the map' : 'Cari lewat nama atau peta';
  String get skyLatitude => _en ? 'Latitude' : 'Lintang';
  String get skyLongitude => _en ? 'Longitude' : 'Bujur';
  String get skyNoPlace => _en ? 'No place yet' : 'Belum ada tempat';
  String get skyBelow => _en ? 'below the horizon' : 'di bawah ufuk';

  /// The place panel's note.
  String get skyPlaceNote => _en
      ? 'Set with the steps, or from this phone with the pin. Rounded to a '
            'tenth of a degree, about 11 km, and kept only on this phone. '
            'The calendar\'s sky and the prayer times use the same place.'
      : 'Atur dengan tombol langkah, atau dari ponsel ini dengan pin. '
            'Dibulatkan ke sepersepuluh derajat, sekitar 11 km, dan hanya '
            'disimpan di ponsel ini. Langit di kalender dan waktu salat '
            'memakai tempat yang sama.';
  String get skyAskPlace => _en
      ? 'Where the sun and the moon stand depends on where you are. Set a '
            'place below.'
      : 'Letak matahari dan bulan bergantung pada tempat Anda. Tetapkan '
            'tempat di bawah.';

  /// The eight points of the compass, from north.
  String compassPoint(int point) => (_en
      ? const ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
      : const ['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL'])[point % 8];

  /// The four on the dome's rim.
  List<String> get compassFour =>
      _en ? const ['N', 'E', 'S', 'W'] : const ['U', 'T', 'S', 'B'];

  /// "+3 min 12 s": a sundial ahead of the clock, or behind.
  String skyMinutesSeconds(double minutes) {
    final sign = minutes < 0 ? '−' : '+';
    final seconds = (minutes.abs() * 60).round();
    return _en
        ? '$sign${seconds ~/ 60} min ${seconds % 60} s'
        : '$sign${seconds ~/ 60} mnt ${seconds % 60} dtk';
  }

  // Prayer times, under the Hijri system.
  String get salatTitle => _en ? 'Prayer times' : 'Waktu salat';
  String get salatTimes => _en ? 'Times' : 'Waktu';

  /// The times keep their Indonesian names in both languages in
  /// Indonesia; elsewhere, in English, the names used there.
  String salatName(Salat salat, {bool indonesian = true}) => indonesian || !_en
      ? _salatName(salat)
      : switch (salat) {
          Salat.imsak => 'Imsak',
          Salat.subuh => 'Fajr',
          Salat.terbit => 'Sunrise',
          Salat.duha => 'Duha',
          Salat.zuhur => 'Dhuhr',
          Salat.asar => 'Asr',
          Salat.magrib => 'Maghrib',
          Salat.isya => 'Isha',
        };

  String _salatName(Salat salat) => switch (salat) {
    Salat.imsak => 'Imsak',
    Salat.subuh => 'Subuh',
    Salat.terbit => 'Terbit',
    Salat.duha => 'Duha',
    Salat.zuhur => 'Zuhur',
    Salat.asar => 'Asar',
    Salat.magrib => 'Magrib',
    Salat.isya => 'Isya',
  };

  /// What a time is, and how it is reckoned.
  String salatRule(Salat salat) => switch (salat) {
    Salat.imsak =>
      _en
          ? 'Ten minutes before Subuh: where the fast of Ramadan is stopped, '
                'kept back from dawn for safety.'
          : 'Sepuluh menit sebelum Subuh: batas berhenti sahur, dijaga '
                'sebelum fajar untuk kehati-hatian.',
    Salat.subuh =>
      _en
          ? 'Dawn: the sun 20° below the eastern horizon, plus two minutes. '
                'Its time runs until sunrise.'
          : 'Fajar: matahari 20° di bawah ufuk timur, ditambah dua menit. '
                'Waktunya sampai matahari terbit.',
    Salat.terbit =>
      _en
          ? 'Sunrise, less two minutes: the end of the time of Subuh.'
          : 'Matahari terbit, dikurangi dua menit: akhir waktu Subuh.',
    Salat.duha =>
      _en
          ? 'The sun 4.5° up, plus two minutes: the voluntary forenoon '
                'prayer may begin. Its time runs until just before Zuhur.'
          : 'Matahari 4,5° di atas ufuk, ditambah dua menit: salat sunah '
                'duha boleh dimulai. Waktunya sampai menjelang Zuhur.',
    Salat.zuhur =>
      _en
          ? 'Noon: the sun past the meridian, plus three minutes. Its time '
                'runs until Asar.'
          : 'Tengah hari: matahari tergelincir dari meridian, ditambah tiga '
                'menit. Waktunya sampai Asar.',
    Salat.asar =>
      _en
          ? 'Afternoon: a shadow as long as the thing itself beyond its noon '
                'shadow, plus two minutes. Its time runs until Magrib.'
          : 'Sore: bayangan sepanjang bendanya ditambah bayangan saat '
                'Zuhur, ditambah dua menit. Waktunya sampai Magrib.',
    Salat.magrib =>
      _en
          ? 'Sunset, plus two minutes. The Hijri day begins here. Its time '
                'runs until Isya.'
          : 'Matahari terbenam, ditambah dua menit. Hari Hijriah berganti '
                'di sini. Waktunya sampai Isya.',
    Salat.isya =>
      _en
          ? 'Nightfall: the sun 18° below the western horizon, plus two '
                'minutes. Its time runs until Subuh.'
          : 'Malam: matahari 18° di bawah ufuk barat, ditambah dua menit. '
                'Waktunya sampai Subuh.',
  };

  String get salatMethod => _en
      ? 'Reckoned as the Ministry of Religious Affairs reckons its '
            'schedules, and checked against them: within a minute every '
            'day. A mosque\'s own schedule may differ by a minute or two.'
      : 'Dihitung seperti Kementerian Agama menghitung jadwalnya, dan '
            'diperiksa terhadapnya: selisih paling banyak satu menit setiap '
            'hari. Jadwal masjid setempat bisa berbeda satu-dua menit.';
  String get salatMethodTab => _en ? 'Method' : 'Cara hitung';
  String get salatChooseMethod => _en
      ? 'Outside Indonesia, prayer times are reckoned by several '
            'conventions. Choose the one your mosque follows in the panel.'
      : 'Di luar Indonesia, waktu salat dihitung dengan beberapa cara. '
            'Pilih yang diikuti masjid Anda di panel.';
  String get salatMethodsHint => _en
      ? 'Choose the convention your mosque follows. The likeliest for this '
            'place are first.'
      : 'Pilih cara hitung yang diikuti masjid Anda. Yang paling mungkin '
            'untuk tempat ini ada di atas.';
  String salatMethodName(SalatMethod method) => switch (method) {
    SalatMethod.kemenag =>
      _en ? 'Ministry of Religious Affairs, Indonesia' : 'Kementerian Agama',
    SalatMethod.muslimWorldLeague =>
      _en ? 'Muslim World League' : 'Liga Muslim Dunia',
    SalatMethod.moonsightingCommittee => 'Moonsighting Committee',
    SalatMethod.northAmerica =>
      _en ? 'ISNA, North America' : 'ISNA, Amerika Utara',
    SalatMethod.egyptian =>
      _en
          ? 'Egyptian General Authority of Survey'
          : 'Otoritas Survei Umum Mesir',
    SalatMethod.karachi =>
      _en
          ? 'University of Islamic Sciences, Karachi'
          : 'Universitas Ilmu Islam, Karachi',
    SalatMethod.ummAlQura => 'Umm al-Qura, Makkah',
    SalatMethod.dubai => _en ? 'Dubai, UAE' : 'Dubai, UEA',
    SalatMethod.kuwait => 'Kuwait',
    SalatMethod.qatar => 'Qatar',
    SalatMethod.singapore =>
      _en ? 'MUIS Singapore, JAKIM Malaysia' : 'MUIS Singapura, JAKIM Malaysia',
    SalatMethod.turkey => _en ? 'Diyanet, Turkey' : 'Diyanet, Turki',
    SalatMethod.tehran =>
      _en ? 'Institute of Geophysics, Tehran' : 'Institut Geofisika, Teheran',
  };

  /// "Fajr 18° · Isha 17°", or Isha as minutes after Maghrib.
  String salatMethodAngles(SalatMethod method) {
    String name(Salat s) => salatName(s, indonesian: false);
    String degrees(double d) =>
        '${d.toString().replaceAll(RegExp(r'\.0$'), '')}°';
    final isha = method.ishaInterval > 0
        ? (_en
              ? '${name(Salat.isya)} ${method.ishaInterval} min after '
                    '${name(Salat.magrib)}'
              : '${name(Salat.isya)} ${method.ishaInterval} menit setelah '
                    '${name(Salat.magrib)}')
        : '${name(Salat.isya)} ${degrees(method.ishaAngle)}';
    return '${name(Salat.subuh)} ${degrees(method.fajrAngle)} · $isha';
  }

  String get salatAsrShadow => _en ? 'Asr' : 'Asar';
  String salatMadhab(Madhab madhab) => switch (madhab) {
    Madhab.standard =>
      _en
          ? "Shafi'i, Maliki, Hanbali: one shadow"
          : "Syafi'i, Maliki, Hanbali: satu bayangan",
    Madhab.hanafi => _en ? 'Hanafi: two shadows' : 'Hanafi: dua bayangan',
  };
  String get salatHighLatitude =>
      _en ? 'Far north and south' : 'Jauh di utara dan selatan';
  String salatHighLatitudeRule(HighLatitudeRule? rule, double latitude) {
    String of(HighLatitudeRule r) => switch (r) {
      HighLatitudeRule.middleOfTheNight =>
        _en ? 'middle of the night' : 'tengah malam',
      HighLatitudeRule.seventhOfTheNight =>
        _en ? 'a seventh of the night' : 'sepertujuh malam',
      HighLatitudeRule.twilightAngle =>
        _en ? 'the angle over 60' : 'sudut per 60',
    };
    if (rule == null) {
      final r = of(HighLatitudeRule.recommended(latitude));
      return _en ? 'Recommended here: $r' : 'Disarankan di sini: $r';
    }
    return '${of(rule)[0].toUpperCase()}${of(rule).substring(1)}';
  }

  /// What a time is, and how it is reckoned, by a convention other than
  /// the ministry's.
  String salatRuleElsewhere(Salat salat, SalatMethod method, Madhab madhab) {
    String name(Salat s) => salatName(s, indonesian: false);
    String plus(String time) {
      final m = method.adjustment(time);
      if (m == 0) return '';
      return _en
          ? ', ${m > 0 ? 'plus' : 'less'} ${m.abs()} min'
          : ', ${m > 0 ? 'ditambah' : 'dikurangi'} ${m.abs()} menit';
    }

    String degrees(double d) =>
        '${d.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll('.', _en ? '.' : ',')}°';
    return switch (salat) {
      Salat.imsak => '',
      Salat.subuh =>
        _en
            ? 'Dawn: the sun ${degrees(method.fajrAngle)} below the eastern '
                  'horizon, or, where it never sinks so far, the night rule. '
                  'Its time runs until sunrise.'
            : 'Fajar: matahari ${degrees(method.fajrAngle)} di bawah ufuk '
                  'timur, atau aturan malam bila tidak pernah turun sejauh '
                  'itu. Waktunya sampai matahari terbit.',
      Salat.terbit =>
        _en
            ? 'Sunrise, the sun\'s upper edge on the horizon${plus('terbit')}: '
                  'the end of the time of ${name(Salat.subuh)}.'
            : 'Matahari terbit, tepi atasnya di ufuk${plus('terbit')}: akhir '
                  'waktu ${name(Salat.subuh)}.',
      Salat.duha =>
        _en
            ? 'The sun 4.5° up, as Indonesia\'s ministry reckons it: the '
                  'voluntary forenoon prayer may begin.'
            : 'Matahari 4,5° di atas ufuk, seperti hitungan Kementerian '
                  'Agama: salat sunah duha boleh dimulai.',
      Salat.zuhur =>
        _en
            ? 'Noon: the sun past the meridian${plus('zuhur')}. Its time runs '
                  'until ${name(Salat.asar)}.'
            : 'Tengah hari: matahari tergelincir dari meridian${plus('zuhur')}. '
                  'Waktunya sampai Asar.',
      Salat.asar =>
        _en
            ? 'Afternoon: a shadow '
                  '${madhab == Madhab.hanafi ? 'twice as long as' : 'as long as'} '
                  'the thing itself beyond its noon shadow${plus('asar')}. Its '
                  'time runs until ${name(Salat.magrib)}.'
            : 'Sore: bayangan '
                  '${madhab == Madhab.hanafi ? 'dua kali panjang' : 'sepanjang'} '
                  'bendanya ditambah bayangan saat Zuhur${plus('asar')}. '
                  'Waktunya sampai Magrib.',
      Salat.magrib =>
        method.maghribAngle != null
            ? (_en
                  ? 'The sun ${degrees(method.maghribAngle!)} below the western '
                        'horizon. The Hijri day begins at sunset. Its time '
                        'runs until ${name(Salat.isya)}.'
                  : 'Matahari ${degrees(method.maghribAngle!)} di bawah ufuk '
                        'barat. Hari Hijriah berganti saat matahari terbenam. '
                        'Waktunya sampai Isya.')
            : (_en
                  ? 'Sunset${plus('magrib')}. The Hijri day begins here. Its '
                        'time runs until ${name(Salat.isya)}.'
                  : 'Matahari terbenam${plus('magrib')}. Hari Hijriah berganti '
                        'di sini. Waktunya sampai Isya.'),
      Salat.isya =>
        method.ishaInterval > 0
            ? (_en
                  ? 'Nightfall: ${method.ishaInterval} minutes after '
                        '${name(Salat.magrib)}${method == SalatMethod.ummAlQura ? ', 120 in Ramadan' : ''}. '
                        'Its time runs until ${name(Salat.subuh)}.'
                  : 'Malam: ${method.ishaInterval} menit setelah Magrib'
                        '${method == SalatMethod.ummAlQura ? ', 120 menit di bulan Ramadan' : ''}. '
                        'Waktunya sampai Subuh.')
            : (_en
                  ? 'Nightfall: the sun ${degrees(method.ishaAngle)} below the '
                        'western horizon, or, where it never sinks so far, the '
                        'night rule. Its time runs until ${name(Salat.subuh)}.'
                  : 'Malam: matahari ${degrees(method.ishaAngle)} di bawah ufuk '
                        'barat, atau aturan malam bila tidak pernah turun '
                        'sejauh itu. Waktunya sampai Subuh.'),
    };
  }

  /// How the times are reckoned, outside Indonesia.
  String salatMethodElsewhere(SalatMethod method) {
    const checked = {
      SalatMethod.turkey,
      SalatMethod.qatar,
      SalatMethod.dubai,
      SalatMethod.kuwait,
      SalatMethod.moonsightingCommittee,
      SalatMethod.ummAlQura,
      SalatMethod.singapore,
    };
    final name = salatMethodName(method);
    if (checked.contains(method)) {
      return _en
          ? 'Reckoned by the convention of $name, and checked against its '
                'published timetable: within two minutes. Far north and south '
                'the night rule holds dawn and nightfall within the night. A '
                'mosque\'s own schedule may differ by a minute or two.'
          : 'Dihitung dengan cara $name, dan diperiksa terhadap jadwal '
                'terbitannya: selisih paling banyak dua menit. Jauh di utara '
                'dan selatan, aturan malam menjaga fajar dan malam tetap di '
                'dalam malam. Jadwal masjid setempat bisa berbeda satu-dua '
                'menit.';
    }
    return _en
        ? 'Reckoned by the angles of $name. No timetable of it was at hand to '
              'check against. Far north and south the night rule holds dawn '
              'and nightfall within the night. Follow your mosque\'s own '
              'schedule where it differs.'
        : 'Dihitung dengan sudut $name. Belum ada jadwal terbitannya untuk '
              'pembanding. Jauh di utara dan selatan, aturan malam menjaga '
              'fajar dan malam tetap di dalam malam. Ikuti jadwal masjid Anda '
              'bila berbeda.';
  }

  String get salatAskPlace => _en
      ? 'Prayer times depend on where you are. Set a place in the panel.'
      : 'Waktu salat bergantung pada tempat Anda. Tetapkan tempat di panel.';
  // Planets.
  String planetName(Body body) => switch (body) {
    Body.mercury => _en ? 'Mercury' : 'Merkurius',
    Body.venus => 'Venus',
    Body.mars => 'Mars',
    Body.jupiter => _en ? 'Jupiter' : 'Yupiter',
    Body.saturn => _en ? 'Saturn' : 'Saturnus',
    Body.uranus => 'Uranus',
    Body.neptune => _en ? 'Neptune' : 'Neptunus',
    Body.sun => _en ? 'Sun' : 'Matahari',
    Body.moon => _en ? 'Moon' : 'Bulan',
  };

  String get planetsTitle => _en ? 'Planets' : 'Planet';
  String get planetsAskPlace => _en
      ? 'Where the planets stand depends on where you are. Set a place in '
            'the panel.'
      : 'Letak planet bergantung pada tempat Anda. Tetapkan tempat di panel.';
  String get planetsHours => _en ? 'Hours' : 'Jam';
  String get planetsLore => _en ? 'Lore' : 'Ajaran';
  String planetsMagnitude(double m) => _en
      ? 'mag ${m.toStringAsFixed(1)}'
      : 'mag ${m.toStringAsFixed(1).replaceAll('.', ',')}';
  String get planetsEvening => _en ? 'evening sky' : 'langit senja';
  String get planetsMorning => _en ? 'morning sky' : 'langit fajar';
  String get planetsHow => _en
      ? 'Worked out on the phone from the VSOP87 theory (Bretagnon and '
            'Francou, 1988) and held against JPL\'s ephemeris to two seconds '
            'of arc; brightness by Mallama and Hilton (2018). Mag is the '
            'magnitude: smaller is brighter, and the eye sees to about 6.'
      : 'Dihitung di ponsel dari teori VSOP87 (Bretagnon dan Francou, 1988) '
            'dan dibandingkan dengan efemeris JPL sampai dua detik busur; '
            'kecerlangan menurut Mallama dan Hilton (2018). Mag adalah '
            'magnitudo: makin kecil makin terang, dan mata melihat sampai '
            'sekitar 6.';
  String get planetsNoHours => _en
      ? 'The sun does not both rise and set here that day: there are no '
            'planetary hours.'
      : 'Matahari tidak terbit dan terbenam di sini hari itu: tidak ada jam '
            'planet.';
  String planetsDayOf(String weekday, String ruler) =>
      _en ? '$weekday, the day of $ruler' : '$weekday, hari $ruler';
  String get planetsDayHours =>
      _en ? 'Day, from sunrise' : 'Siang, sejak matahari terbit';
  String get planetsNightHours =>
      _en ? 'Night, from sunset' : 'Malam, sejak matahari terbenam';
  String get planetsHoursHow => _en
      ? 'The old astrologers\' hours: sunrise to sunset cut into twelve, '
            'sunset to the next sunrise into twelve more, so they are long by '
            'day in summer and short in winter. Each goes to a planet in the '
            'Chaldean order, slowest to swiftest (Saturn, Jupiter, Mars, the '
            'sun, Venus, Mercury, the moon), the day\'s first hour to the '
            'planet the day is named for. Twenty-four hours on, the next '
            'day\'s first hour falls three places down the order: that is '
            'why the week runs as it does. Sunrise is the sun\'s centre on '
            'the horizon, as of old; the night belongs to the day before it, '
            'so malam Jumat is in Thursday\'s hours. The Malay ketika tujuh '
            'is the same order, seven parts to the day.'
      : 'Jam para ahli nujum lama: matahari terbit sampai terbenam dibagi dua '
            'belas, terbenam sampai terbit berikutnya dua belas lagi, sehingga '
            'jam siang panjang di musim panas dan pendek di musim dingin. '
            'Tiap jam diberikan kepada sebuah planet menurut urutan Kaldea, '
            'dari yang terlambat sampai yang tercepat (Saturnus, Yupiter, Mars, '
            'matahari, Venus, Merkurius, bulan), jam pertama tiap hari kepada '
            'planet yang memberi nama hari itu. Dua puluh empat jam kemudian, '
            'jam pertama hari berikutnya jatuh tiga tempat lebih jauh dalam '
            'urutan itu: karena itulah urutan hari dalam sepekan seperti '
            'sekarang. Matahari terbit adalah pusatnya di ufuk, seperti dahulu; '
            'malam milik hari sebelumnya, sehingga malam Jumat termasuk jam '
            'hari Kamis. Ketika tujuh orang Melayu memakai urutan yang sama, '
            'tujuh bagian dalam sehari.';

  /// Its name in the Arabic of the Malay manuals (Skeat 1900; the Tāj
  /// al-Mulk) and the Sanskrit of the Old Javanese weekday (Trigangga
  /// and others 2015).
  String planetsOtherNames(Body body) {
    final (arabic, sanskrit) = switch (body) {
      Body.saturn => ('Zuhal', 'Śanaiścara'),
      Body.jupiter => ('Musytari', 'Wṛhaspati'),
      Body.mars => ('Mirrikh', 'Aṅgāraka'),
      Body.sun => ('Syams', 'Āditya'),
      Body.venus => ('Zuhrah', 'Śukra'),
      Body.mercury => ('ʿUtarid', 'Budha'),
      Body.moon => ('Qamar', 'Soma'),
      _ => ('', ''),
    };
    return _en
        ? 'Arabic $arabic · Old Javanese $sanskrit'
        : 'Arab $arabic · Jawa Kuno $sanskrit';
  }

  /// The signs Ptolemy gives each as its house (Tetrabiblos I.17).
  String planetsSigns(Body body) {
    final signs = switch (body) {
      Body.saturn => 'Capricornus, Aquarius',
      Body.jupiter => 'Sagittarius, Pisces',
      Body.mars => 'Scorpius, Aries',
      Body.sun => 'Leo',
      Body.venus => 'Libra, Taurus',
      Body.mercury => 'Gemini, Virgo',
      Body.moon => 'Cancer',
      _ => '',
    };
    return _en ? 'houses $signs' : 'rumah $signs';
  }

  /// Of the day or of the night (Tetrabiblos I.7).
  String planetsSect(Body body) => switch (body) {
    Body.sun ||
    Body.jupiter ||
    Body.saturn => _en ? 'of the day' : 'planet siang',
    Body.moon ||
    Body.venus ||
    Body.mars => _en ? 'of the night' : 'planet malam',
    _ => _en ? 'of either: the day as morning star, the night as evening star' : 'keduanya: siang sebagai bintang fajar, malam sebagai bintang senja',
  };

  String planetsMetal(Body body) => switch (body) {
    Body.saturn => _en ? 'lead' : 'timbal',
    Body.jupiter => _en ? 'tin' : 'timah',
    Body.mars => _en ? 'iron' : 'besi',
    Body.sun => _en ? 'gold' : 'emas',
    Body.venus => _en ? 'copper' : 'tembaga',
    Body.mercury => _en ? 'quicksilver' : 'raksa',
    Body.moon => _en ? 'silver' : 'perak',
    _ => '',
  };
  String planetsWeekday(Body body) => switch (body) {
    Body.saturn => _en ? 'Saturday (dies Saturni)' : 'Sabtu (dies Saturni)',
    Body.jupiter => _en ? 'Thursday (dies Iovis)' : 'Kamis (dies Iovis)',
    Body.mars => _en ? 'Tuesday (dies Martis)' : 'Selasa (dies Martis)',
    Body.sun => _en ? 'Sunday (dies Solis)' : 'Minggu (dies Solis)',
    Body.venus => _en ? 'Friday (dies Veneris)' : 'Jumat (dies Veneris)',
    Body.mercury => _en ? 'Wednesday (dies Mercurii)' : 'Rabu (dies Mercurii)',
    Body.moon => _en ? 'Monday (dies Lunae)' : 'Senin (dies Lunae)',
    _ => '',
  };
  String get planetsLoreHow => _en
      ? 'The seven wanderers of the old astronomy, slowest to swiftest. The '
            'metals are the alchemists\' usual set; the oldest Greek lists '
            'gave Jupiter electrum and Mercury tin (Olympiodorus, through '
            'Berthelot). The days are named for the planets in Latin and in '
            'Old Javanese inscriptions (soma-vāra, Monday, in 863); the '
            'Indonesian names are Arabic and Portuguese and do not name them. '
            'Houses and day or night are Ptolemy\'s, Tetrabiblos I.17 and I.7.'
      : 'Tujuh pengembara dalam astronomi lama, dari yang terlambat sampai '
            'yang tercepat. Logamnya himpunan yang lazim pada ahli kimia lama; '
            'daftar Yunani tertua memberi Yupiter elektrum dan Merkurius timah '
            '(Olympiodorus, lewat Berthelot). Hari-hari dinamai menurut planet '
            'dalam bahasa Latin dan dalam prasasti Jawa Kuno (soma-vāra, Senin, '
            'tahun 863); nama hari dalam bahasa Indonesia berasal dari bahasa '
            'Arab dan Portugis dan tidak menyebutnya. Rumah dan siang atau '
            'malam menurut Ptolemaios, Tetrabiblos I.17 dan I.7.';

  /// Venus by its Javanese names: the evening star and the morning star
  /// (Gericke and Roorda, 1901).
  String panjer({required bool evening}) =>
      evening ? 'Panjer Sore' : 'Panjer Esuk';
  String get planetEvening =>
      _en ? 'Evening sky, east of the sun' : 'Langit senja, timur matahari';
  String get planetMorning =>
      _en ? 'Morning sky, west of the sun' : 'Langit fajar, barat matahari';
  String get planetSide => _en ? 'Seen' : 'Terlihat';
  String get planetDistance => _en ? 'Distance' : 'Jarak';
  String planetAu(double au) => _en
      ? '${au.toStringAsFixed(3)} au'
      : '${au.toStringAsFixed(3).replaceAll('.', ',')} SA';
  String get planetLit => _en ? 'Lit' : 'Terang';
  String get planetSize => _en ? 'Apparent size' : 'Ukuran tampak';
  String get planetFromSun => _en ? 'From the sun' : 'Dari matahari';
  String get planetPanjerNote => _en
      ? 'Venus is Panjer Sore as the evening star and Panjer Esuk as the '
            'morning star (Gericke and Roorda\'s dictionary, 1901).'
      : 'Venus disebut Panjer Sore sebagai bintang senja dan Panjer Esuk '
            'sebagai bintang fajar (kamus Gericke dan Roorda, 1901).';

  // Hilal. The criteria keep the names they are known by.
  String get hilalTitle => 'Hilal';
  String get hilalEvening => _en ? 'Evening' : 'Petang';
  String get hilalCriteria => _en ? 'Criteria' : 'Kriteria';
  String get hilalMonths => _en ? 'New moons' : 'Ijtimak';
  String get hilalAskPlace => _en
      ? 'The crescent depends on where you are. Set a place in the panel.'
      : 'Hilal bergantung pada tempat Anda. Tetapkan tempat di panel.';
  String get hilalNoSunset => _en
      ? 'The sun does not set here that day.'
      : 'Matahari tidak terbenam di sini hari itu.';
  String get hilalConjunction => _en ? 'New moon' : 'Ijtimak';
  String get hilalSunset => _en ? 'Sunset' : 'Matahari terbenam';
  String get hilalMoonset => _en ? 'Moonset' : 'Bulan terbenam';
  String get hilalLag => _en ? 'Moon after sun' : 'Selisih terbenam';
  String hilalLagValue(int minutes) => minutes >= 0
      ? (_en ? '$minutes min after' : '$minutes menit sesudah')
      : (_en ? '${-minutes} min before' : '${-minutes} menit sebelum');
  String get hilalAge => _en ? 'Age at sunset' : 'Umur bulan';
  String hilalAgeValue(int minutes) {
    final m = minutes.abs();
    final text = _en
        ? '${m ~/ 60} h ${m % 60} min'
        : '${m ~/ 60} j ${m % 60} m';
    if (minutes >= 0) return text;
    return _en ? 'the new moon in $text' : 'ijtimak $text lagi';
  }

  String get hilalHeight => _en ? 'Height' : 'Tinggi hilal';
  String get hilalHeightAir => _en ? 'Height, as seen' : 'Tinggi, terlihat';
  String get hilalElongation => _en ? 'Elongation' : 'Elongasi';
  String get hilalElongationHere =>
      _en ? 'Elongation, from here' : 'Elongasi, dari sini';
  String get hilalLit => _en ? 'Lit' : 'Iluminasi';
  String get hilalBest => _en ? 'Best time' : 'Waktu terbaik';
  String get hilalEveningHow => _en
      ? 'At sunset, the sun\'s upper edge on the horizon. The height is the '
            'moon\'s centre from this place with no air, as Bosscha '
            'Observatory gives it; as seen, the air lifts it. Elongation is '
            'from the Earth\'s centre, as the ministry reckons it. The best '
            'time, for Yallop and Odeh, is four ninths of the way from sunset '
            'to moonset.'
      : 'Saat matahari terbenam, tepi atasnya di ufuk. Tinggi hilal adalah '
            'pusat bulan dari tempat ini tanpa udara, seperti yang diberikan '
            'Observatorium Bosscha; yang terlihat, terangkat oleh udara. '
            'Elongasi dari pusat bumi, seperti hitungan Kementerian Agama. '
            'Waktu terbaik, bagi Yallop dan Odeh, empat persembilan jalan dari '
            'matahari terbenam ke bulan terbenam.';
  String get hilalMabims => 'MABIMS';
  String get hilalMabimsWho => _en
      ? 'Indonesia\'s ministry, from 2022'
      : 'Kementerian Agama, sejak 2022';
  String hilalMabimsValue(bool met, String height, String elongation) => _en
      ? '${met ? 'Met' : 'Not met'} here: $height high (3°), $elongation apart (6.4°)'
      : '${met ? 'Terpenuhi' : 'Tidak terpenuhi'} di sini: tinggi $height (3°), elongasi $elongation (6,4°)';
  String get hilalIndonesia =>
      _en ? 'Anywhere in Indonesia' : 'Di mana pun di Indonesia';
  String hilalIndonesiaValue(bool met, String height, String elongation) => _en
      ? '${met ? 'Met somewhere' : 'Met nowhere'}: highest $height, widest $elongation'
      : '${met ? 'Terpenuhi di suatu tempat' : 'Tidak terpenuhi di mana pun'}: tertinggi $height, elongasi terbesar $elongation';
  String get hilalWujud => 'Wujudul hilal';
  String get hilalWujudWho => _en
      ? 'Muhammadiyah\'s rule until 1446 H'
      : 'Kaidah Muhammadiyah hingga 1446 H';
  String hilalWujudValue(bool met) => _en
      ? (met
            ? 'Met: the new moon before sunset, the moon\'s upper edge above the horizon'
            : 'Not met')
      : (met
            ? 'Terpenuhi: ijtimak sebelum matahari terbenam, piringan atas bulan di atas ufuk'
            : 'Tidak terpenuhi');
  String get hilalAboutMabims => _en
      ? 'The rule of the religious ministers of Brunei, Indonesia, Malaysia '
            'and Singapore: the crescent counts as possible to see once the '
            'moon is 3° high and 6.4° from the sun at sunset.'
      : 'Kaidah para menteri agama Brunei, Indonesia, Malaysia dan Singapura: '
            'hilal dianggap mungkin terlihat bila tinggi bulan 3° dan '
            'elongasinya 6,4° saat matahari terbenam.';
  String get hilalAboutIndonesia => _en
      ? 'The ministry applies MABIMS to the whole country: met at any one '
            'place in Indonesia, it holds for all. Worked out over every '
            'whole degree of Indonesia.'
      : 'Kementerian memberlakukan MABIMS untuk seluruh negeri: terpenuhi di '
            'satu tempat mana pun di Indonesia, berlaku untuk semua. Dihitung '
            'pada setiap derajat bulat wilayah Indonesia.';
  String get hilalAboutWujud => _en
      ? 'Muhammadiyah\'s old rule: the month begins once the moon has '
            'passed the sun and is still above the horizon at sunset, however '
            'low, seen or not. Replaced in 1447 H by a calendar for the whole '
            'world.'
      : 'Kaidah lama Muhammadiyah: bulan baru dimulai bila ijtimak sudah '
            'terjadi dan bulan masih di atas ufuk saat matahari terbenam, '
            'serendah apa pun, terlihat atau tidak. Diganti pada 1447 H oleh '
            'kalender untuk seluruh dunia.';
  String get hilalAboutOdeh => _en
      ? 'Not a religious rule but a forecast: can the crescent actually be '
            'seen, and with what. Mohammad Odeh, astronomer, 2004, from 737 '
            'recorded sightings and failures.'
      : 'Bukan kaidah agama melainkan perkiraan: apakah hilal benar-benar '
            'bisa terlihat, dan dengan apa. Mohammad Odeh, astronom, 2004, dari '
            '737 catatan rukyat yang berhasil dan gagal.';
  String get hilalAboutYallop => _en
      ? 'The same question, the older answer that Odeh refined: B. D. '
            'Yallop of HM Nautical Almanac Office, Britain, 1997.'
      : 'Pertanyaan yang sama, jawaban lebih tua yang disempurnakan Odeh: '
            'B. D. Yallop dari HM Nautical Almanac Office, Inggris, 1997.';
  String get hilalOdeh => 'Odeh';
  String hilalOdehZone(OdehZone zone) => switch (zone) {
    OdehZone.a =>
      _en ? 'Zone A: seen by the naked eye' : 'Zona A: terlihat mata telanjang',
    OdehZone.b =>
      _en
          ? 'Zone B: with optical aid, maybe the naked eye'
          : 'Zona B: dengan alat optik, mungkin mata telanjang',
    OdehZone.c =>
      _en ? 'Zone C: with optical aid only' : 'Zona C: hanya dengan alat optik',
    OdehZone.d =>
      _en
          ? 'Zone D: not even with optical aid'
          : 'Zona D: tidak terlihat meski dengan alat optik',
  };
  String get hilalYallop => 'Yallop';
  String hilalYallopClass(YallopClass c) => switch (c) {
    YallopClass.a => _en ? 'Class A: easily seen' : 'Kelas A: mudah terlihat',
    YallopClass.b =>
      _en
          ? 'Class B: seen in perfect conditions'
          : 'Kelas B: terlihat dalam kondisi sempurna',
    YallopClass.c =>
      _en
          ? 'Class C: may need optical aid to find'
          : 'Kelas C: mungkin perlu alat optik untuk menemukannya',
    YallopClass.d =>
      _en
          ? 'Class D: will need optical aid to find'
          : 'Kelas D: perlu alat optik untuk menemukannya',
    YallopClass.e =>
      _en
          ? 'Class E: not seen with a telescope'
          : 'Kelas E: tidak terlihat dengan teleskop',
    YallopClass.f =>
      _en
          ? 'Class F: below the Danjon limit'
          : 'Kelas F: di bawah batas Danjon',
  };
  String get hilalSetsFirst => _en
      ? 'The moon sets before the sun: nothing to see'
      : 'Bulan terbenam sebelum matahari: tidak ada yang terlihat';
  String get hilalCriteriaHow => _en
      ? 'Astronomy only. A month begins when those who rule on it say so, by '
            'their own criterion and, for many, by sight. Muhammadiyah\'s '
            'global calendar (KHGT) is reckoned for the whole world and is not '
            'worked out here. The moon\'s height is from this place at '
            'sunset; the best time, for Odeh and Yallop, four ninths of the '
            'way from sunset to moonset.'
      : 'Hanya astronomi. Awal bulan ditetapkan oleh yang berwenang, dengan '
            'kriterianya sendiri dan, bagi banyak orang, dengan rukyat. '
            'Kalender global Muhammadiyah (KHGT) dihitung untuk seluruh dunia '
            'dan tidak dihitung di sini. Tinggi bulan dari tempat ini saat '
            'matahari terbenam; waktu terbaik, bagi Odeh dan Yallop, empat '
            'persembilan jalan dari matahari terbenam ke bulan terbenam.';
  String hilalMonthAt(String time) =>
      _en ? 'new moon at $time' : 'ijtimak pukul $time';
  String hilalMonthEvening(String day, bool mabims, String? odeh) => _en
      ? '$day: MABIMS ${mabims ? 'met' : 'not met'} · Odeh ${odeh ?? '–'}'
      : '$day: MABIMS ${mabims ? 'terpenuhi' : 'tidak'} · Odeh ${odeh ?? '–'}';
  String get hilalMonthsHow => _en
      ? 'The coming new moons, and here, for the evening of each and the '
            'next, whether MABIMS is met and Odeh\'s zone. Touch one to see it.'
      : 'Ijtimak yang akan datang, dan di sini, untuk petang hari itu dan '
            'sesudahnya, apakah MABIMS terpenuhi dan zona Odeh. Sentuh untuk '
            'melihatnya.';
  String get hilalMoonDown =>
      _en ? 'The moon is below the horizon' : 'Bulan di bawah ufuk';
  String get salatNext => _en ? 'Next' : 'Berikutnya';
  String get salatNow => _en ? 'Now in the time of' : 'Sedang waktu';

  /// "in 1 h 12 min", "in 25 min".
  String salatIn(int minutes) {
    final unit = _en ? 'min' : 'mnt';
    final text = minutes < 60
        ? '$minutes $unit'
        : '${minutes ~/ 60} ${_en ? 'h' : 'j'} ${minutes % 60} $unit';
    return _en ? 'in $text' : '$text lagi';
  }

  String get imageSaved =>
      _en ? 'Saved to Pictures/Candra.' : 'Tersimpan di Pictures/Candra.';
  String get imageNotSaved => _en
      ? 'Could not save the image on this device.'
      : 'Gambar tidak dapat disimpan di perangkat ini.';

  String get pressBackAgain => _en
      ? 'Press back again to exit.'
      : 'Tekan kembali sekali lagi untuk keluar.';

  String systemLockReleased() => _en
      ? 'Default calendar reset to '
            '${systemLabel(CalendarSystem.gregorian)}.'
      : 'Kalender bawaan dikembalikan ke '
            '${systemLabel(CalendarSystem.gregorian)}.';

  String viewLockedAsDefault({required bool year, bool day = false}) => _en
      ? '${day
                ? 'Day'
                : year
                ? 'Year'
                : 'Month'} view is now your default '
            'and will persist on restart.'
      : 'Tampilan ${day
                ? 'hari'
                : year
                ? 'tahun'
                : 'bulan'} sekarang menjadi bawaan '
            'dan tetap tersimpan saat aplikasi dibuka kembali.';

  String viewLockReleased() => _en
      ? 'Default view reset to month.'
      : 'Tampilan bawaan dikembalikan ke bulan.';

  String lockedAsDefault(CalendarSystem system) => _en
      ? '${systemLabel(system)} is now your default calendar '
            'and will persist on restart.'
      : '${systemLabel(system)} sekarang menjadi kalender bawaan '
            'dan tetap tersimpan saat aplikasi dibuka kembali.';

  // Monday first.
  List<String> get weekdayInitials => _en
      ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
      : const ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  List<String> get monthNames => _en ? _monthsEn : _monthsId;

  String monthYear(int year, int month) => '${monthNames[month - 1]} $year';

  /// The Gregorian days from [first] to [last], as a month of another
  /// system spans them: "October – November 2026", "December 2026 –
  /// January 2027", or one month alone.
  String gregorianSpan(CivilDate first, CivilDate last) {
    final from = monthNames[first.month - 1];
    final to = monthNames[last.month - 1];
    if (first.year != last.year) {
      return '$from ${first.year} – $to ${last.year}';
    }
    if (first.month == last.month) return '$from ${first.year}';
    return '$from – $to ${last.year}';
  }

  // Systems.

  String systemLabel(CalendarSystem system) => switch (system) {
    CalendarSystem.weton => 'Weton',
    CalendarSystem.javanese => _en ? 'Javanese' : 'Jawa',
    CalendarSystem.chinese => _en ? 'Chinese' : 'Imlek',
    CalendarSystem.hijri => _en ? 'Hijri' : 'Hijriah',
    CalendarSystem.gregorian => _en ? 'Gregorian' : 'Masehi',
  };

  /// The day as [system] names it, or null outside its supported range.
  String? dayText(CalendarSystem system, CivilDate date) => switch (system) {
    CalendarSystem.weton => '${Weton.of(date)}',
    CalendarSystem.javanese =>
      JavaneseDate.supports(date) ? '${JavaneseDate.of(date)}' : null,
    CalendarSystem.chinese =>
      ChineseDate.supports(date) ? chinese(ChineseDate.of(date)) : null,
    CalendarSystem.hijri =>
      HijriDate.supports(date) ? hijri(HijriDate.of(date)) : null,
    CalendarSystem.gregorian => gregorian(date),
  };

  /// The line under the month button: [system]'s months across the
  /// Gregorian month running from [first] to [last].
  String? monthSubtitle(
    CalendarSystem system,
    CivilDate first,
    CivilDate last,
  ) {
    switch (system) {
      case CalendarSystem.weton:
        return 'Pasaran';
      case CalendarSystem.gregorian:
        return null;
      case CalendarSystem.javanese:
        if (!JavaneseDate.supports(first) || !JavaneseDate.supports(last)) {
          return null;
        }
        final from = JavaneseDate.of(first);
        final to = JavaneseDate.of(last);
        return _span(
          from.month.label,
          '${from.year}',
          to.month.label,
          '${to.year} ${to.taun.label}',
          sameYear: from.year == to.year,
        );
      case CalendarSystem.hijri:
        if (!HijriDate.supports(first)) return null;
        final from = HijriDate.of(first);
        final to = HijriDate.of(last);
        return _span(
          hijriMonth(from.month),
          '${from.year} $_hijriEra',
          hijriMonth(to.month),
          '${to.year} $_hijriEra',
          sameYear: from.year == to.year,
        );
      case CalendarSystem.chinese:
        if (!ChineseDate.supports(first) || !ChineseDate.supports(last)) {
          return null;
        }
        final from = ChineseDate.of(first);
        final to = ChineseDate.of(last);
        return _span(
          chineseMonth(from),
          '${from.kongziliYear}',
          chineseMonth(to),
          '${to.kongziliYear} ${zodiac(to)}',
          sameYear: from.year == to.year,
        );
    }
  }

  /// The line under the month button in year view: what [system] makes of
  /// the whole of [year].
  String? yearSubtitle(CalendarSystem system, int year, CivilDate selected) {
    final first = CivilDate(year, 1, 1);
    final last = CivilDate(year, 12, 31);
    String span(String from, String to) => from == to ? from : '$from – $to';

    switch (system) {
      case CalendarSystem.weton:
        return '${Weton.of(selected)}';
      case CalendarSystem.gregorian:
        return null;
      case CalendarSystem.javanese:
        if (!JavaneseDate.supports(first) || !JavaneseDate.supports(last)) {
          return null;
        }
        return span(
          javaneseYear(JavaneseDate.of(first)),
          javaneseYear(JavaneseDate.of(last)),
        );
      case CalendarSystem.hijri:
        if (!HijriDate.supports(first)) return null;
        return span(
          hijriYear(HijriDate.of(first)),
          hijriYear(HijriDate.of(last)),
        );
      case CalendarSystem.chinese:
        if (!ChineseDate.supports(first) || !ChineseDate.supports(last)) {
          return null;
        }
        return span(
          chineseYear(ChineseDate.of(first)),
          chineseYear(ChineseDate.of(last)),
        );
    }
  }

  String javaneseYear(JavaneseDate date) => '${date.year} ${date.taun.label}';

  String hijriYear(HijriDate date) => '${date.year} $_hijriEra';

  String chineseYear(ChineseDate date) =>
      '${date.kongziliYear} ${zodiac(date)}';

  String get newYear => _en ? 'New year' : 'Tahun baru';

  /// A day and month without the year: "17 February".
  String dayMonth(CivilDate date) =>
      '${date.day} ${monthNames[date.month - 1]}';

  /// "10 times in 2026" / "10 kali pada 2026".
  String timesInYear(int count, int year) =>
      _en ? '$count times in $year' : '$count kali pada $year';

  static String _span(
    String fromMonth,
    String fromYear,
    String toMonth,
    String toYear, {
    required bool sameYear,
  }) {
    if (!sameYear) return '$fromMonth $fromYear – $toMonth $toYear';
    if (fromMonth != toMonth) return '$fromMonth – $toMonth $toYear';
    return '$toMonth $toYear';
  }

  // Dates.

  String gregorian(CivilDate date) =>
      '${date.day} ${monthNames[date.month - 1]} ${date.year}';

  String hijriMonth(HijriMonth month) =>
      _en ? _hijriMonthsEn[month.index] : month.label;

  String get _hijriEra => _en ? 'AH' : 'H';

  String hijri(HijriDate date) =>
      '${date.day} ${hijriMonth(date.month)} ${date.year} $_hijriEra';

  /// Hokkien month names in Indonesian; numbered months in English.
  String chineseMonth(ChineseDate date) {
    if (!_en) return date.monthLabel;
    final month = '${_ordinalsEn[date.month - 1]} Month';
    return date.isLeapMonth ? 'Leap $month' : month;
  }

  String chinese(ChineseDate date) =>
      '${date.day} ${chineseMonth(date)} ${date.kongziliYear}';

  /// The year's animal and element: "Fire Horse", "Kuda Api".
  String zodiac(ChineseDate date) => _en
      ? '${zodiacElement(date)} ${zodiacAnimal(date)}'
      : '${zodiacAnimal(date)} ${zodiacElement(date)}';

  String zodiacAnimal(ChineseDate date) =>
      _en ? _animalsEn[date.shio.index] : date.shio.label;

  String zodiacElement(ChineseDate date) =>
      _en ? _elementsEn[date.unsur.index] : date.unsur.label;

  /// English puts the element first ("Fire Horse"); Indonesian the animal.
  bool get elementFirst => _en;

  /// The element's character: 木 火 土 金 水.
  static String elementHanzi(ChineseDate date) =>
      _elementsHanzi[date.unsur.index];

  /// An element's character.
  static String unsurHanzi(Unsur unsur) => _elementsHanzi[unsur.index];

  /// A day's element in full, yin or yang, in characters: 陽金, 陰土.
  static String dayElementHanzi(CivilDate date) =>
      '${ChineseDate.dayIsYang(date) ? '陽' : '陰'}'
      '${unsurHanzi(ChineseDate.dayUnsur(date))}';

  /// A day's element in full, in words: "Yang Metal", "Logam Yang".
  String dayElement(CivilDate date) {
    final polarity = ChineseDate.dayIsYang(date) ? 'Yang' : 'Yin';
    final element = elementName(ChineseDate.dayUnsur(date));
    return _en ? '$polarity $element' : '$element $polarity';
  }

  /// An element's name: "Fire", "Api".
  String elementName(Unsur unsur) =>
      _en ? _elementsEn[unsur.index] : unsur.label;

  /// The animal's character: 鼠 牛 虎 兔 龍 蛇 馬 羊 猴 雞 狗 豬.
  static String animalHanzi(ChineseDate date) => _animalsHanzi[date.shio.index];

  /// The date in Chinese characters, with the year by its stem and branch:
  /// 丙午年九月初二. A leap month is marked 閏.
  static String chineseHanzi(ChineseDate date) {
    final stem = _stems[(date.year - 4) % 10];
    final branch = _branches[(date.year - 4) % 12];
    final month = date.month == 1 ? '正' : _numeral(date.month);
    final day = switch (date.day) {
      <= 10 => '初${_numeral(date.day)}',
      < 20 => '十${_numeral(date.day - 10)}',
      20 => '二十',
      < 30 => '廿${_numeral(date.day - 20)}',
      _ => '三十',
    };
    return '$stem$branch年${date.isLeapMonth ? '閏' : ''}$month月$day';
  }

  // 1..12 as Chinese numerals.
  static String _numeral(int n) => switch (n) {
    <= 10 => '一二三四五六七八九十'[n - 1],
    _ => '十${'一二'[n - 11]}',
  };

  /// Whether the day reading writes the Chinese date in characters.
  bool get chineseDateInHanzi => _en;

  String moonPhase(MoonPhase phase) =>
      _en ? phase.label : _phasesId[phase.index];

  static const _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _monthsId = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const _hijriMonthsEn = [
    'Muharram',
    'Safar',
    'Rabi\' al-Awwal',
    'Rabi\' al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah',
  ];

  static const _ordinalsEn = [
    'First',
    'Second',
    'Third',
    'Fourth',
    'Fifth',
    'Sixth',
    'Seventh',
    'Eighth',
    'Ninth',
    'Tenth',
    'Eleventh',
    'Twelfth',
  ];

  static const _animalsEn = [
    'Rat',
    'Ox',
    'Tiger',
    'Rabbit',
    'Dragon',
    'Snake',
    'Horse',
    'Goat',
    'Monkey',
    'Rooster',
    'Dog',
    'Pig',
  ];

  static const _elementsEn = ['Wood', 'Fire', 'Earth', 'Metal', 'Water'];

  static const _elementsHanzi = ['木', '火', '土', '金', '水'];
  static const _animalsHanzi = [
    '鼠',
    '牛',
    '虎',
    '兔',
    '龍',
    '蛇',
    '馬',
    '羊',
    '猴',
    '雞',
    '狗',
    '豬',
  ];
  static const _stems = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  static const _branches = [
    '子',
    '丑',
    '寅',
    '卯',
    '辰',
    '巳',
    '午',
    '未',
    '申',
    '酉',
    '戌',
    '亥',
  ];

  static const _phasesId = [
    'Bulan Baru',
    'Sabit Muda',
    'Paruh Awal',
    'Cembung Awal',
    'Purnama',
    'Cembung Akhir',
    'Paruh Akhir',
    'Sabit Tua',
  ];
}
