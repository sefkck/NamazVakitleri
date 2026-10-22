import SwiftUI
import UniformTypeIdentifiers
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
                fastingSection
                backupSection
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
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), let p = try? TrackingBackup.decode(data) {
                    pendingRestore = p
                } else {
                    backupMessage = loc.t("backup_invalid", fallback: "Bu dosya bir Safa yedeği değil.")
                }
            }
            .alert(loc.t("backup_confirm_title", fallback: "Yedek geri yüklensin mi?"),
                   isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                   presenting: pendingRestore) { p in
                Button(loc.t("backup_restore", fallback: "Geri Yükle"), role: .destructive) {
                    TrackingBackup.apply(p)
                    backupMessage = loc.t("backup_done", fallback: "Yedek geri yüklendi.")
                }
                Button(loc.t("common_cancel", fallback: "Vazgeç"), role: .cancel) {}
            } message: { p in
                Text(loc.tf("backup_confirm_msg", "%d günlük namaz kaydı ve %d kaza bulundu. Bu telefondaki kayıtların yerine yazılacak.",
                            p.prayerLog.count, p.kaza.values.reduce(0, +)))
            }
            .alert(backupMessage ?? "", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
                Button(loc.t("common_ok", fallback: "Tamam"), role: .cancel) {}
            }
        }
    }

    // MARK: - Yedekleme

    @State private var importing = false
    @State private var pendingRestore: TrackingBackup.Payload?
    @State private var backupMessage: String?

    private var backupSection: some View {
        Section {
            ShareLink(item: TrackingBackupFile(), preview: SharePreview(loc.t("backup_file_name", fallback: "Safa yedeği"))) {
                Label(loc.t("backup_export", fallback: "Kayıtları dosyaya yedekle"), systemImage: "square.and.arrow.up")
            }
            Button { importing = true } label: {
                Label(loc.t("backup_import", fallback: "Yedekten geri yükle"), systemImage: "square.and.arrow.down")
            }
        } header: {
            Text(loc.t("backup_title", fallback: "Yedekleme"))
        } footer: {
            Text(loc.t("backup_footer", fallback: "Kıldım kayıtları, özel günler, kazalar ve zikir sayıları tek bir dosyaya yazılır. Dosyayı Dosyalar'a, iCloud Drive'a ya da kendine mesajla kaydedebilirsin; yeni telefonda buradan geri yükle. Dosya sadece senin seçtiğin yere gider."))
        }
        .tint(AppTheme.accent)
    }

    // MARK: - Bugün

    /// Yanlış dokunuşu geri almak için ~10 sn görünen "Sabah kılındı · Geri Al" satırı (yaşlı kullanıcılar da yetişsin).
    private struct UndoInfo: Equatable { let name: String; let dayKey: String; let nowPrayed: Bool; let id: Int }
    @State private var undo: UndoInfo?

    private func showUndo(name: String, dayKey: String, nowPrayed: Bool) {
        let info = UndoInfo(name: name, dayKey: dayKey, nowPrayed: nowPrayed, id: (undo?.id ?? 0) + 1)
        withAnimation { undo = info }
        let text = loc.tf(nowPrayed ? "tracking_marked" : "tracking_unmarked",
                          nowPrayed ? "%@ kılındı olarak işaretlendi" : "%@ işareti kaldırıldı", PrayerTracker.namazName(name))
        UIAccessibility.post(notification: .announcement, argument: text)
        // VoiceOver açıkken "Geri Al"a ulaşmak daha uzun sürer.
        let delay: Double = UIAccessibility.isVoiceOverRunning ? 30 : 10
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if undo == info { withAnimation { undo = nil } }
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let u = undo {
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward.circle.fill").foregroundColor(AppTheme.accent)
                Text(loc.tf(u.nowPrayed ? "tracking_marked" : "tracking_unmarked",
                            u.nowPrayed ? "%@ kılındı olarak işaretlendi" : "%@ işareti kaldırıldı",
                            PrayerTracker.namazName(u.name)))
                    .font(AppTheme.body(14, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                Spacer(minLength: 4)
                Button(loc.t("common_undo", fallback: "Geri Al")) {
                    PrayerTracker.setPrayed(!u.nowPrayed, name: u.name, dayKey: u.dayKey)
                    withAnimation { undo = nil }
                }
                .font(AppTheme.body(15, weight: .bold))
                .foregroundColor(AppTheme.accent)
                .buttonStyle(.borderless)
            }
            .listRowBackground(AppTheme.accentSoft(colorScheme))
            .transition(.opacity)
        }
    }


    private var todaySection: some View {
        let key = PrayerTracker.dayKey(Date(), timeZone: timeZone)
        return Section {
            if todayTimes.isEmpty {
                Text(loc.t("tracking_no_location", fallback: "Vakitleri görmek için önce ana sayfayı bir kez aç."))
                    .foregroundStyle(.secondary)
            }
            // Özel gün (kadınlar): o gün namazdan muaf, seri bozulmaz.
            Toggle(isOn: Binding(
                get: { PrayerTracker.isExcused(dayKey: key) },
                set: { PrayerTracker.setExcused($0, dayKey: key) }
            )) {
                Label(loc.t("tracking_excused", fallback: "Bugün özel gün (namazdan muafım)"), systemImage: "moon.zzz")
            }
            .tint(AppTheme.accent)
            .id("excused-\(refresh)")
            if !PrayerTracker.isExcused(dayKey: key) {
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
                .id("today-\(item.name)-\(refresh)")
            }
            }
            // Geri Al satırı vakitlerin hemen altında: kaza düğmelerinin üstüne
            // binmesin (çubuk kaybolurken dokunuş alttaki "+"ya gidiyordu).
            if undo != nil { undoBar }
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
                    let dk = PrayerTracker.dayKey(day, timeZone: timeZone)
                    let count = PrayerTracker.prayedCount(dayKey: dk)
                    let excused = PrayerTracker.isExcused(dayKey: dk)
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: excused ? 0 : CGFloat(count) / 5)
                                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            if excused {
                                Image(systemName: "moon.zzz").font(.caption2)
                            } else {
                                Text("\(count)")
                                    .font(.caption2.weight(.semibold))
                            }
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

    // MARK: - Kaza orucu

    private var fastingSection: some View {
        let name = PrayerTracker.fastingKazaName
        let count = PrayerTracker.kazaCount(name)
        return Section {
            Stepper(value: Binding(
                get: { PrayerTracker.kazaCount(name) },
                set: { PrayerTracker.setKazaCount($0, for: name) }
            ), in: 0...99_999) {
                HStack {
                    Label(loc.t("tracking_fast_days", fallback: "Kaza orucu (gün)"), systemImage: "moon.haze")
                    Spacer()
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(count > 0 ? AppTheme.accent : .secondary)
                }
            }
            .accessibilityValue("\(count)")
            .id("fast-\(refresh)")
        } header: {
            Text(loc.t("tracking_fast_title", fallback: "Kaza oruçları"))
        } footer: {
            Text(loc.t("tracking_fast_footer", fallback: "Ramazan'da tutamadığın günleri + ile ekle. Kaza orucu tuttukça − ile azalt."))
        }
    }

    // MARK: - Kaza

    private var kazaSection: some View {
        Section {
            ForEach(PrayerTracker.kazaNames, id: \.self) { name in
                let count = PrayerTracker.kazaCount(name)
                // Değer her seferinde kayıttan okunur: eskiden satır yenilenmediği için
                // "+" hep eski değeri (0) görüp 1 yazıyordu, satırda da 0 kalıyordu.
                Stepper(value: Binding(
                    get: { PrayerTracker.kazaCount(name) },
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
                // Kayıt değişince satır yeniden çizilsin (liste satırları kendiliğinden yenilenmiyordu).
                .accessibilityValue("\(count)")
                .id("kaza-\(name)-\(refresh)")
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
