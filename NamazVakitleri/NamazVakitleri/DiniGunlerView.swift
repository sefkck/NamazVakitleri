import SwiftUI

struct ReligiousDay: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let note: String?
}

/// Dini günler listesi: Diyanet'in yayımladığı tarihler + sonrası için
/// Hicri takvimden otomatik hesaplanan günler. Hem "Dini Günler" ekranı
/// hem de dini gün hatırlatma bildirimleri bunu kullanır.
enum ReligiousDays {
    static func upcoming(from now: Date = Date()) -> [ReligiousDay] {
        let calendar = Calendar(identifier: .gregorian)

        func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        }

        let allDays: [ReligiousDay] = [
            ReligiousDay(name: "Üç Ayların Başlangıcı (Recep)", date: makeDate(2026, 12, 10), note: nil),
            ReligiousDay(name: "Regaip Kandili", date: makeDate(2026, 12, 10), note: "Gece idrak edilir"),
            // 26 Recep 1448 (Diyanet 2025 ve 2026'da da Miraç'ı 26 Recep'e koydu).
            ReligiousDay(name: "Miraç Kandili", date: makeDate(2027, 1, 4), note: nil),
            ReligiousDay(name: "Berat Kandili", date: makeDate(2027, 1, 22), note: nil),
            ReligiousDay(name: "Ramazan Başlangıcı", date: makeDate(2027, 2, 8), note: nil),
            ReligiousDay(name: "Kadir Gecesi", date: makeDate(2027, 3, 5), note: "Yaklaşık tarih"),
            ReligiousDay(name: "Ramazan Bayramı Arefesi", date: makeDate(2027, 3, 8), note: "Yaklaşık tarih"),
            ReligiousDay(name: "Ramazan Bayramı", date: makeDate(2027, 3, 9), note: "Yaklaşık tarih"),
            ReligiousDay(name: "Kurban Bayramı Arefesi", date: makeDate(2027, 5, 15), note: nil),
            ReligiousDay(name: "Kurban Bayramı", date: makeDate(2027, 5, 16), note: nil),
            ReligiousDay(name: "Hicri Yılbaşı", date: makeDate(2027, 6, 6), note: nil),
            ReligiousDay(name: "Aşure Günü", date: makeDate(2027, 6, 15), note: nil),
            ReligiousDay(name: "Mevlid Kandili", date: makeDate(2027, 8, 13), note: nil),
            ReligiousDay(name: "Üç Ayların Başlangıcı (Recep)", date: makeDate(2027, 11, 29), note: nil),
            ReligiousDay(name: "Regaip Kandili", date: makeDate(2027, 12, 2), note: nil),
            ReligiousDay(name: "Miraç Kandili", date: makeDate(2027, 12, 24), note: nil)
        ]

        let today = calendar.startOfDay(for: now)
        //===========Otomatik Dini Günler Starts===========
        // Elle girilen Diyanet tarihleri bittikten sonrası Hicri takvimden
        // otomatik hesaplanır (bkz. ReligiousDayGenerator).
        let generatedDays = ReligiousDayGenerator.days(after: allDays.map(\.date).max() ?? today)
        //===========Otomatik Dini Günler Ends===========
        return (allDays + generatedDays)
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
    }
}

