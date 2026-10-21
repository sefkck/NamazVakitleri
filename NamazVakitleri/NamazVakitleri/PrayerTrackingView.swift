import SwiftUI
import Adhan

/// "Namaz Takibi": bugün kılınan vakitler, üst üste tamamlanan gün sayısı
/// (seri), son 7 gün ve kaza namazı sayaçları. Veriler sadece cihazda.
struct PrayerTrackingView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// Ekranı yenilemek için (kayıt değişince artar).
    @State private var refresh = 0

    private var timeZone: TimeZone { NotificationManager.lastKnownLocation()?.1 ?? .current }

    /// Bugünün vakitleri (vakti girmemiş namaz işaretlenemez).
    private var todayTimes: [(name: String, date: Date)] {
        guard let (coordinate, tz) = NotificationManager.lastKnownLocation(),
              let t = PrayerCalculation.times(on: Date(), coordinate: coordinate, timeZone: tz) else { return [] }
        return [("İmsak", t.fajr), ("Öğle", t.dhuhr), ("İkindi", t.asr), ("Akşam", t.maghrib), ("Yatsı", t.isha)]
    }

    private var lastSevenDays: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        NavigationView {
            List {
                todaySection
                streakSection
                kazaSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle(loc.t("tracking_title", fallback: "Namaz Takibi"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .accessibilityLabel(loc.t("common_close", fallback: "Kapat"))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: PrayerTracker.didChange)) { _ in refresh += 1 }
            .safeAreaInset(edge: .bottom) { undoBar }
        }
    }

    // MARK: - Bugün

    /// Yanlış dokunuşu geri almak için ~4 sn görünen "Sabah kılındı · Geri Al" çubuğu.
    private struct UndoInfo: Equatable { let name: String; let dayKey: String; let nowPrayed: Bool; let id: Int }
    @State private var undo: UndoInfo?

    private func showUndo(name: String, dayKey: String, nowPrayed: Bool) {
        let info = UndoInfo(name: name, dayKey: dayKey, nowPrayed: nowPrayed, id: (undo?.id ?? 0) + 1)
        withAnimation { undo = info }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if undo == info { withAnimation { undo = nil } }
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let u = undo {
            HStack(spacing: 12) {
                Text(loc.tf(u.nowPrayed ? "tracking_marked" : "tracking_unmarked",
                            u.nowPrayed ? "%@ kılındı olarak işaretlendi" : "%@ işareti kaldırıldı",
                            PrayerTracker.namazName(u.name)))
                    .font(AppTheme.body(14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Button(loc.t("common_undo", fallback: "Geri Al")) {
                    PrayerTracker.setPrayed(!u.nowPrayed, name: u.name, dayKey: u.dayKey)
                    withAnimation { undo = nil }
                }
                .font(AppTheme.body(14, weight: .bold))
                .foregroundColor(AppTheme.gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.85)))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var todaySection: some View {
        let key = PrayerTracker.dayKey(Date(), timeZone: timeZone)
        return Section {
            if todayTimes.isEmpty {
                Text(loc.t("tracking_no_location", fallback: "Vakitleri görmek için önce ana sayfayı bir kez aç."))
                    .foregroundStyle(.secondary)
            }
            ForEach(todayTimes, id: \.name) { item in
                let prayed = PrayerTracker.isPrayed(item.name, dayKey: key)
                let started = item.date <= Date()
                Button {
                    PrayerTracker.setPrayed(!prayed, name: item.name, dayKey: key)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showUndo(name: item.name, dayKey: key, nowPrayed: !prayed)
                } label: {
                    HStack {
                        Image(systemName: prayed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(prayed ? AppTheme.accent : (started ? .secondary : Color.secondary.opacity(0.35)))
                        Text(PrayerTracker.namazName(item.name))
                            .foregroundColor(AppTheme.textPrimary(colorScheme))
                        Spacer()
                        Text(started ? (prayed ? loc.t("tracking_prayed", fallback: "Kılındı") : loc.t("tracking_not_prayed", fallback: "Kılınmadı"))
                                     : loc.t("tracking_not_yet", fallback: "Vakti girmedi"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!started)
            }
        } header: {
            Text(loc.tf("tracking_today", "Bugün · %d/5", PrayerTracker.prayedCount(dayKey: key)) + (refresh < 0 ? "" : ""))
        } footer: {
            Text(loc.t("tracking_today_footer", fallback: "Bildirimdeki ya da alarm ekranındaki \"Kıldım\" düğmesi de buraya kaydeder."))
        }
    }

    // MARK: - Seri ve son 7 gün

    private var streakSection: some View {
        let streak = PrayerTracker.streak(timeZone: timeZone)
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = loc.locale
            f.timeZone = timeZone
            f.dateFormat = "EEE"
            return f
        }()
        return Section {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(streak > 0 ? .orange : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.tf("tracking_streak", "%d gün üst üste", streak))
                        .font(.headline)
                    Text(loc.t("tracking_streak_sub", fallback: "5 vaktin hepsinin kılındığı ardışık günler"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 0) {
                ForEach(lastSevenDays, id: \.self) { day in
                    let count = PrayerTracker.prayedCount(dayKey: PrayerTracker.dayKey(day, timeZone: timeZone))
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: CGFloat(count) / 5)
                                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(count)")
                                .font(.caption2.weight(.semibold))
                        }
                        .frame(width: 30, height: 30)
                        Text(formatter.string(from: day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(loc.tf("tracking_day_a11y", "%@: %d/5 kılındı", formatter.string(from: day), count))
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(loc.t("tracking_last7", fallback: "Son 7 gün"))
        }
    }

    // MARK: - Kaza

    private var kazaSection: some View {
        Section {
            ForEach(PrayerTracker.kazaNames, id: \.self) { name in
                let count = PrayerTracker.kazaCount(name)
                Stepper(value: Binding(
                    get: { count },
                    set: { PrayerTracker.setKazaCount($0, for: name) }
                ), in: 0...99_999) {
                    HStack {
                        Text(PrayerTracker.namazName(name))
                        Spacer()
                        Text("\(count)")
                            .monospacedDigit()
                            .foregroundStyle(count > 0 ? AppTheme.accent : .secondary)
                    }
                }
            }
        } header: {
            Text(loc.tf("tracking_kaza", "Kaza namazları · toplam %d", PrayerTracker.totalKaza))
        } footer: {
            Text(loc.t("tracking_kaza_footer", fallback: "Borcun olan kaza namazlarını + ile ekle. Kaza kıldıkça − ile azalt."))
        }
    }
}

#Preview {
    PrayerTrackingView()
}
