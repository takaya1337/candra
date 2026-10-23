import ActivityKit
import Foundation

// What Candra has standing in the Dynamic Island and on the lock screen:
// a practice under way, and nothing else. Shared by the app, which starts
// and ends it, and the widget extension, which draws it.
@available(iOS 16.1, *)
struct CandraActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    // The category it is under, and what it is.
    var title: String
    var detail: String
    // The category's colour, as 0xAARRGGBB.
    var color: Int
    // When it began. A stopwatch counts up from here.
    var start: Date
    // When a countdown runs out; nil for a stopwatch.
    var end: Date?
  }
}

// The app group the app leaves the coming days in for the widgets, and
// the address a tap on the island opens the app with.
enum CandraShared {
  static let group = "group.com.suryamajapahit.candra.ios"
  static let daysKey = "days"
  static let practiceURL = URL(string: "candra://practice")!
}
