import SwiftUI
import Adhan
import CoreLocation

/// İmsakiye: içinde bulunulan ya da sıradaki Ramazan'ın her günü için
/// vakitler (İmsak = sahurun bitişi, Akşam = iftar). Konum: ana sayfanın
/// son kullandığı konum.
struct ImsakiyeView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private struct Row: Identifiable {
        let id: Int
        let day: Date
        let times: DayPrayerTimes
    }

    private var location: (CLLocationCoordinate2D, TimeZone)? { NotificationManager.lastKnownLocation() }

    private var rows: [Row] {
        guard let (coordinate, tz) = location else { return [] }
        return RamadanInfo.ramadanDays(around: DebugClock.now, timeZone: tz).enumerated().compactMap { index, day in
            // Gün başına 12 saat ekleyerek konumun saat diliminde doğru günü al.
            guard let t = PrayerCalculation.times(on: day.addingTimeInterval(12 * 3600), coordinate: coordinate, timeZone: tz) else { return nil }
            return Row(id: index + 1, day: day, times: t)
        }
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = loc.locale
        f.timeZone = location?.1 ?? .current
        f.dateFormat = pattern
        return f.string(from: date)
    }

    private func isToday(_ row: Row) -> Bool {
        guard let tz = location?.1 else { return false }
        return PrayerTracker.dayKey(row.day.addingTimeInterval(12 * 3600), timeZone: tz) == PrayerTracker.dayKey(DebugClock.now, timeZone: tz)
    }

    var body: some View {
        NavigationView {
            Group {
                if rows.isEmpty {
                    Text(loc.t("tracking_no_location", fallback: "Vakitleri görmek için önce ana sayfayı bir kez aç."))
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ScrollViewReader { proxy in
                        List {
                            Section {
                                header
                                ForEach(rows) { row in
                                    rowView(row)
                                        .id(row.id)
                                        .listRowBackground(isToday(row) ? AppTheme.accentSoft(colorScheme) : AppTheme.cardFill(colorScheme))
                                }
                            } header: {
                                Text(rangeText)
                            } footer: {
                                Text(loc.t("imsakiye_footer", fallback: "Tarihler Hicri takvime göre hesaplanır; Diyanet'in ilanı bir gün farklı olabilir. Vakitler bulunduğun konuma göredir."))
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .onAppear {
                            if let today = rows.first(where: isToday) { proxy.scrollTo(today.id, anchor: .center) }
                        }
                    }
                }
            }
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle(loc.t("imsakiye_title", fallback: "İmsakiye"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .accessibilityLabel(loc.t("common_close", fallback: "Kapat"))
                }
            }
        }
    }

    private var rangeText: String {
        guard let first = rows.first, let last = rows.last else { return "" }
        let city = UserDefaults.standard.string(forKey: "lastKnownCityName") ?? ""
        let ramadan = loc.tf("imsakiye_ramadan_year", "Ramazan %@", format(first.day.addingTimeInterval(12 * 3600), "yyyy"))
        return "\(ramadan) · \(city) · \(format(first.day.addingTimeInterval(12 * 3600), "d MMM")) – \(format(last.day.addingTimeInterval(12 * 3600), "d MMM yyyy"))"
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text(loc.t("imsakiye_day", fallback: "Gün")).frame(maxWidth: .infinity, alignment: .leading)
            Text(loc.t("imsakiye_sahur", fallback: "İmsak")).frame(width: 52)
            Text(loc.t("imsakiye_iftar", fallback: "İftar")).frame(width: 52)
            Text(loc.x("Yatsı")).frame(width: 52)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(loc.tf("imsakiye_day_n", "%d. gün", row.id))
                    .font(.subheadline.weight(isToday(row) ? .bold : .regular))
                Text(format(row.day.addingTimeInterval(12 * 3600), "d MMM EEE"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(DisplayFormat.time(row.times.fajr, timeZone: location?.1 ?? .current, compact: true)).frame(width: 52)
            Text(DisplayFormat.time(row.times.maghrib, timeZone: location?.1 ?? .current, compact: true)).frame(width: 52).foregroundColor(AppTheme.accent)
            Text(DisplayFormat.time(row.times.isha, timeZone: location?.1 ?? .current, compact: true)).frame(width: 52)
        }
        .font(.subheadline.monospacedDigit())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ImsakiyeView()
}
