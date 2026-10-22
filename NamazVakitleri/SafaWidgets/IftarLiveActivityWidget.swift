import ActivityKit
import SwiftUI
import WidgetKit

/// Kilit ekranı ve Dynamic Island: "İftara kalan 02:14:33".
struct IftarLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IftarActivityAttributes.self) { context in
            IftarLockView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(IftarText.title(context.state.isIftar), systemImage: IftarText.icon(context.state.isIftar))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(DisplayFormat.time(context.state.target, timeZone: context.attributes.timeZone))
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IftarCountdown(state: context.state, isStale: context.isStale)
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                }
            } compactLeading: {
                Image(systemName: IftarText.icon(context.state.isIftar)).foregroundStyle(AppTheme.accent)
            } compactTrailing: {
                IftarCountdown(state: context.state, isStale: context.isStale)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: IftarText.icon(context.state.isIftar)).foregroundStyle(AppTheme.accent)
            }
        }
    }
}

enum IftarText {
    static func title(_ isIftar: Bool) -> String {
        isIftar ? LocalizationManager.tShared("live_iftar_left", fallback: "İftara kalan")
                : LocalizationManager.tShared("live_sahur_left", fallback: "Sahurun bitişine kalan")
    }

    static func icon(_ isIftar: Bool) -> String { isIftar ? "sunset.fill" : "moon.stars.fill" }
}

/// Hedef geçince sayaç 0'da durmasın: "Vakit girdi" yazar.
struct IftarCountdown: View {
    let state: IftarActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale || state.target <= Date() {
            Text(state.isIftar ? LocalizationManager.tShared("live_iftar_now", fallback: "İftar vakti")
                               : LocalizationManager.tShared("live_sahur_now", fallback: "İmsak vakti girdi"))
        } else {
            Text(timerInterval: state.start...state.target, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct IftarLockView: View {
    let context: ActivityViewContext<IftarActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: IftarText.icon(context.state.isIftar))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(IftarText.title(context.state.isIftar))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                IftarCountdown(state: context.state, isStale: context.isStale)
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(DisplayFormat.time(context.state.target, timeZone: context.attributes.timeZone))
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                Text(context.attributes.cityName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}
