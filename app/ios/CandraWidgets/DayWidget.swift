import SwiftUI
import WidgetKit

// One day as every calendar reads it. The app works these out (the
// calendars are in Dart) and leaves a month of them in the app group;
// the widgets only show the one for today.
struct CandraDay: Codable {
  var date: String
  var day: Int
  var month: String
  var year: Int
  var weekday: String
  var sunday: Bool
  var weton: String
  var pasaran: String
  var neptu: Int
  var hijriLabel: String
  var hijriDay: String
  var hijriYear: String
  var chineseLabel: String
  // The day in the Hokkien month names: "4 Kau Gwee".
  var chineseDay: String
  var chineseHanzi: String
  var zodiac: String
  // The day's element in full, in words and in characters: "Yang
  // Metal", 陽金.
  var element: String
  var elementHanzi: String
  var elementColor: Int
  var javaneseLabel: String
  var javaneseDay: String
  var javaneseYear: String
  var wetonLabel: String
  var moon: String
  // Which of the eight phases, new moon being 0.
  var moonIndex: Int
  var lit: Int
  // The colours of the day's reminders, one for each category.
  var dots: [Int]

  // The system's own drawing of the phase.
  var moonSymbol: String {
    [
      "moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter",
      "moonphase.waxing.gibbous", "moonphase.full.moon", "moonphase.waning.gibbous",
      "moonphase.last.quarter", "moonphase.waning.crescent",
    ][max(0, min(7, moonIndex))]
  }
}

struct DayEntry: TimelineEntry {
  let date: Date
  // Nil when the app has not been opened recently enough to say.
  let day: CandraDay?
}

struct DayProvider: TimelineProvider {
  private static let sample = CandraDay(
    date: "2026-10-12", day: 12, month: "October", year: 2026, weekday: "Monday",
    sunday: false, weton: "Senin Pahing", pasaran: "Pahing", neptu: 13,
    hijriLabel: "HIJRI", hijriDay: "29 Rabi' al-Thani", hijriYear: "1448 AH",
    chineseLabel: "CHINESE", chineseDay: "3 Kau Gwee", chineseHanzi: "丙午年九月初三",
    zodiac: "Fire Horse", element: "Yin Earth", elementHanzi: "陰土",
    elementColor: 0xFFCF_A64E,
    javaneseLabel: "JAVANESE", javaneseDay: "29 Bakdamulud", javaneseYear: "1960 Be",
    wetonLabel: "WETON", moon: "Waxing Crescent", moonIndex: 1, lit: 3,
    dots: [0xFFD7_A16A, 0xFF6A_A0D7])

  private func stored() -> [CandraDay] {
    guard
      let text = UserDefaults(suiteName: CandraShared.group)?.string(forKey: CandraShared.daysKey),
      let data = text.data(using: .utf8),
      let days = try? JSONDecoder().decode([CandraDay].self, from: data)
    else { return [] }
    return days
  }

