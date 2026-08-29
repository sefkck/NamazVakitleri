import SwiftUI

struct Surah: Identifiable {
    let id = UUID()
    let name: String
    let arabic: String
    let meal: String
}

struct QuranView: View {
    @Environment(\.dismiss) private var dismiss

    // NOT: Bu, sık okunan kısa surelerden oluşan bir başlangıç seti.
    // Kuran'ın tamamı (114 sure) için ileride bir Kuran API'si ya da
    // veri seti entegrasyonu yapılması gerekir.
    private let surahs: [Surah] = [
        Surah(name: "Fatiha Suresi",
              arabic: "بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيمِ ﴿١﴾ اَلْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمِينَ ﴿٢﴾ الرَّحْمٰنِ الرَّحِيمِ ﴿٣﴾ مَالِكِ يَوْمِ الدِّينِ ﴿٤﴾ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ﴿٥﴾ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ﴿٦﴾ صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ ﴿٧﴾",
              meal: "Rahman ve Rahim olan Allah'ın adıyla. Hamd, alemlerin Rabbi Allah'a mahsustur. O, Rahman ve Rahim'dir. Din gününün sahibidir. Yalnız sana ibadet eder, yalnız senden yardım dileriz. Bizi doğru yola ilet; kendilerine nimet verdiklerinin yoluna, gazaba uğrayanların ve sapanların yoluna değil."),
        Surah(name: "İhlas Suresi",
              arabic: "قُلْ هُوَ اللّٰهُ أَحَدٌ ﴿١﴾ اللّٰهُ الصَّمَدُ ﴿٢﴾ لَمْ يَلِدْ وَلَمْ يُولَدْ ﴿٣﴾ وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ ﴿٤﴾",
              meal: "De ki: O, Allah'tır, tektir. Allah, her şeyin kendisine muhtaç olduğu, hiçbir şeye muhtaç olmayandır. Doğurmamış ve doğurulmamıştır. Hiçbir şey O'na denk değildir."),
        Surah(name: "Felak Suresi",
              arabic: "قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ﴿١﴾ مِنْ شَرِّ مَا خَلَقَ ﴿٢﴾ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ﴿٣﴾ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ﴿٤﴾ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ ﴿٥﴾",
              meal: "De ki: Sabahın Rabbine sığınırım; yarattıklarının şerrinden, karanlığı çöktüğünde gecenin şerrinden, düğümlere üfleyenlerin şerrinden ve haset ettiğinde hasetçinin şerrinden."),
        Surah(name: "Nas Suresi",
              arabic: "قُلْ أَعُوذُ بِرَبِّ النَّاسِ ﴿١﴾ مَلِكِ النَّاسِ ﴿٢﴾ إِلٰهِ النَّاسِ ﴿٣﴾ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ﴿٤﴾ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ﴿٥﴾ مِنَ الْجِنَّةِ وَالنَّاسِ ﴿٦﴾",
              meal: "De ki: İnsanların Rabbine, insanların Melikine, insanların İlahına sığınırım; sinsi vesvesecinin şerrinden; o ki insanların göğüslerine vesvese verir; cinlerden ve insanlardan."),
        Surah(name: "Kevser Suresi",
              arabic: "إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ ﴿١﴾ فَصَلِّ لِرَبِّكَ وَانْحَرْ ﴿٢﴾ إِنَّ شَانِئَكَ هُوَ الْأَبْتَرُ ﴿٣﴾",
              meal: "Şüphesiz biz sana Kevser'i verdik. Öyleyse Rabbin için namaz kıl ve kurban kes. Doğrusu sana buğzeden, soyu kesik olandır."),
        Surah(name: "Asr Suresi",
              arabic: "وَالْعَصْرِ ﴿١﴾ إِنَّ الْإِنْسَانَ لَفِي خُسْرٍ ﴿٢﴾ إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّبْرِ ﴿٣﴾",
              meal: "Asra yemin olsun ki, insan gerçekten ziyandadır. Ancak iman edip salih ameller işleyenler, birbirlerine hakkı tavsiye edenler ve birbirlerine sabrı tavsiye edenler müstesna.")
    ]

    var body: some View {
        NavigationView {
            ProGatedContent(title: "Kuran-ı Kerim") {
                List(surahs) { surah in
                    NavigationLink(surah.name) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(surah.arabic)
                                    .font(.system(size: 24))
                                    .multilineTextAlignment(.trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                                Divider()
                                Text(surah.meal)
                                    .font(.body)
                            }
                            .padding()
                        }
                        .navigationTitle(surah.name)
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
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

#Preview {
    QuranView().environmentObject(UserStore())
}
