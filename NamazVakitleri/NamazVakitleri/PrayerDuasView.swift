import SwiftUI

struct PrayerDua: Identifiable {
    let id = UUID()
    let title: String
    let arabic: String
    let meal: String
}

struct PrayerDuasView: View {
    @Environment(\.dismiss) private var dismiss

    private let duas: [PrayerDua] = [
        PrayerDua(title: "Sübhaneke",
                  arabic: "سُبْحَانَكَ اللّٰهُمَّ وَبِحَمْدِكَ، وَتَبَارَكَ اسْمُكَ، وَتَعَالٰى جَدُّكَ، وَلَا إِلٰهَ غَيْرُكَ",
                  meal: "Allah'ım, seni her türlü eksiklikten tenzih eder, sana hamd ederim. Adın mübarektir, şanın yücedir. Senden başka ilah yoktur."),
        PrayerDua(title: "Ettehiyyatü (Tahiyyat)",
                  arabic: "التَّحِيَّاتُ لِلّٰهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ، السَّلَامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللّٰهِ وَبَرَكَاتُهُ، السَّلَامُ عَلَيْنَا وَعَلٰى عِبَادِ اللّٰهِ الصَّالِحِينَ، أَشْهَدُ أَنْ لَا إِلٰهَ إِلَّا اللّٰهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ",
                  meal: "Bütün dil, beden ve mal ile yapılan ibadetler Allah'a mahsustur. Ey Peygamber, Allah'ın selamı, rahmeti ve bereketi senin üzerine olsun. Selam bizim ve Allah'ın iyi kullarının üzerine olsun. Şahitlik ederim ki Allah'tan başka ilah yoktur, yine şahitlik ederim ki Muhammed O'nun kulu ve elçisidir."),
        PrayerDua(title: "Allahümme Salli",
                  arabic: "اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ وَعَلٰى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلٰى إِبْرَاهِيمَ وَعَلٰى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ",
                  meal: "Allah'ım, İbrahim'e ve ailesine salat ettiğin gibi Muhammed'e ve ailesine de salat et. Şüphesiz sen övgüye layık ve yücesin."),
        PrayerDua(title: "Allahümme Barik",
                  arabic: "اَللّٰهُمَّ بَارِكْ عَلٰى مُحَمَّدٍ وَعَلٰى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلٰى إِبْرَاهِيمَ وَعَلٰى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ",
                  meal: "Allah'ım, İbrahim'e ve ailesine bereket verdiğin gibi Muhammed'e ve ailesine de bereket ver. Şüphesiz sen övgüye layık ve yücesin."),
        PrayerDua(title: "Rabbena Atina",
                  arabic: "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ",
                  meal: "Rabbimiz, bize dünyada iyilik, ahirette de iyilik ver ve bizi ateşin azabından koru."),
        PrayerDua(title: "Kunut Duası 1",
                  arabic: "اَللّٰهُمَّ إِنَّا نَسْتَعِينُكَ وَنَسْتَغْفِرُكَ وَنُؤْمِنُ بِكَ وَنَتَوَكَّلُ عَلَيْكَ",
                  meal: "Allah'ım, senden yardım ister, senden bağışlanma dileriz. Sana inanır, sana güveniriz."),
        PrayerDua(title: "Kunut Duası 2",
                  arabic: "اَللّٰهُمَّ إِيَّاكَ نَعْبُدُ وَلَكَ نُصَلِّي وَنَسْجُدُ وَإِلَيْكَ نَسْعٰى وَنَحْفِدُ نَرْجُو رَحْمَتَكَ وَنَخْشٰى عَذَابَكَ إِنَّ عَذَابَكَ بِالْكُفَّارِ مُلْحِقٌ",
                  meal: "Allah'ım, yalnız sana ibadet eder, senin için namaz kılar ve secde ederiz. Yalnız sana koşar ve sana yaklaştırıcı işler yaparız. Rahmetini umar, azabından korkarız. Şüphesiz senin azabın kâfirlere ulaşır.")
    ]

    var body: some View {
        NavigationView {
            ProGatedContent(title: "Namaz Duaları") {
                List(duas) { dua in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dua.title)
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text(dua.arabic)
                            .font(.system(size: 22))
                            .multilineTextAlignment(.trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(dua.meal)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Namaz Duaları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PrayerDuasView().environmentObject(UserStore())
}
