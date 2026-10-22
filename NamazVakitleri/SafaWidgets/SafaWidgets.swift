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

    private var backgroundView: some View { WidgetBackdrop(colorScheme: colorScheme) }

    var body: some View {
        content
            .foregroundStyle(AppTheme.textPrimary(colorScheme))
            .environment(\.colorScheme, colorScheme)
            .environment(\.layoutDirection, layoutDirection)
            .containerBackground(for: .widget) { backgroundView }
    }
}

// MARK: - 1) Sıradaki Namaz Widget'ı

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
            DailyFamilyView(entry: entry)
        }
    }
}

// MARK: - 3) Düzenli Aralıklarla Değişen Ayet Widget'ı

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
            AyahFamilyView(entry: entry)
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

/// Boyutu WidgetKit'ten okuyup ortak görünüme verir.
private struct DailyFamilyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry
    var body: some View { DailyPrayerListView(family: family, entry: entry) }
}

private struct AyahFamilyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AyahEntry
    var body: some View { AyahWidgetView(family: family, entry: entry) }
}
