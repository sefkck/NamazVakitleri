import SwiftUI

private enum RevelationFilter: String, CaseIterable {
    case all = "Tümü"
    case meccan = "Mekki"
    case medinan = "Medeni"
}

struct QuranView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationView {
            SurahListContent()
                .background(AppTheme.background(colorScheme).ignoresSafeArea())
                .navigationTitle("Sureler")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Kapat") { dismiss() }
                    }
                }
        }
    }
}

private struct SurahListContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var surahs: [QuranSurahSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var filter: RevelationFilter = .all

    private var filteredSurahs: [QuranSurahSummary] {
        surahs.filter { surah in
            let matchesSearch = searchText.isEmpty || surah.englishNameTranslation.localizedCaseInsensitiveContains(searchText) || surah.name.localizedCaseInsensitiveContains(searchText)
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
                TextField("Sure ara", text: $searchText)
                    .font(AppTheme.body(14))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.cardFill(colorScheme)))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Picker("Filtre", selection: $filter) {
                ForEach(RevelationFilter.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Group {
                if isLoading {
                    ProgressView("Sureler yükleniyor...")
                        .tint(AppTheme.accent)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage).foregroundStyle(.red).multilineTextAlignment(.center)
                        Button("Tekrar Dene") { Task { await loadSurahs() } }
                    }
                    .padding()
                } else {
                    List(filteredSurahs) { surah in
                        NavigationLink {
                            SurahDetailView(surah: surah)
                        } label: {
                            HStack {
                                Text("\(surah.number).")
                                    .foregroundStyle(AppTheme.textTertiary(colorScheme))
                                    .frame(width: 28, alignment: .trailing)
                                VStack(alignment: .leading) {
                                    Text(surah.englishNameTranslation)
                                        .font(AppTheme.body(15, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary(colorScheme))
                                    Text("\(surah.numberOfAyahs) Ayet")
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
        }
    }

    private func loadSurahs() async {
        isLoading = true
        errorMessage = nil
        do {
            surahs = try await QuranAPI.shared.fetchSurahList()
            isLoading = false
        } catch {
            errorMessage = "Sureler yüklenemedi, internet bağlantını kontrol et."
            isLoading = false
        }
    }
}

private struct SurahDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lastReadSurahName") private var lastReadSurahName: String = ""
    @AppStorage("lastReadAyahNumber") private var lastReadAyahNumber: Int = 0

    @StateObject private var speechReader = SpeechReader()

    let surah: QuranSurahSummary

    @State private var content: QuranAPI.SurahContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Yükleniyor...")
                    .tint(AppTheme.accent)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
            } else if let content {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 6) {
                            Text(surah.name)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                            Text("\(surah.englishNameTranslation) · \(surah.numberOfAyahs) Ayet · \(surah.revelationType == "Meccan" ? "Mekki" : "Medeni")")
                                .font(AppTheme.body(12))
                                .foregroundStyle(AppTheme.textTertiary(colorScheme))

                            if surah.number != 9 {
                                Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                                    .font(.system(size: 24, design: .serif))
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                    .padding(.top, 10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)

                        ForEach(Array(content.arabic.enumerated()), id: \.offset) { index, arabicAyah in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Spacer()
                                    Text("\(arabicAyah.numberInSurah)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(AppTheme.accent))
                                }
                                Text(arabicAyah.text)
                                    .font(.system(size: 26, design: .serif))
                                    .lineSpacing(10)
                                    .multilineTextAlignment(.trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                                    .foregroundColor(AppTheme.textPrimary(colorScheme))
                                if index < content.transliteration.count {
                                    Text(content.transliteration[index].text)
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
                            Divider().overlay(AppTheme.cardStroke(colorScheme))
                        }
                    }
                    .padding()
                    .padding(.bottom, 60)
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        if speechReader.isSpeaking {
                            speechReader.stop()
                        } else {
                            let fullText = content.arabic.map { $0.text }.joined(separator: " ")
                            speechReader.speak(fullText)
                        }
                    } label: {
                        Label(speechReader.isSpeaking ? "Durdur" : "Sesli Oku",
                              systemImage: speechReader.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.accent)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
        }
        .background(AppTheme.background(colorScheme).ignoresSafeArea())
        .navigationTitle(surah.englishNameTranslation)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContent()
            lastReadSurahName = surah.englishNameTranslation
            lastReadAyahNumber = 1
        }
    }

    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        do {
            content = try await QuranAPI.shared.fetchSurahContent(number: surah.number)
            isLoading = false
        } catch {
            errorMessage = "Sure yüklenemedi, internet bağlantını kontrol et."
            isLoading = false
        }
    }
}

#Preview {
    QuranView()
}
