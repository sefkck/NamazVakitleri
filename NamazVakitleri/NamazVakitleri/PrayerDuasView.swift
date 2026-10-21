import SwiftUI

struct PrayerDua: Identifiable {
    let id = UUID()
    let title: String
    let arabic: String
    let okunus: String
    let meal: String
    /// Kur'an ayeti olan dualar için ayetlerin genel numaraları (1...6236):
    /// bunlar hafız sesiyle okunur. Boşsa (ayet değilse) ses düğmesi gösterilmez.
    var quranAyahs: [Int] = []
}

struct PrayerDuasView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recitation = RecitationPlayer()
    /// Şu an okunan dua (simgeyi "durdur"a çevirmek için).
    @State private var playingDuaID: UUID?

    let duas: [PrayerDua] = [
        PrayerDua(title: "Sübhaneke",
                  arabic: "سُبْحَانَكَ اللّٰهُمَّ وَبِحَمْدِكَ، وَتَبَارَكَ اسْمُكَ، وَتَعَالٰى جَدُّكَ، وَلَا إِلٰهَ غَيْرُكَ",
                  okunus: "Sübhânekellâhümme ve bihamdik, ve tebârakesmük, ve teâlâ ceddük, ve lâ ilâhe ğayruk.",
                  meal: "Allah'ım, seni her türlü eksiklikten tenzih eder, sana hamd ederim. Adın mübarektir, şanın yücedir. Senden başka ilah yoktur."),
        PrayerDua(title: "Ettehiyyatü (Tahiyyat)",
                  arabic: "التَّحِيَّاتُ لِلّٰهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللّٰهِ وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلٰى عِبَادِ اللّٰهِ الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلٰهَ إِلَّا اللّٰهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ",
                  okunus: "Ettehiyyâtü lillâhi vessalevâtü vettayyibât. Esselâmü aleyke eyyühen Nebiyyü ve rahmetullâhi ve berakâtüh. Esselâmü aleynâ ve alâ ibâdillâhis sâlihîn. Eşhedü en lâ ilâhe illallah ve eşhedü enne Muhammeden abdühû ve rasûlüh.",
                  meal: "Bütün dil, beden ve mal ile yapılan ibadetler Allah'a mahsustur. Ey Peygamber, Allah'ın selamı, rahmeti ve bereketi senin üzerine olsun. Selam bizim ve Allah'ın iyi kullarının üzerine olsun. Şahitlik ederim ki Allah'tan başka ilah yoktur, yine şahitlik ederim ki Muhammed O'nun kulu ve elçisidir."),
        PrayerDua(title: "Allahümme Salli",
                  arabic: "اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ وَعَلٰى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلٰى إِبْرَاهِيمَ وَعَلٰى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ",
                  okunus: "Allâhümme salli alâ Muhammedin ve alâ âli Muhammed. Kemâ salleyte alâ İbrâhîme ve alâ âli İbrâhîme inneke hamîdün mecîd.",
                  meal: "Allah'ım, İbrahim'e ve ailesine salat ettiğin gibi Muhammed'e ve ailesine de salat et. Şüphesiz sen övgüye layık ve yücesin."),
        PrayerDua(title: "Allahümme Barik",
                  arabic: "اَللّٰهُمَّ بَارِكْ عَلٰى مُحَمَّدٍ وَعَلٰى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلٰى إِبْرَاهِيمَ وَعَلٰى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ",
                  okunus: "Allâhümme bârik alâ Muhammedin ve alâ âli Muhammed. Kemâ bârekte alâ İbrâhîme ve alâ âli İbrâhîme inneke hamîdün mecîd.",
                  meal: "Allah'ım, İbrahim'e ve ailesine bereket verdiğin gibi Muhammed'e ve ailesine de bereket ver. Şüphesiz sen övgüye layık ve yücesin."),
        PrayerDua(title: "Rabbena Atina",
                  arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
                  okunus: "Rabbenâ âtinâ fid dünyâ haseneten ve fil âhirati haseneten ve kınâ azâben nâr.",
                  meal: "Rabbimiz, bize dünyada iyilik, ahirette de iyilik ver ve bizi ateşin azabından koru.",
                  quranAyahs: [208]),
        PrayerDua(title: "Rabbenağfirli",
                  arabic: "رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَلِلْمُؤْمِنِينَ يَوْمَ يَقُومُ الْحِسَابُ",
                  okunus: "Rabbiğfirlî ve li vâlideyye ve lil mü'minîne yevme yekûmül hisâb.",
                  meal: "Rabbim, hesabın görüleceği gün beni, anne babamı ve mü'minleri bağışla.",
                  quranAyahs: [1791]),
        PrayerDua(title: "Kunut Duası 1",
                  arabic: "اَللّٰهُمَّ إِنَّا نَسْتَعِينُكَ وَنَسْتَغْفِرُكَ وَنُؤْمِنُ بِكَ وَنَتَوَكَّلُ عَلَيْكَ",
                  okunus: "Allâhümme innâ nesteînüke ve nestağfiruke ve nü'minü bike ve netevekkelü aleyk.",
                  meal: "Allah'ım, senden yardım ister, senden bağışlanma dileriz. Sana inanır, sana güveniriz."),
        PrayerDua(title: "Kunut Duası 2",
                  arabic: "اَللّٰهُمَّ إِيَّاكَ نَعْبُدُ وَلَكَ نُصَلِّي وَنَسْجُدُ وَإِلَيْكَ نَسْعٰى وَنَحْفِدُ نَرْجُو رَحْمَتَكَ وَنَخْشٰى عَذَابَكَ إِنَّ عَذَابَكَ بِالْكُفَّارِ مُلْحِقٌ",
                  okunus: "Allâhümme iyyâke na'büdü ve leke nusallî ve nescüdü ve ileyke nes'â ve nahfidü nercû rahmeteke ve nahşâ azâbeke inne azâbeke bilküffâri mülhik.",
                  meal: "Allah'ım, yalnız sana ibadet eder, senin için namaz kılar ve secde ederiz. Yalnız sana koşar ve sana yaklaştırıcı işler yaparız. Rahmetini umar, azabından korkarız. Şüphesiz senin azabın kâfirlere ulaşır."),
        PrayerDua(title: "Ayete'l Kürsi",
                  arabic: "اللّٰهُ لَا إِلٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ",
                  okunus: "Allâhü lâ ilâhe illâ hüvel hayyül kayyûm, lâ te'huzühû sinetün ve lâ nevm.",
                  meal: "Allah, kendisinden başka ilah olmayandır. O, diridir, her şeyin varlığı O'na dayanır. O'nu ne bir uyuklama tutabilir ne de bir uyku.",
                  quranAyahs: [262]),
        PrayerDua(title: "Rabbişrahli",
                  arabic: "رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي",
                  okunus: "Rabbişrahlî sadrî ve yessirlî emrî.",
                  meal: "Rabbim, göğsümü genişlet ve işimi bana kolaylaştır.",
                  quranAyahs: [2373, 2374]),
        PrayerDua(title: "Amenerrasulü (Bakara 285-286)",
                  arabic: "آمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ",
                  okunus: "Âmener rasûlü bimâ ünzile ileyhi mir rabbihî vel mü'minûn.",
                  meal: "Peygamber, Rabbinden kendisine indirilene iman etti, mü'minler de iman ettiler.",
                  quranAyahs: [292, 293])
    ]

    /// Hafız sesiyle oku / durdur (sadece Kur'an ayeti olan dualar).
    private func toggle(_ dua: PrayerDua, isPlaying: Bool) {
        recitation.stop()
        guard !isPlaying, !dua.quranAyahs.isEmpty else { playingDuaID = nil; return }
        playingDuaID = dua.id
        recitation.play(globalNumbers: dua.quranAyahs)
    }

    private func duaNumber(_ dua: PrayerDua) -> Int {
        (duas.firstIndex(where: { $0.id == dua.id }) ?? 0) + 1
    }

    var body: some View {
        NavigationView {
            List(duas) { dua in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(loc.t("dua\(duaNumber(dua))_title", fallback: dua.title))
                            .font(AppTheme.body(15, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                        Spacer()
                        // Ses düğmesi sadece hafız kaydı olan (Kur'an ayeti) dualarda var.
                        if !dua.quranAyahs.isEmpty {
                            let isPlayingThis = playingDuaID == dua.id && recitation.currentIndex != nil
                            Button {
                                toggle(dua, isPlaying: isPlayingThis)
                            } label: {
                                Image(systemName: isPlayingThis ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(AppTheme.accent)
                            }
                            .accessibilityLabel(isPlayingThis ? loc.t("quran_stop", fallback: "Durdur") : loc.t("quran_listen", fallback: "Sesli Oku"))
                        }
                    }
                    Text(dua.arabic)
                        .font(.system(size: 22))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .foregroundColor(AppTheme.textPrimary(colorScheme))
                    Text(loc.t("dua\(duaNumber(dua))_trans", fallback: dua.okunus))
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                    Text(loc.t("dua\(duaNumber(dua))_meal", fallback: dua.meal))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary(colorScheme))
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background(colorScheme).ignoresSafeArea())
            .onDisappear { recitation.stop() }
            .navigationTitle(loc.t("more_duas", fallback: "Namaz Duaları"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(loc.t("common_close", fallback: "Kapat"))
                }
            }
        }
    }
}

#Preview {
    PrayerDuasView()
}
