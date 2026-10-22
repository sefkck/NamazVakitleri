import AlarmKit
import SwiftUI
import WidgetKit

/// Gerçek alarm ertelenince (10 dk) kilit ekranı ve Dynamic Island'daki geri sayım.
struct PrayerAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<PrayerAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(context.attributes.tintColor)
                Text(context.attributes.presentation.alert.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 8)
                PrayerAlarmCountdown(state: context.state)
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.55))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PrayerAlarmCountdown(state: context.state)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                PrayerAlarmCountdown(state: context.state)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "alarm.fill").foregroundStyle(context.attributes.tintColor)
            }
        }
    }
}

struct PrayerAlarmCountdown: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let c):
            Text(timerInterval: Date.now...max(Date.now, c.fireDate), countsDown: true)
                .multilineTextAlignment(.trailing)
        case .paused(let p):
            Text(Duration.seconds(max(0, p.totalCountdownDuration - p.previouslyElapsedDuration)), format: .time(pattern: .minuteSecond))
        default:
            Image(systemName: "bell.fill")
        }
    }
}
