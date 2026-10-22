import WidgetKit
import SwiftUI

// =============================================================
// BU DOSYA ANA UYGULAMA HEDEFİNE DEĞİL, "Widget Extension" HEDEFİNE
// EKLENMELİ. Kurulum adımları için önceki notlara bak (PrayerWidgetData.swift
// ve sohbet geçmişindeki adım adım talimatlar).
//
// Bu dosyada ÜÇ widget var:
// 1. SafaPrayerWidget - küçük/orta boy, sadece sıradaki namaz + geri sayım
// 2. SafaDailyPrayerWidget - orta/büyük boy, GÜNÜN TÜM vakitlerini listeler
// 3. SafaAyahWidget - küçük/orta boy, her birkaç saatte bir DEĞİŞEN bir ayet
//    gösterir (telefon kilitliyken bile, uygulama hiç açılmasa da -
//    WidgetKit'in "timeline" özelliği sayesinde)
// =============================================================

// MARK: - Ortak: tema farkına duyarlı arka plan + hafif degrade derinlik

/// Widget'ın arka planını VE yazı renklerini uygulamanın kendi
/// Aydınlık/Karanlık temasına göre ayarlayan sarmalayıcı. Düz tek renk
/// yerine köşede hafif bir altın/bordo degrade ile derinlik katıyor -
/// "premium" hissi büyük ölçüde buradan geliyor.
struct ThemedWidgetBackground<Content: View>: View {
    @Environment(\.colorScheme) private var systemColorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// Uygulamada seçilen tema (Ayarlar > Görünüm). Hiç seçilmediyse
    /// sistemin görünümü kullanılır.
    private var colorScheme: ColorScheme {
        guard let isDark = PrayerWidgetData.storedDarkTheme() else { return systemColorScheme }
        return isDark ? .dark : .light
    }

    private var layoutDirection: LayoutDirection {
        LocalizationManager.sharedLanguage().isRightToLeft ? .rightToLeft : .leftToRight
    }

    private var backgroundView: some View {
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

    var body: some View {
        content
            .foregroundStyle(AppTheme.textPrimary(colorScheme))
            .environment(\.colorScheme, colorScheme)
            .environment(\.layoutDirection, layoutDirection)
            .containerBackground(for: .widget) { backgroundView }
    }
}

/// Namaz vakti adına göre uygun bir SF Symbol ikon döndürür ("Yarın
/// İmsak" gibi önekli isimleri de yakalar).
private func prayerIcon(for name: String) -> String {
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
private struct IconBadge: View {
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

// MARK: - 1) Sıradaki Namaz Widget'ı

struct PrayerEntry: TimelineEntry {
    let date: Date
    let nextPrayerName: String
    let nextPrayerDate: Date?
    let cityName: String
    let dailyTimes: [PrayerWidgetData.DailyPrayerTime]
    /// Vakitlerin gösterileceği saat dilimi (uygulamada seçili konumunki).
    var timeZone: TimeZone = .current
}

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), nextPrayerName: "İkindi", nextPrayerDate: Date().addingTimeInterval(3600), cityName: "Antalya Kepez", dailyTimes: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(buildEntries().first ?? fallbackEntry())
    }

    /// Uygulama birkaç günlük vakti önceden kaydediyor. Widget, her vakit
    /// geçişinde ve her gece yarısında devreye girecek girişleri bu
    /// listeden kendisi üretiyor. Böylece uygulama birkaç gün hiç
    /// açılmasa da doğru günü ve doğru "sıradaki namaz"ı gösteriyor.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entries = buildEntries()
        guard let last = entries.last else {
            completion(Timeline(entries: [fallbackEntry()], policy: .after(Date().addingTimeInterval(30 * 60))))
            return
        }
        // Kaydedilmiş veri bitince (son girişin zamanı) yeniden dene.
        let refreshDate = max(last.date, Date().addingTimeInterval(15 * 60))
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    func buildEntries(now: Date = Date()) -> [PrayerEntry] {
        guard let snapshot = PrayerWidgetData.load() else { return [] }
        return PrayerWidgetData.timelineSteps(from: snapshot, now: now).map { step in
            PrayerEntry(
                date: step.date,
                nextPrayerName: step.nextName,
                nextPrayerDate: step.nextDate,
                cityName: snapshot.cityName,
                dailyTimes: step.today,
                timeZone: snapshot.timeZone
            )
        }
    }

