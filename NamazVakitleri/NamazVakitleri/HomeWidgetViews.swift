import SwiftUI
import WidgetKit

// Ana ekran widget'larının görünümleri. Hem widget hedefinde hem uygulamada
// derlenir: uygulama tarafı sadece DEBUG'da, widget'ları açık/koyu temada
// test ekranında çizmek için kullanır (-uiSheet widgetGallery).

/// Widget arka planı: tema rengi + köşelerde hafif bordo/altın degrade.
struct WidgetBackdrop: View {
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            AppTheme.background(colorScheme)
            LinearGradient(
                colors: [AppTheme.accent.opacity(colorScheme == .dark ? 0.16 : 0.08), .clear],
                startPoint: .topTrailing,
                endPoint: .center
            )
            LinearGradient(
                colors: [AppTheme.gold.opacity(colorScheme == .dark ? 0.10 : 0.06), .clear],
                startPoint: .bottomLeading,
                endPoint: .center
            )
        }
    }
}

/// Namaz vakti adına göre uygun bir SF Symbol ikon döndürür ("Yarın
/// İmsak" gibi önekli isimleri de yakalar).
func prayerIcon(for name: String) -> String {
    if name.contains("İmsak") { return "moon.stars.fill" }
    if name.contains("Güneş") { return "sunrise.fill" }
    if name.contains("Öğle") { return "sun.max.fill" }
    if name.contains("İkindi") { return "sun.haze.fill" }
    if name.contains("Akşam") { return "sunset.fill" }
    if name.contains("Yatsı") { return "moon.fill" }
    return "clock.fill"
}

/// Küçük, degrade dolgulu, ikonlu rozet - başlıkların yanında dekoratif
/// olarak kullanılıyor.
struct IconBadge: View {
    let systemName: String
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.gold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: AppTheme.accent.opacity(0.35), radius: 4, y: 2)
    }
}


struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerDate: Date?
    let cityName: String
    let dailyTimes: [PrayerWidgetData.DailyPrayerTime]
    /// Vakitlerin gösterileceği saat dilimi (uygulamada seçili konumunki).
    var timeZone: TimeZone = .current
}


/// Seçili dile göre büyük harf ("SIRADAKİ NAMAZ"; Türkçede i → İ).
func widgetUpper(_ s: String) -> String {
    s.uppercased(with: LocalizationManager.sharedLanguage().locale)
}

func nextCaption() -> String {
    widgetUpper(LocalizationManager.tShared("home_next_prayer", fallback: "Sıradaki Namaz"))
}

