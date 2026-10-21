import Foundation

/// 114 surenin Türkçe adı ve anlamı. Türkçe arayüzde sure listesinde
/// "The Cow" gibi İngilizce adlar yerine bunlar gösterilir.
enum SurahNames {
    /// numara: (Türkçe ad, anlamı)
    static let turkish: [Int: (name: String, meaning: String)] = [
        1: ("Fâtiha", "Açılış"), 2: ("Bakara", "İnek"), 3: ("Âl-i İmrân", "İmran Ailesi"),
        4: ("Nisâ", "Kadınlar"), 5: ("Mâide", "Sofra"), 6: ("En'âm", "Davarlar"),
        7: ("A'râf", "Yüksek Yerler"), 8: ("Enfâl", "Ganimetler"), 9: ("Tevbe", "Tövbe"),
        10: ("Yûnus", "Yunus"), 11: ("Hûd", "Hud"), 12: ("Yûsuf", "Yusuf"),
        13: ("Ra'd", "Gök Gürültüsü"), 14: ("İbrâhîm", "İbrahim"), 15: ("Hicr", "Hicr"),
        16: ("Nahl", "Bal Arısı"), 17: ("İsrâ", "Gece Yürüyüşü"), 18: ("Kehf", "Mağara"),
        19: ("Meryem", "Meryem"), 20: ("Tâhâ", "Tâhâ"), 21: ("Enbiyâ", "Peygamberler"),
        22: ("Hac", "Hac"), 23: ("Mü'minûn", "Müminler"), 24: ("Nûr", "Nur"),
        25: ("Furkân", "Ayırt Edici"), 26: ("Şuarâ", "Şairler"), 27: ("Neml", "Karınca"),
        28: ("Kasas", "Kıssalar"), 29: ("Ankebût", "Örümcek"), 30: ("Rûm", "Bizanslılar"),
        31: ("Lokmân", "Lokman"), 32: ("Secde", "Secde"), 33: ("Ahzâb", "Topluluklar"),
        34: ("Sebe", "Sebe"), 35: ("Fâtır", "Yaratan"), 36: ("Yâsîn", "Yâsîn"),
        37: ("Sâffât", "Saf Tutanlar"), 38: ("Sâd", "Sâd"), 39: ("Zümer", "Gruplar"),
        40: ("Mü'min", "İnanan"), 41: ("Fussilet", "Ayrıntılı Açıklanan"), 42: ("Şûrâ", "Danışma"),
        43: ("Zuhruf", "Altın Süsler"), 44: ("Duhân", "Duman"), 45: ("Câsiye", "Diz Çöken"),
        46: ("Ahkâf", "Kum Tepeleri"), 47: ("Muhammed", "Muhammed"), 48: ("Fetih", "Fetih"),
        49: ("Hucurât", "Odalar"), 50: ("Kâf", "Kâf"), 51: ("Zâriyât", "Savuranlar"),
        52: ("Tûr", "Tur"), 53: ("Necm", "Yıldız"), 54: ("Kamer", "Ay"),
        55: ("Rahmân", "Rahman"), 56: ("Vâkıa", "Gerçekleşen"), 57: ("Hadîd", "Demir"),
        58: ("Mücâdele", "Tartışma"), 59: ("Haşr", "Toplanma"), 60: ("Mümtehine", "Sınanan Kadın"),
        61: ("Saff", "Saf"), 62: ("Cuma", "Cuma"), 63: ("Münâfikûn", "Münafıklar"),
        64: ("Teğâbün", "Aldanma"), 65: ("Talâk", "Boşanma"), 66: ("Tahrîm", "Yasaklama"),
        67: ("Mülk", "Egemenlik"), 68: ("Kalem", "Kalem"), 69: ("Hâkka", "Gerçekleşen Hak"),
        70: ("Meâric", "Yükseliş Yolları"), 71: ("Nûh", "Nuh"), 72: ("Cin", "Cinler"),
        73: ("Müzzemmil", "Örtünen"), 74: ("Müddessir", "Bürünen"), 75: ("Kıyâme", "Kıyamet"),
        76: ("İnsân", "İnsan"), 77: ("Mürselât", "Gönderilenler"), 78: ("Nebe", "Haber"),
        79: ("Nâziât", "Söküp Çıkaranlar"), 80: ("Abese", "Surat Astı"), 81: ("Tekvîr", "Dürülme"),
        82: ("İnfitâr", "Yarılma"), 83: ("Mutaffifîn", "Ölçüde Hile Yapanlar"), 84: ("İnşikâk", "Çatlama"),
        85: ("Bürûc", "Burçlar"), 86: ("Târık", "Gece Gelen"), 87: ("A'lâ", "En Yüce"),
        88: ("Gâşiye", "Kuşatan"), 89: ("Fecr", "Şafak"), 90: ("Beled", "Şehir"),
        91: ("Şems", "Güneş"), 92: ("Leyl", "Gece"), 93: ("Duhâ", "Kuşluk Vakti"),
        94: ("İnşirâh", "Ferahlık"), 95: ("Tîn", "İncir"), 96: ("Alak", "Kan Pıhtısı"),
        97: ("Kadr", "Kadir"), 98: ("Beyyine", "Açık Delil"), 99: ("Zilzâl", "Deprem"),
        100: ("Âdiyât", "Koşanlar"), 101: ("Kâria", "Çarpan"), 102: ("Tekâsür", "Çoğalma Yarışı"),
        103: ("Asr", "Zaman"), 104: ("Hümeze", "Gıybet Edenler"), 105: ("Fîl", "Fil"),
        106: ("Kureyş", "Kureyş"), 107: ("Mâûn", "Yardım"), 108: ("Kevser", "Kevser"),
        109: ("Kâfirûn", "Kâfirler"), 110: ("Nasr", "Yardım"), 111: ("Tebbet", "Kurusun"),
        112: ("İhlâs", "Samimiyet"), 113: ("Felak", "Şafak"), 114: ("Nâs", "İnsanlar")
    ]

    /// Ekranda gösterilecek sure başlığı. Türkçede "Bakara (İnek)" gibi,
    /// ad ile anlam aynıysa sadece ad ("Meryem"). Diğer dillerde kaynaktan
    /// gelen İngilizce ad aynen kullanılır.
    static func title(number: Int, englishFallback: String) -> String {
        guard LocalizationManager.shared.language == .turkish,
              let entry = turkish[number] else { return englishFallback }
        return entry.name == entry.meaning ? entry.name : "\(entry.name) (\(entry.meaning))"
    }

    /// Sure başlığı, seçili dile göre: Türkçe ad + anlam; İngilizcede
    /// İngilizce anlam; Arapçada Arapça ad; diğer dillerde (ör. Almanca)
    /// İngilizce çeviri yerine evrensel okunuş adı ("Al-Faatiha").
    static func title(for surah: QuranSurahSummary) -> String {
        switch LocalizationManager.shared.language {
        case .turkish: return title(number: surah.number, englishFallback: surah.englishNameTranslation)
        case .english: return surah.englishNameTranslation
        case .arabic: return surah.name
        case .german: return surah.englishName
        }
    }
}