    private func fallbackEntry() -> PrayerEntry {
        PrayerEntry(date: Date(), nextPrayerName: LocalizationManager.tShared("widget_open_app", fallback: "Uygulamayı Açın"), nextPrayerDate: nil, cityName: LocalizationManager.tShared("widget_waiting", fallback: "Veri bekleniyor"), dailyTimes: [])
    }
}

struct SmallPrayerWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IconBadge(systemName: prayerIcon(for: entry.nextPrayerName), size: 28)
                Text(LocalizationManager.tShared("home_next_prayer", fallback: "Sıradaki Namaz"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    .lineLimit(1)
            }

            Text(LocalizationManager.xShared(entry.nextPrayerName))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Spacer(minLength: 2)

            if let date = entry.nextPrayerDate {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date, style: .timer)
                        .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text(date, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                        .environment(\.timeZone, entry.timeZone)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.accentSoft(colorScheme))
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MediumPrayerWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconBadge(systemName: prayerIcon(for: entry.nextPrayerName), size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizationManager.tShared("home_next_prayer", fallback: "Sıradaki Namaz"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    Text(LocalizationManager.xShared(entry.nextPrayerName))
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 0)
            }

            if let date = entry.nextPrayerDate {
                HStack(spacing: 6) {
                    Text(date, style: .timer)
                        .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("·")
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    Text(date, style: .time)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                        .environment(\.timeZone, entry.timeZone)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.accentSoft(colorScheme))
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct SafaPrayerWidget: Widget {
    let kind: String = "SafaPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            contentView(for: entry)
        }
        .configurationDisplayName(LocalizationManager.tShared("widget_next_name", fallback: "Sıradaki Namaz"))
        .description(LocalizationManager.tShared("widget_next_desc", fallback: "Sıradaki namaz vaktini ve geri sayımı ana ekranında gösterir."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    @ViewBuilder
    private func contentView(for entry: PrayerEntry) -> some View {
        ThemedWidgetBackground {
            SmallOrMediumView(entry: entry)
        }
    }
}

private struct SmallOrMediumView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumPrayerWidgetView(entry: entry)
        default:
            SmallPrayerWidgetView(entry: entry)
        }
    }
}

// MARK: - 2) Günün Tüm Vakitleri Widget'ı (standart liste)

struct SafaDailyPrayerWidget: Widget {
    let kind: String = "SafaDailyPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            contentView(for: entry)
        }
        .configurationDisplayName(LocalizationManager.tShared("widget_daily_name", fallback: "Günün Namaz Vakitleri"))
        .description(LocalizationManager.tShared("widget_daily_desc", fallback: "İmsak'tan Yatsı'ya günün tüm namaz vakitlerini liste halinde gösterir."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }

    @ViewBuilder
    private func contentView(for entry: PrayerEntry) -> some View {
        ThemedWidgetBackground {
            DailyPrayerListView(entry: entry)
        }
    }
}

