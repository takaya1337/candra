import 'civil_date.dart';

/// The seven-day week, Monday first.
enum Weekday {
  senin('Senin', 4),
  selasa('Selasa', 3),
  rabu('Rabu', 7),
  kamis('Kamis', 8),
  jumat('Jumat', 6),
  sabtu('Sabtu', 9),
  minggu('Minggu', 5);

  final String label;
  final int neptu;

  const Weekday(this.label, this.neptu);

  factory Weekday.of(CivilDate date) => values[date.dayNumber % 7];
}

/// The five-day Javanese market week.
enum Pasaran {
  legi('Legi', 5),
  pahing('Pahing', 9),
  pon('Pon', 7),
  wage('Wage', 4),
  kliwon('Kliwon', 8);

  final String label;
  final int neptu;

  const Pasaran(this.label, this.neptu);

  // Anchored on 17 August 1945 = Jumat Legi, whose day number is 0 mod 5.
  factory Pasaran.of(CivilDate date) => values[date.dayNumber % 5];
}

/// A day's position in the 35-day selapan cycle: weekday paired with pasaran.
class Weton {
  final Weekday weekday;
  final Pasaran pasaran;

  const Weton(this.weekday, this.pasaran);

  factory Weton.of(CivilDate date) => Weton(Weekday.of(date), Pasaran.of(date));

  int get neptu => weekday.neptu + pasaran.neptu;

  @override
  bool operator ==(Object other) =>
      other is Weton && other.weekday == weekday && other.pasaran == pasaran;

  @override
  int get hashCode => Object.hash(weekday, pasaran);

  @override
  String toString() => '${weekday.label} ${pasaran.label}';
}
