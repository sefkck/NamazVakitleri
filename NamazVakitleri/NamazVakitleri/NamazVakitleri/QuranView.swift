import SwiftUI

struct QuranView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ProGatedContent(title: "Kuran-ı Kerim") {
                SurahListContent()
            }
            .navigationTitle("Kuran-ı Kerim")
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
    @State private var surahs: [QuranSurahSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Sureler yükleniyor...")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Tekrar Dene") {
                        Task { await loadSurahs() }
                    }
                }
                .padding()
            } else {
                List(surahs) { surah in
                    NavigationLink {
                        SurahDetailView(surah: surah)
                    } label: {
                        HStack {
                            Text("\(surah.number).")
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                            VStack(alignment: .leading) {
                                Text(surah.englishNameTranslation)
                                    .font(.body)
                                Text("\(surah.numberOfAyahs) ayet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(surah.name)
                                .font(.system(size: 18))
                        }
                    }
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
    @EnvironmentObject private var userStore: UserStore
    @StateObject private var speechReader = SpeechReader()

    let surah: QuranSurahSummary

    @State private var content: QuranAPI.SurahContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var isPro: Bool { userStore.currentUser?.isPro == true }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Yükleniyor...")
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
            } else if let content {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(content.arabic.enumerated()), id: \.offset) { index, arabicAyah in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(arabicAyah.numberInSurah)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                Text(arabicAyah.text)
                                    .font(.system(size: 24))
                                    .multilineTextAlignment(.trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                                if index < content.transliteration.count {
                                    Text(content.transliteration[index].text)
                                        .font(.footnote)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                }
                                if index < content.meal.count {
                                    Text(content.meal[index].text)
                                        .font(.subheadline)
                                }
                            }
                            Divider()
                        }
                    }
                    .padding()
                    .padding(.bottom, isPro ? 60 : 0)
                }
                .safeAreaInset(edge: .bottom) {
                    if isPro {
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
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .navigationTitle(surah.englishNameTranslation)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContent()
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
    QuranView().environmentObject(UserStore())
}
