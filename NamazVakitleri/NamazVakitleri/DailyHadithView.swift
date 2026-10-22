import SwiftUI

/// Günün hadisi ve Nevevî'nin Kırk Hadisi listesi.
struct DailyHadithView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if let today = DailyHadith.ofDay() {
                    Section(loc.t("hadith_today", fallback: "Günün hadisi")) {
                        HadithBody(item: today)
                            .listRowBackground(AppTheme.cardFill(colorScheme))
                    }
                }
                Section {
                    ForEach(DailyHadith.all) { item in
                        NavigationLink {
                            ScrollView { HadithBody(item: item).padding() }
                                .background(AppTheme.background(colorScheme).ignoresSafeArea())
                                .navigationTitle(loc.tf("hadith_number", "%d. hadis", item.n))
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(item.n)")
                                    .font(AppTheme.body(12, weight: .semibold))
                                    .foregroundColor(AppTheme.textTertiary(colorScheme))
                                    .frame(minWidth: 22, alignment: .trailing)
                                Text(item.translation(in: loc.language) ?? item.ar)
                                    .font(AppTheme.body(14))
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                    .lineLimit(2)
                            }
                        }
                        .listRowBackground(AppTheme.cardFill(colorScheme))
                    }
                } header: {
                    Text(loc.t("hadith_all", fallback: "Kırk Hadis (İmam Nevevî)"))
                } footer: {
                    Text(loc.t("hadith_footer", fallback: "Her gün bir hadis. Kaynak: İmam Nevevî, el-Erbaûn (Kırk Hadis). Arapça metin klasik metindir; çeviri açık kaynaklı hadith-api projesindendir ve Arapçasıyla karşılaştırılmıştır."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .navigationTitle(loc.t("hadith_title", fallback: "Günün Hadisi"))
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
}

/// Arapça metin + telefonun dilindeki çeviri + kaynak.
private struct HadithBody: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    let item: DailyHadith.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.arabic(item.ar))
                .font(.system(size: AppTheme.scaled(20)))
                .foregroundColor(AppTheme.accent)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .fixedSize(horizontal: false, vertical: true)
            if let text = item.translation(in: loc.language) {
                Text(text)
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(loc.tf("hadith_source", "İmam Nevevî, Kırk Hadis · %d. hadis", item.n))
                .font(AppTheme.body(12, weight: .semibold))
                .foregroundColor(AppTheme.gold)
        }
        .padding(.vertical, 6)
        .textSelection(.enabled)
    }

    /// VoiceOver Arapça metni Arapça sesle okusun.
    private static func arabic(_ text: String) -> AttributedString {
        var a = AttributedString(text)
        a.languageIdentifier = "ar"
        return a
    }
}
