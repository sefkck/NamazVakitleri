import SwiftUI
import WidgetKit

/// Ana ekran: Günün Esmâ'sı. Her gece yarısı değişir; 7 gün önceden planlanır.
struct EsmaEntry: TimelineEntry {
    let date: Date
    let name: EsmaulHusna.Name
}

struct EsmaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EsmaEntry { EsmaEntry(date: Date(), name: EsmaulHusna.all[0]) }

    func getSnapshot(in context: Context, completion: @escaping (EsmaEntry) -> Void) {
        completion(EsmaEntry(date: Date(), name: EsmaulHusna.nameOfDay()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EsmaEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        var entries = [EsmaEntry(date: now, name: EsmaulHusna.nameOfDay(now))]
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(EsmaEntry(date: day, name: EsmaulHusna.nameOfDay(day)))
        }
        completion(Timeline(entries: entries, policy: .after(entries.last?.date ?? now.addingTimeInterval(86400))))
    }
}

struct SafaEsmaWidget: Widget {
    let kind: String = "SafaEsmaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EsmaTimelineProvider()) { entry in
            ThemedWidgetBackground {
                EsmaFamilyView(name: entry.name)
            }
        }
        .configurationDisplayName(LocalizationManager.tShared("widget_esma_name", fallback: "Günün İsmi"))
        .description(LocalizationManager.tShared("widget_esma_desc", fallback: "Allah'ın 99 isminden birini anlamıyla gösterir; her gün değişir."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct EsmaFamilyView: View {
    @Environment(\.widgetFamily) private var family
    let name: EsmaulHusna.Name

    var body: some View {
        EsmaWidgetView(name: name, language: LocalizationManager.sharedLanguage(), medium: family == .systemMedium)
    }
}
