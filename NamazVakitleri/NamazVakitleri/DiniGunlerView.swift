import SwiftUI

struct ReligiousDay: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let note: String?
}

struct DiniGunlerView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var days: [ReligiousDay] {
        let calendar = Calendar(identifier: .gregorian)

        func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        }

        let allDays: [ReligiousDay] = [
            ReligiousDay(name: "Üç Ayların Başlangıcı (Recep)", date: makeDate(2026, 12, 10), note: nil),
            ReligiousDay(name: "Regaip Kandili", date: makeDate(2026, 12, 10), note: "Gece idrak edilir"),
            ReligiousDay(name: "Miraç Kandili", date: makeDate(2027, 1, 5), note: nil),
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

        let today = calendar.startOfDay(for: Date())
        return allDays
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationView {
            List {
                if let nearest = days.first {
                    Section {
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.35), Color.black],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                            .frame(height: 130)
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.accent.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(nearest.name)
                                    .font(AppTheme.title(17))
                                    .foregroundColor(.white)
                                Text(formattedDate(nearest.date))
                                    .font(AppTheme.body(12))
                                    .foregroundColor(.white.opacity(0.85))
                                Text(daysRemainingText(nearest.date))
                                    .font(AppTheme.body(12, weight: .semibold))
                                    .foregroundColor(AppTheme.gold)
                            }
                            .padding(14)
                        }
                        .cornerRadius(AppTheme.cardCornerRadius)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(days.dropFirst()) { day in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.name)
                                    .font(AppTheme.body(15, weight: .medium))
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                if let note = day.note {
                                    Text(note)
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
                    Text("Tarihler Diyanet İşleri Başkanlığı'nın yayımladığı dini günler takvimine dayanmaktadır. Ramazan ve Kurban Bayramı gibi hilal gözlemine bağlı başlangıç tarihleri, ilgili ay yaklaştığında resmî olarak kesinleşir ve ±1 gün değişebilir.")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle("Dini Günler")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }

    private func daysRemainingText(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days == 0 { return "Bugün" }
        return "\(days) gün kaldı"
    }
}

#Preview {
    DiniGunlerView()
}