struct SmallPrayerWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                IconBadge(systemName: prayerIcon(for: entry.nextPrayerName), size: 30)
                Spacer(minLength: 4)
                if let date = entry.nextPrayerDate {
                    Text(DisplayFormat.time(date, timeZone: entry.timeZone, compact: true))
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                }
            }

            Spacer(minLength: 6)

            Text(nextCaption())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(LocalizationManager.xShared(entry.nextPrayerName))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Spacer(minLength: 6)

            if let date = entry.nextPrayerDate {
                Text(date, style: .timer)
                    .font(.system(size: 19, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 11).fill(AppTheme.accentSoft(colorScheme)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Günün altı vakti yan yana; sıradaki vakit renkli kapsül içinde.
struct PrayerStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        HStack(spacing: 4) {
            ForEach(entry.dailyTimes, id: \.name) { prayer in
                let isNext = prayer.name == entry.nextPrayerName
                VStack(spacing: 2) {
                    Image(systemName: prayerIcon(for: prayer.name))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isNext ? .white : AppTheme.gold)
                    Text(LocalizationManager.xShared(prayer.name))
                        .font(.system(size: 9.5, weight: isNext ? .bold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(DisplayFormat.time(prayer.time, timeZone: entry.timeZone, compact: true))
                        .font(.system(size: 12, weight: isNext ? .bold : .semibold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(isNext ? .white : AppTheme.textPrimary(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isNext ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(AppTheme.accentSoft(colorScheme).opacity(0.6)))
                )
            }
        }
    }
}

struct MediumPrayerWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                IconBadge(systemName: prayerIcon(for: entry.nextPrayerName), size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(nextCaption())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                        .lineLimit(1)
                    Text(LocalizationManager.xShared(entry.nextPrayerName))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 6)
                if let date = entry.nextPrayerDate {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(date, style: .timer)
                            .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(entry.cityName)
                            .font(.system(size: 10.5))
                            .foregroundStyle(AppTheme.textSecondary(colorScheme))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 120, alignment: .trailing)
                }
            }

            if entry.dailyTimes.isEmpty {
                Text(LocalizationManager.tShared("widget_open_hint", fallback: "Namaz vakitleri için uygulamayı bir kez aç."))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
            } else {
                PrayerStrip(entry: entry)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}


struct DailyPrayerListView: View {
    @Environment(\.colorScheme) private var colorScheme
    var family: WidgetFamily = .systemMedium
    let entry: PrayerEntry

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.accent)
            Text(entry.cityName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(LocalizationManager.tShared("widget_today", fallback: "BUGÜN"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
        }
    }

    private func row(_ prayer: PrayerWidgetData.DailyPrayerTime, size: CGFloat, vertical: CGFloat) -> some View {
        let isNext = prayer.name == entry.nextPrayerName
        return HStack(spacing: 8) {
            Image(systemName: prayerIcon(for: prayer.name))
                .font(.system(size: size - 1, weight: .medium))
                .foregroundStyle(isNext ? .white : AppTheme.gold)
                .frame(width: family == .systemLarge ? size + 6 : size + 2)
            // Ad önce kendi genişliğini alır (yoksa HStack onu küçültüyordu); saat hiç kesilmez.
            Text(LocalizationManager.xShared(prayer.name))
                .font(.system(size: size, weight: isNext ? .bold : .regular))
                .foregroundStyle(isNext ? .white : AppTheme.textPrimary(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
            Spacer(minLength: 2)
            Text(DisplayFormat.time(prayer.time, timeZone: entry.timeZone, compact: true))
                .font(.system(size: size, weight: isNext ? .bold : .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(isNext ? .white : AppTheme.textSecondary(colorScheme))
                .fixedSize()
                .layoutPriority(2)
        }
        .padding(.horizontal, family == .systemLarge ? 9 : 6)
        .padding(.vertical, vertical)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isNext ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(Color.clear))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 8) {
            header
            if entry.dailyTimes.isEmpty {
                Spacer()
                Text(LocalizationManager.tShared("widget_open_hint", fallback: "Namaz vakitleri için uygulamayı bir kez aç."))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                Spacer()
            } else if family == .systemLarge {
                if let date = entry.nextPrayerDate {
                    HStack(spacing: 12) {
                        IconBadge(systemName: prayerIcon(for: entry.nextPrayerName), size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(nextCaption())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(AppTheme.textSecondary(colorScheme))
                                .lineLimit(1)
                                .fixedSize()
                            Text(LocalizationManager.xShared(entry.nextPrayerName))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 4)
                        Text(date, style: .timer)
                            .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: 96, alignment: .trailing)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.accentSoft(colorScheme)))
                }
                VStack(spacing: 2) {
                    ForEach(entry.dailyTimes, id: \.name) { row($0, size: 15, vertical: 8) }
                }
                Spacer(minLength: 0)
            } else {
                // Orta boy: altı vakit iki sütunda (3 + 3) — eskiden tek sütunda sığmıyordu.
                let half = (entry.dailyTimes.count + 1) / 2
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 3) { ForEach(entry.dailyTimes.prefix(half), id: \.name) { row($0, size: 13, vertical: 5) } }
                    VStack(spacing: 3) { ForEach(entry.dailyTimes.dropFirst(half), id: \.name) { row($0, size: 13, vertical: 5) } }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}


struct AyahEntry: TimelineEntry {
    let date: Date
    let reference: String
    let text: String
}


struct AyahWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    var family: WidgetFamily = .systemSmall
    let entry: AyahEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.gold)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.gold.opacity(0.6))
            }

            Text(entry.text)
                .font(.system(size: family == .systemSmall ? 13 : 15, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(family == .systemSmall ? 5 : 4)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            Rectangle()
                .fill(AppTheme.gold.opacity(0.4))
                .frame(height: 1)

            Text(widgetUpper(entry.reference))
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

