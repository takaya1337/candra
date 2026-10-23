import SwiftUI
import WidgetKit

@main
struct CandraWidgetsBundle: WidgetBundle {
  var body: some Widget {
    CandraLockWidget()
    CandraDayWidget()
    CandraLiveActivity()
  }
}

extension Color {
  // From 0xAARRGGBB, as Flutter writes a colour.
  init(argb: Int) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: Double((argb >> 24) & 0xFF) / 255)
  }
}
