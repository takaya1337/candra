import ActivityKit
import SwiftUI
import WidgetKit

// The Dynamic Island and its banner on the lock screen: a practice under
// way. The app's own mark on one side, the clock on the other, each at
// the middle of its own half; a tap opens the practice.
struct CandraLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CandraActivityAttributes.self) { context in
      // The lock screen, and phones without an island.
      HStack(spacing: 12) {
        Mark(state: context.state, size: 30)
        VStack(alignment: .leading, spacing: 2) {
          Text(context.state.title)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
          Text(context.state.detail)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        Spacer()
        Clock(state: context.state)
          .font(.system(size: 26, weight: .bold, design: .monospaced))
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 130, alignment: .trailing)
      }
      .padding(16)
      .activityBackgroundTint(Color(red: 0.078, green: 0.09, blue: 0.106))
      .activitySystemActionForegroundColor(.white)
      .widgetURL(CandraShared.practiceURL)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Mark(state: context.state, size: 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Clock(state: context.state)
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.title)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.detail)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      } compactLeading: {
        // A fixed width with the mark at its middle, so it stands clear
        // of the island's edge.
        Mark(state: context.state, size: 20)
          .frame(width: 44, alignment: .center)
      } compactTrailing: {
        Clock(state: context.state)
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .multilineTextAlignment(.center)
          .frame(width: 64, alignment: .center)
      } minimal: {
        Mark(state: context.state, size: 18)
      }
      .keylineTint(Color(argb: context.state.color))
      .widgetURL(CandraShared.practiceURL)
    }
  }
}

// Candra's own mark, the crescent in its rings, in the category's colour.
private struct Mark: View {
  let state: CandraActivityAttributes.ContentState
  let size: CGFloat

  var body: some View {
    Image("Mark")
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .foregroundStyle(Color(argb: state.color))
  }
}

// A stopwatch counts up from its start; a countdown, down to its end.
// The phone keeps the figures turning by itself, with the app closed.
private struct Clock: View {
  let state: CandraActivityAttributes.ContentState

  var body: some View {
    Group {
      if let end = state.end {
        if end > Date() {
          Text(timerInterval: Date()...end, countsDown: true)
        } else {
          Text("0:00")
        }
      } else {
        Text(timerInterval: state.start...Date.distantFuture, countsDown: false)
      }
    }
    .monospacedDigit()
    .foregroundStyle(Color(argb: state.color))
  }
}