  private static let key: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  func placeholder(in context: Context) -> DayEntry {
    DayEntry(date: Date(), day: DayProvider.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
    let today = stored().first { $0.date == DayProvider.key.string(from: Date()) }
    completion(DayEntry(date: Date(), day: today ?? (context.isPreview ? DayProvider.sample : nil)))
  }

  // One entry for each day the app has told of, each from its midnight;
  // after the last, one that says to open the app.
  func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let days = stored()
    var entries: [DayEntry] = []
    for ahead in 0..<31 {
      guard let midnight = calendar.date(byAdding: .day, value: ahead, to: start) else { continue }
      let day = days.first { $0.date == DayProvider.key.string(from: midnight) }
      entries.append(DayEntry(date: ahead == 0 ? Date() : midnight, day: day))
      if day == nil { break }
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

private let paper = Color(red: 0.078, green: 0.09, blue: 0.106)
private let sundayRed = Color(red: 0.88, green: 0.38, blue: 0.25)

// The weekday alone keeps the app's fixed-width look; everything else in
// a widget is in the system's own face, as Apple's widgets are.
private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
  .system(size: size, weight: weight, design: .monospaced)
}

private func plain(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
  .system(size: size, weight: weight)
}

// The Chinese day in its Hokkien month, then the day's element in
// characters and in its colour: "4 Kau Gwee · 陽金".
private func chineseLine(_ day: CandraDay) -> Text {
  let element = Text(day.elementHanzi).foregroundColor(Color(argb: day.elementColor))
  return day.chineseDay.isEmpty ? element : Text("\(day.chineseDay) · ") + element
}

// MARK: The lock screen

// Three lines in the system's own face, as Apple's own widgets beside it
// are set: the weton, the Chinese day with the day's element, and the
// moon, with the system's drawing of its phase and in smaller type.
struct LockWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DayEntry

  var body: some View {
    if let day = entry.day {
      switch family {
      case .accessoryInline:
        Label(day.weton, systemImage: day.moonSymbol)
      default:
        VStack(alignment: .leading, spacing: 2) {
          Text(day.weton)
            .font(.headline)
            .widgetAccentable()
          chineseLine(day)
            .font(.subheadline)
          HStack(spacing: 4) {
            Image(systemName: day.moonSymbol)
            Text(day.moon)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    } else {
      Text("Open Candra")
    }
  }
}

struct CandraLockWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "CandraLock", provider: DayProvider()) { entry in
      LockWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Candra")
    .description("The weton, the Chinese day and its element, and the moon.")
    .supportedFamilies([.accessoryRectangular, .accessoryInline])
  }
}

// MARK: The home screen

// The tear-off sheet. Small: the date, the weekday, the weton, and the
// Chinese day with its element. Large: the whole sheet as the app's day
// view has it, every system in its corner, with the day's reminder dots.
struct SheetWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: DayEntry

  var body: some View {
    if let day = entry.day {
      if family == .systemLarge {
        large(day)
      } else {
        small(day)
      }
    } else {
      Text("Open Candra")
        .font(plain(12))
        .multilineTextAlignment(.center)
    }
  }

  private func ink(_ day: CandraDay) -> Color { day.sunday ? sundayRed : .primary }

  // The big number, with the same room above it as below: its figures
  // are sized to fill the height it is given less that room twice, and
  // set by their own top and foot, not by the typeface's line.
  private func number(_ day: CandraDay, gap: CGFloat) -> some View {
    GeometryReader { space in
      // The system face's figures stand about 0.72 of its size tall,
      // and two of them, bold, about 1.25 of it wide.
      let figures: CGFloat = 0.72
      let size = max(
        10, min((space.size.height - 2 * gap) / figures, space.size.width * 0.86 / 1.25))
      let face = UIFont.systemFont(ofSize: size, weight: .bold)
      // From the middle of the line to the middle of the figures.
      let lift = (face.ascender + face.descender - face.capHeight) / 2
      Text("\(day.day)")
        .font(plain(size, .bold))
        .monospacedDigit()
        .foregroundStyle(ink(day))
        .fixedSize()
        .offset(y: lift)
        .frame(width: space.size.width, height: space.size.height, alignment: .center)
    }
  }

  private func small(_ day: CandraDay) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text(day.month.uppercased())
        Spacer()
        Text(String(day.year))
      }
      .font(plain(10, .medium))
      .foregroundStyle(.secondary)
      number(day, gap: 5)
      Text(day.weekday.uppercased())
        .font(mono(11, .semibold))
        .kerning(2)
        .foregroundStyle(ink(day))
        .padding(.bottom, 2)
      Text(day.weton)
        .font(plain(11))
        .foregroundStyle(.secondary)
      chineseLine(day)
        .font(plain(11))
        .foregroundStyle(.secondary)
        .minimumScaleFactor(0.7)
    }
    .lineLimit(1)
  }

  private func corner(
    _ label: String, _ first: String, _ second: Text, _ trailing: Bool
  ) -> some View {
    VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
      Text(label)
        .font(plain(9, .medium))
        .kerning(1)
        .foregroundStyle(.tertiary)
      Text(first)
        .font(plain(14))
      second
        .font(plain(12))
    }
    .lineLimit(1)
    .minimumScaleFactor(0.7)
    .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
  }

  private func faint(_ text: String) -> Text {
    Text(text).foregroundColor(.secondary)
  }

  private func large(_ day: CandraDay) -> some View {
    VStack(spacing: 0) {
      // The head of the sheet.
      HStack {
        Text(day.month.uppercased())
        Spacer()
        Text(String(day.year))
      }
      .font(plain(17, .medium))
      .kerning(2)
      .foregroundStyle(.secondary)
      .padding(.bottom, 8)
      Divider()
      HStack(alignment: .top) {
        corner(day.hijriLabel, day.hijriDay, faint(day.hijriYear), false)
        // Under the Chinese day, its element in characters, coloured.
        corner(
          day.chineseLabel, day.chineseDay,
          Text(day.elementHanzi).foregroundColor(Color(argb: day.elementColor)), true)
      }
      .padding(.top, 10)
      // As far from the corners' last line as from the weekday.
      number(day, gap: 14)
      Text(day.weekday.uppercased())
        .font(mono(17))
        .kerning(6)
        .foregroundStyle(ink(day))
      // A dot for each category with a reminder today; the row keeps its
      // height when there are none.
      HStack(spacing: 6) {
        ForEach(Array(day.dots.enumerated()), id: \.offset) { dot in
          Circle().fill(Color(argb: dot.element)).frame(width: 6, height: 6)
        }
      }
      .frame(height: 18)
      HStack(alignment: .top) {
        corner(day.javaneseLabel, day.javaneseDay, faint(day.javaneseYear), false)
        corner(day.wetonLabel, day.weton, faint("neptu \(day.neptu)"), true)
      }
      .padding(.bottom, 10)
      Divider()
      // The foot: the moon, and the Chinese year.
      HStack(spacing: 5) {
        Image(systemName: day.moonSymbol)
        Text("\(day.moon) · \(day.lit)%")
        Spacer()
        Text(day.zodiac)
      }
      .font(plain(12))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.top, 8)
    }
  }
}

struct CandraDayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "CandraDay", provider: DayProvider()) { entry in
      SheetWidgetView(entry: entry)
        .containerBackground(paper, for: .widget)
    }
    .configurationDisplayName("Candra day sheet")
    .description("Today as a tear-off calendar sheet, in every calendar.")
    .supportedFamilies([.systemSmall, .systemLarge])
  }
}