struct DiniGunlerView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var days: [ReligiousDay] {
        ReligiousDays.upcoming()
    }

    var body: some View {
        NavigationView {
            List {
                if let nearest = days.first {
                    Section {
                        ZStack(alignment: .topLeading) {
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.6), Color(red: 0.13, green: 0.08, blue: 0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            // Dekoratif parlayan ay ve yıldızlar
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [AppTheme.gold.opacity(0.5), .clear],
                                            center: .center,
                                            startRadius: 2,
                                            endRadius: 72
                                        )
                                    )
                                    .frame(width: 150, height: 150)
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppTheme.gold, .white.opacity(0.92)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: AppTheme.gold.opacity(0.5), radius: 8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.top, 6)
                            .padding(.trailing, 4)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(loc.t("rd_next", fallback: "SIRADAKİ DİNİ GÜN"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.8)
                                    .foregroundColor(.white.opacity(0.75))

                                Text(loc.x(nearest.name))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)

                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                    Text(formattedDate(nearest.date))
                                        .font(AppTheme.body(13))
                                }
                                .foregroundColor(.white.opacity(0.92))

                                Spacer(minLength: 6)

                                Text(daysRemainingText(nearest.date))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(red: 0.22, green: 0.12, blue: 0.10))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(AppTheme.gold))
                            }
                            .padding(16)
                            .padding(.trailing, 70)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 172)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(days.dropFirst()) { day in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.x(day.name))
                                    .font(AppTheme.body(15, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                if let note = day.note {
                                    Text(loc.x(note))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textTertiary(colorScheme))
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formattedDate(day.date))
                                    .font(AppTheme.body(13, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                Text(daysRemainingText(day.date))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                    }
                } footer: {
                    Text(loc.t("rd_footer", fallback: "Tarihler Diyanet İşleri Başkanlığı'nın yayımladığı dini günler takvimine dayanmaktadır. Ramazan ve Kurban Bayramı gibi hilal gözlemine bağlı başlangıç tarihleri, ilgili ay yaklaştığında resmî olarak kesinleşir ve ±1 gün değişebilir."))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle(loc.t("more_religious_days", fallback: "Dini Günler"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = loc.locale
        return formatter.string(from: date)
    }

    private func daysRemainingText(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days == 0 { return loc.t("rd_today", fallback: "Bugün") }
        if days == 1 { return loc.t("rd_one_day_left", fallback: "1 gün kaldı") }
        return loc.tf("rd_days_left", "%d gün kaldı", days)
    }
}

#Preview {
    DiniGunlerView()
}

//===========Otomatik Dini Günler Starts===========
/// Elle girilmiş Diyanet listesinin bittiği tarihten sonrası için dini
/// günleri Hicri takvimden (Umm al-Qura) hesaplar. Diyanet'in takvimiyle
/// ±1 gün fark olabileceği için hepsi "Yaklaşık tarih" notuyla gösterilir.
enum ReligiousDayGenerator {
    /// Kaç Hicri yıl ileriye kadar üretileceği.
    private static let yearsAhead = 2
    private static let approximateNote = "Yaklaşık tarih"

    private static let hijriCalendar: Calendar = {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = .current
        return cal
    }()

    private static let gregorian: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    /// `cutoff` tarihinden SONRAKİ otomatik dini günler.
    static func days(after cutoff: Date) -> [ReligiousDay] {
        let currentHijriYear = hijriCalendar.component(.year, from: Date())
        return (currentHijriYear...(currentHijriYear + yearsAhead))
            .flatMap { days(forHijriYear: $0) }
            .filter { $0.date > cutoff }
    }

    /// Bir Hicri yıla ait tüm dini günler (Diyanet'in kullandığı kurallarla).
    private static func days(forHijriYear year: Int) -> [ReligiousDay] {
        var result: [ReligiousDay] = []
        func add(_ name: String, _ date: Date?) {
            guard let date else { return }
            result.append(ReligiousDay(name: name, date: date, note: approximateNote))
        }

        add("Hicri Yılbaşı", hijriDate(year, 1, 1))                         // 1 Muharrem
        add("Aşure Günü", hijriDate(year, 1, 10))                           // 10 Muharrem
        add("Mevlid Kandili", hijriDate(year, 3, 11))                       // 12 Rebiülevvel gecesi
        add("Üç Ayların Başlangıcı (Recep)", hijriDate(year, 7, 1))         // 1 Recep
        add("Regaip Kandili", regaipDate(hijriYear: year))                  // Recep'in ilk Cuma gecesi
        add("Miraç Kandili", hijriDate(year, 7, 26))                        // 27 Recep gecesi
        add("Berat Kandili", hijriDate(year, 8, 14))                        // 15 Şaban gecesi
        add("Ramazan Başlangıcı", hijriDate(year, 9, 1))                    // 1 Ramazan
        add("Kadir Gecesi", hijriDate(year, 9, 26))                         // 27 Ramazan gecesi
        add("Ramazan Bayramı Arefesi", dayBefore(hijriDate(year, 10, 1)))   // 1 Şevval'den önceki gün
        add("Ramazan Bayramı", hijriDate(year, 10, 1))                      // 1 Şevval
        add("Kurban Bayramı Arefesi", hijriDate(year, 12, 9))               // 9 Zilhicce
        add("Kurban Bayramı", hijriDate(year, 12, 10))                      // 10 Zilhicce
        return result
    }

    /// Hicri tarihi, o günün başlangıcındaki (00:00) Miladi tarihe çevirir.
    private static func hijriDate(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        guard let date = hijriCalendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        return gregorian.startOfDay(for: date)
    }

    private static func dayBefore(_ date: Date?) -> Date? {
        guard let date else { return nil }
        return gregorian.date(byAdding: .day, value: -1, to: date)
    }

    /// Regaip Kandili: Recep ayının ilk Cuma'sından önceki Perşembe.
    private static func regaipDate(hijriYear year: Int) -> Date? {
        guard let firstOfRajab = hijriDate(year, 7, 1) else { return nil }
        let fridayWeekday = 6 // Gregoryen takvimde 1 = Pazar ... 6 = Cuma
        let weekday = gregorian.component(.weekday, from: firstOfRajab)
        let daysUntilFriday = (fridayWeekday - weekday + 7) % 7
        guard let firstFriday = gregorian.date(byAdding: .day, value: daysUntilFriday, to: firstOfRajab) else { return nil }
        return dayBefore(firstFriday)
    }
}
//===========Otomatik Dini Günler Ends===========