struct DailyPrayerListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = entry.timeZone
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.accent)
                Text(entry.cityName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                Spacer()
                Text(LocalizationManager.tShared("widget_today", fallback: "BUGÜN"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
            }

            if entry.dailyTimes.isEmpty {
                Spacer()
                Text(LocalizationManager.tShared("widget_open_hint", fallback: "Namaz vakitleri için uygulamayı bir kez aç."))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary(colorScheme))
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(entry.dailyTimes, id: \.name) { prayer in
                        let isNext = prayer.name == entry.nextPrayerName

                        HStack(spacing: 10) {
                            Image(systemName: prayerIcon(for: prayer.name))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isNext ? .white : AppTheme.gold)
                                .frame(width: 22)

                            Text(LocalizationManager.xShared(prayer.name))
                                .font(.system(size: 14, weight: isNext ? .bold : .regular))
                                .foregroundStyle(isNext ? .white : AppTheme.textPrimary(colorScheme))

                            Spacer()

                            Text(DisplayFormat.time(prayer.time, timeZone: entry.timeZone, compact: true))
                                .font(.system(size: 14, weight: isNext ? .bold : .regular).monospacedDigit())
                                .foregroundStyle(isNext ? .white : AppTheme.textSecondary(colorScheme))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isNext ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(Color.clear))
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - 3) Düzenli Aralıklarla Değişen Ayet Widget'ı

struct AyahEntry: TimelineEntry {
    let date: Date
    let reference: String
    let text: String
}

struct AyahTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AyahEntry {
        let first = AyahPool.localizedShared()[0]
        return AyahEntry(date: Date(), reference: first.reference, text: first.text)
    }

    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        let verse = AyahPool.localizedShared().randomElement() ?? AyahPool.localizedShared()[0]
        completion(AyahEntry(date: Date(), reference: verse.reference, text: verse.text))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {
        // Her 4 saatte bir farklı (karıştırılmış) bir ayet gösterilecek
        // şekilde önceden birkaç giriş planlıyoruz - uygulama hiç
        // açılmasa bile WidgetKit bunları otomatik sırayla gösterir.
        let calendar = Calendar.current
        let now = Date()
        let shuffled = AyahPool.localizedShared().shuffled()
        var entries: [AyahEntry] = []

        for (index, verse) in shuffled.enumerated() {
            let entryDate = calendar.date(byAdding: .hour, value: index * 4, to: now) ?? now
            entries.append(AyahEntry(date: entryDate, reference: verse.reference, text: verse.text))
        }

        let nextRefresh = entries.last?.date.addingTimeInterval(4 * 3600) ?? now.addingTimeInterval(4 * 3600)
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }
}

struct AyahWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                .font(.system(size: 14, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(AppTheme.textPrimary(colorScheme))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Rectangle()
                .fill(AppTheme.gold.opacity(0.4))
                .frame(height: 1)

            Text(entry.reference.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(AppTheme.textSecondary(colorScheme))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct SafaAyahWidget: Widget {
    let kind: String = "SafaAyahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AyahTimelineProvider()) { entry in
            contentView(for: entry)
        }
        .configurationDisplayName(LocalizationManager.tShared("widget_ayah_name", fallback: "Günün Ayeti"))
        .description(LocalizationManager.tShared("widget_ayah_desc", fallback: "Her birkaç saatte bir değişen kısa bir ayet gösterir."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    @ViewBuilder
    private func contentView(for entry: AyahEntry) -> some View {
        ThemedWidgetBackground {
            AyahWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle (hepsini topluyor)

// MARK: - 4) Kilit Ekranı Widget'ı (sıradaki namaz)

struct SafaLockScreenWidget: Widget {
    let kind: String = "SafaLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            LockScreenEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(LocalizationManager.tShared("lock_widget_name", fallback: "Sıradaki Namaz (Kilit Ekranı)"))
        .description(LocalizationManager.tShared("lock_widget_desc", fallback: "Kilit ekranında sıradaki namazı ve kalan süreyi gösterir."))
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct LockScreenEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            LockInlinePrayerView(prayerName: entry.nextPrayerName, prayerDate: entry.nextPrayerDate, timeZone: entry.timeZone)
        case .accessoryCircular:
            LockCircularPrayerView(prayerName: entry.nextPrayerName, prayerDate: entry.nextPrayerDate, timeZone: entry.timeZone)
        default:
            LockRectangularPrayerView(prayerName: entry.nextPrayerName, prayerDate: entry.nextPrayerDate, timeZone: entry.timeZone, cityName: entry.cityName)
        }
    }
}

@main
struct SafaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SafaPrayerWidget()
        SafaLockScreenWidget()
        SafaDailyPrayerWidget()
        SafaAyahWidget()
        SafaEsmaWidget()
        IftarLiveActivityWidget()
        PrayerAlarmLiveActivity()
    }
}
