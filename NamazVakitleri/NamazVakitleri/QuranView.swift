import SwiftUI
import UIKit

/// Arapça metin verisi zaten gerçek Mushaf yazımı olan "quran-uthmani"
/// kaynağından geliyor. Ama sistemin genel Arapça fontu, Kur'an'a özel
/// işaretleri (üstün/ötre/med, secde-vakf işaretleri vb.) tam
/// karşılamadığı için "gerçek Kur'an gibi durmuyor" hissi verebiliyor.
/// Projeye "AmiriQuran-Regular" gibi Kur'an'a özel bir font eklenirse
/// (ör. Amiri Quran, ücretsiz ve Google Fonts'ta mevcut) otomatik olarak
/// o kullanılır; eklenmediyse mevcut serif sistem fontuna düşer, hata
/// vermez.
private func quranArabicFont(size baseSize: CGFloat) -> Font {
    let size = AppTheme.scaled(baseSize)
    if UIFont(name: "AmiriQuran-Regular", size: size) != nil {
        return .custom("AmiriQuran-Regular", size: size)
    }
    return .system(size: size, design: .serif)
}

private enum RevelationFilter: String, CaseIterable {
    case all = "Tümü"
    case meccan = "Mekki"
    case medinan = "Medeni"
}

struct QuranView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            SurahListContent()
                .background(AppTheme.background(colorScheme).ignoresSafeArea())
                .navigationTitle(loc.t("quran_surahs", fallback: "Sureler"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.background(colorScheme), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private struct SurahListContent: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var surahs: [QuranSurahSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var filter: RevelationFilter = .all
    /// Sadece DEBUG ekran testleri: -uiSurah 36 ile sureyi doğrudan aç.
    @State private var debugSurah: QuranSurahSummary?

    private var filteredSurahs: [QuranSurahSummary] {
        surahs.filter { surah in
            // Tüm dillerdeki adlarda ve numarada ara (Türkçe harflere duyarlı).
            let matchesSearch = searchText.isEmpty
                || surah.englishNameTranslation.matchesSearch(searchText)
                || surah.englishName.matchesSearch(searchText)
                || SurahNames.title(number: surah.number, englishFallback: "").matchesSearch(searchText)
                || SurahNames.title(for: surah).matchesSearch(searchText)
                // Her dilde Türkçe adla da bulunsun (İngilizce'de "Yasin" → Yâsîn).
                || (SurahNames.turkish[surah.number]?.name ?? "").matchesSearch(searchText)
                || surah.name.contains(searchText)
                || String(surah.number) == searchText.trimmingCharacters(in: .whitespaces)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .meccan: matchesFilter = surah.revelationType.lowercased() == "meccan"
            case .medinan: matchesFilter = surah.revelationType.lowercased() == "medinan"
            }
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textTertiary(colorScheme))
                TextField(loc.t("quran_search", fallback: "Sure ara"), text: $searchText)
                    .font(AppTheme.body(14))
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textTertiary(colorScheme))
                    }
                    .accessibilityLabel(loc.t("common_clear", fallback: "Temizle"))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardFill(colorScheme)))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Picker(loc.t("quran_filter", fallback: "Filtre"), selection: $filter) {
                ForEach(RevelationFilter.allCases, id: \.self) { option in
                    Text(loc.x(option.rawValue)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Group {
                if isLoading {
                    ProgressView(loc.t("quran_loading_surahs", fallback: "Sureler yükleniyor..."))
                        .tint(AppTheme.accent)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage).foregroundStyle(.red).multilineTextAlignment(.center)
                        Button(loc.t("home_retry", fallback: "Tekrar Dene")) { Task { await loadSurahs() } }
                    }
                    .padding()
                } else if filteredSurahs.isEmpty {
                    Text(loc.t("quran_no_match", fallback: "Bu adla sure bulunamadı. Daha kısa yazmayı dene (ör. \"yas\")."))
                        .font(AppTheme.body(14))
                        .foregroundColor(AppTheme.textSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(24)
                    Spacer()
                } else {
                    List(filteredSurahs) { surah in
                        NavigationLink {
                            SurahDetailView(surah: surah)
                        } label: {
                            HStack {
                                Text("\(surah.number).")
                                    .foregroundStyle(AppTheme.textTertiary(colorScheme))
                                    .lineLimit(1)
                                    .fixedSize()
                                    .frame(minWidth: 28, alignment: .trailing)
                                VStack(alignment: .leading) {
                                    Text(SurahNames.title(for: surah))
                                        .font(AppTheme.body(15, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary(colorScheme))
                                    Text(loc.tf("quran_ayah_count", "%d Ayet", surah.numberOfAyahs))
                                        .font(AppTheme.body(12))
                                        .foregroundColor(AppTheme.textTertiary(colorScheme))
                                }
                                Spacer()
                                Text(surah.name)
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .task {
            await loadSurahs()
            #if DEBUG
            let n = UserDefaults.standard.integer(forKey: "uiSurah")
            if n > 0 { debugSurah = surahs.first { $0.number == n } }
            #endif
        }
        .navigationDestination(item: $debugSurah) { surah in
            SurahDetailView(surah: surah)
        }
    }

    private func loadSurahs() async {
        isLoading = true
        errorMessage = nil
        do {
            surahs = try await QuranAPI.shared.fetchSurahList()
            isLoading = false
        } catch {
            errorMessage = loc.t("quran_err_surahs", fallback: "Sureler yüklenemedi, internet bağlantını kontrol et.")
            isLoading = false
        }
    }
}

private struct SurahDetailView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lastReadSurahName") private var lastReadSurahName: String = ""
    @AppStorage("lastReadAyahNumber") private var lastReadAyahNumber: Int = 0

    @StateObject private var recitation = RecitationPlayer()
    @ObservedObject private var audioStore = QuranAudioStore.shared

    let surah: QuranSurahSummary

    @State private var content: QuranAPI.SurahContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView(loc.t("quran_loading", fallback: "Yükleniyor..."))
                    .tint(AppTheme.accent)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
            } else if let content {
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 6) {
                            Text(surah.name)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                            Text("\(SurahNames.title(for: surah)) · " + loc.tf("quran_ayah_count", "%d Ayet", surah.numberOfAyahs) + " · " + (surah.revelationType == "Meccan" ? loc.t("quran_meccan", fallback: "Mekki") : loc.t("quran_medinan", fallback: "Medeni")))
                                .font(AppTheme.body(12))
                                .foregroundStyle(AppTheme.textTertiary(colorScheme))

                            // Fâtiha'da besmele 1. ayettir (iki kez gösterme); Tevbe'de besmele yok.
                            if surah.number != 9 && surah.number != 1 {
                                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                    .font(quranArabicFont(size: 24))
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                    .padding(.top, 10)
                                if loc.language != .arabic {
                                    Text(loc.language == .turkish ? "Bismillâhirrahmânirrahîm" : "Bismillāhir-raḥmānir-raḥīm")
                                        .font(AppTheme.body(13))
                                        .italic()
                                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)

                        ForEach(Array(content.arabic.enumerated()), id: \.offset) { index, arabicAyah in
                            let isCurrent = recitation.currentIndex == index
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Spacer()
                                    // Ayet numarasına dokununca hafız bu ayetten başlar.
                                    Button {
                                        recitation.play(globalNumbers: content.arabic.map(\.number), from: index)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "play.fill")
                                                .font(.system(size: 9, weight: .bold))
                                            Text("\(arabicAyah.numberInSurah)")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(Capsule().fill(AppTheme.accent))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(loc.tf("recitation_from_ayah", "%d. ayetten dinle", arabicAyah.numberInSurah))
                                }
                                Text(arabicAyah.text)
                                    .font(quranArabicFont(size: 26))
                                    .lineSpacing(10)
                                    .multilineTextAlignment(.trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                // Arapça arayüzde Latin okunuş gereksiz (Arap kullanıcı metni okur).
                                if loc.language != .arabic, index < content.transliteration.count {
                                    let plain = QuranAPI.simpleTransliteration(content.transliteration[index].text)
                                    Text(plain.prefix(1).uppercased(with: loc.locale) + plain.dropFirst())
                                        .font(.footnote)
                                        .italic()
                                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                                }
                                if index < content.meal.count {
                                    Text(content.meal[index].text)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textPrimary(colorScheme))
                                }
                            }
                            .padding(isCurrent ? 10 : 0)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isCurrent ? AppTheme.accentSoft(colorScheme) : Color.clear)
                            )
                            .id(index)
                            Divider().overlay(AppTheme.cardStroke(colorScheme))
                        }
                    }
                    .padding()
                    .padding(.bottom, 60)
                }
                // Okunan ayet ekranda görünür kalsın.
                .onChange(of: recitation.currentIndex) { _, newIndex in
                    guard let newIndex else { return }
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(newIndex, anchor: .top) }
                    lastReadAyahNumber = newIndex + 1
                }
                .safeAreaInset(edge: .bottom) {
                    recitationBar(content)
                }
                }
            }
        }
        .onDisappear { recitation.stop() }
        .alert(loc.t("recitation_error_title", fallback: "Ses çalınamadı"), isPresented: Binding(
            get: { recitation.errorMessage != nil },
            set: { if !$0 { recitation.errorMessage = nil } }
        )) {
            Button(loc.t("common_ok", fallback: "Tamam"), role: .cancel) {}
        } message: {
            Text(recitation.errorMessage ?? "")
        }
        .alert(loc.t("audio_download_error_title", fallback: "İndirme tamamlanamadı"), isPresented: Binding(
            get: { audioStore.lastError != nil },
            set: { if !$0 { audioStore.lastError = nil } }
        )) {
            Button(loc.t("common_ok", fallback: "Tamam"), role: .cancel) {}
        } message: {
            Text(audioStore.lastError ?? "")
        }
        .background(AppTheme.background(colorScheme).ignoresSafeArea())
        .navigationTitle(SurahNames.title(for: surah))
        .navigationBarTitleDisplayMode(.inline)
        // Ayetler kaydırılınca üstteki saat çubuğunun altında görünmesin.
        .toolbarBackground(AppTheme.background(colorScheme), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadContent()
            // Sadece sure gerçekten açıldıysa "son okunan" olarak kaydet.
            guard let content else { return }
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "uiAutoPlay") {
                recitation.play(globalNumbers: content.arabic.map(\.number), from: 1)
            }
            #endif
            lastReadSurahName = SurahNames.title(for: surah)
            lastReadAyahNumber = 1
        }
    }

    /// İndir düğmesi: indirilmemiş → ok; iniyor → ilerleme halkası (dokununca durur);
    /// inmiş → yeşil tik (dokununca silme sorusu). İnen sure internetsiz dinlenir.
    @ViewBuilder
    private func downloadButton(_ content: QuranAPI.SurahContent) -> some View {
        let numbers = content.arabic.map(\.number)
        let _ = audioStore.revision
        if let p = audioStore.progress[surah.number] {
            Button { audioStore.cancel(surah: surah.number) } label: {
                ZStack {
                    Circle().stroke(AppTheme.accent.opacity(0.25), lineWidth: 3)
                    Circle().trim(from: 0, to: p).stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(p * 100))").font(.system(size: 10, weight: .bold)).foregroundColor(AppTheme.accent)
                }
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
            }
            .accessibilityLabel(loc.tf("audio_downloading", "İndiriliyor %%%d", Int(p * 100)))
        } else if audioStore.isDownloaded(numbers) {
            // Tek dokunuşla menü açılır (eskiden sadece uzun basınca soruyordu).
            Menu {
                Text(loc.t("audio_downloaded", fallback: "İndirildi, internetsiz dinlenebilir"))
                Button(role: .destructive) { audioStore.delete(numbers) } label: {
                    Label(loc.t("audio_delete", fallback: "Sesi Sil"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(loc.t("audio_downloaded", fallback: "İndirildi, internetsiz dinlenebilir"))
        } else {
            Button { audioStore.download(surah: surah.number, globalNumbers: numbers) } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(loc.t("audio_download", fallback: "İnternetsiz dinlemek için indir"))
        }
    }

    /// Alt çubuk: hafız adı, oynat/duraklat, durdur.
    private func recitationBar(_ content: QuranAPI.SurahContent) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t("recitation_reciter", fallback: "Hafız"))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary(colorScheme))
                Text(RecitationPlayer.localizedReciterName)
                    .font(AppTheme.body(14, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let index = recitation.currentIndex {
                    Text(loc.tf("recitation_now", "%d. ayet okunuyor", index + 1))
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                }
            }
            Spacer(minLength: 4)
            downloadButton(content)
            if recitation.isLoading {
                ProgressView().tint(AppTheme.accent)
            }
            if recitation.currentIndex != nil {
                Button { recitation.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundColor(AppTheme.accent)
                }
                .accessibilityLabel(loc.t("quran_stop", fallback: "Durdur"))
            }
            Button {
                if recitation.currentIndex == nil {
                    recitation.play(globalNumbers: content.arabic.map(\.number))
                } else if recitation.isPlaying {
                    recitation.pause()
                } else {
                    recitation.resume()
                }
            } label: {
                Image(systemName: recitation.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(AppTheme.accent))
            }
            .accessibilityLabel(recitation.isPlaying ? loc.t("recitation_pause", fallback: "Duraklat") : loc.t("quran_listen", fallback: "Dinle"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        do {
            content = try await QuranAPI.shared.fetchSurahContent(number: surah.number, language: loc.language)
            isLoading = false
        } catch {
            errorMessage = loc.t("quran_err_surah", fallback: "Sure yüklenemedi, internet bağlantını kontrol et.")
            isLoading = false
        }
    }
}

#Preview {
    QuranView()
}
