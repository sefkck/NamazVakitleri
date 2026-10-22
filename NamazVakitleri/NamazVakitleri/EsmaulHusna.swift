import Foundation

/// Esmâ-i Hüsnâ: Allah'ın 99 güzel ismi (Tirmizî rivayeti sırası).
/// Arapça yazım ve İngilizce anlam: AlAdhan (api.aladhan.com/v1/asmaAlHusna);
/// Türkçe okunuş ve anlamlar Diyanet kaynaklarındaki yaygın karşılıklara göre.
enum EsmaulHusna {
    struct Name: Identifiable {
        let arabic: String
        let turkish: String
        let meaningTR: String
        let latin: String
        let meaningEN: String
        var id: String { arabic }

        /// Seçili dile göre okunuş.
        var displayName: String { displayName(in: LocalizationManager.shared.language) }
        func displayName(in language: AppLanguage) -> String { language == .turkish ? turkish : latin }
        /// Seçili dile göre anlam (Arapça arayüzde anlam gösterilmez).
        var meaning: String? { meaning(in: LocalizationManager.shared.language) }
        func meaning(in language: AppLanguage) -> String? {
            switch language {
            case .turkish: return meaningTR
            case .arabic: return nil
            case .english, .german: return meaningEN
            }
        }
    }

    static let all: [Name] = [
        Name(arabic: "الرَّحْمَنُ", turkish: "er-Rahmân", meaningTR: "Dünyada bütün yaratılmışlara merhamet eden", latin: "Ar Rahmaan", meaningEN: "The Beneficent"),
        Name(arabic: "الرَّحِيمُ", turkish: "er-Rahîm", meaningTR: "Âhirette müminlere sonsuz merhamet eden", latin: "Ar Raheem", meaningEN: "The Merciful"),
        Name(arabic: "الْمَلِكُ", turkish: "el-Melik", meaningTR: "Mülkün, kâinatın tek sahibi", latin: "Al Malik", meaningEN: "The King / Eternal Lord"),
        Name(arabic: "الْقُدُّوسُ", turkish: "el-Kuddûs", meaningTR: "Her türlü eksiklikten uzak, tertemiz", latin: "Al Quddus", meaningEN: "The Purest"),
        Name(arabic: "السَّلاَمُ", turkish: "es-Selâm", meaningTR: "Kullarını esenliğe çıkaran", latin: "As Salaam", meaningEN: "The Source of Peace"),
        Name(arabic: "الْمُؤْمِنُ", turkish: "el-Mü'min", meaningTR: "Güven veren, vaadine sadık", latin: "Al Mu'min", meaningEN: "The inspirer of faith"),
        Name(arabic: "الْمُهَيْمِنُ", turkish: "el-Müheymin", meaningTR: "Her şeyi görüp gözeten", latin: "Al Muhaymin", meaningEN: "The Guardian"),
        Name(arabic: "الْعَزِيزُ", turkish: "el-Azîz", meaningTR: "Mağlup edilmesi imkânsız, üstün", latin: "Al Azeez", meaningEN: "The Precious / The Most Mighty"),
        Name(arabic: "الْجَبَّارُ", turkish: "el-Cebbâr", meaningTR: "Dilediğini yaptıran, kırıkları onaran", latin: "Al Jabbaar", meaningEN: "The Compeller"),
        Name(arabic: "الْمُتَكَبِّرُ", turkish: "el-Mütekebbir", meaningTR: "Büyüklükte eşi olmayan", latin: "Al Mutakabbir", meaningEN: "The Greatest"),
        Name(arabic: "الْخَالِقُ", turkish: "el-Hâlık", meaningTR: "Her şeyi yoktan yaratan", latin: "Al Khaaliq", meaningEN: "The Creator"),
        Name(arabic: "الْبَارِئُ", turkish: "el-Bâri'", meaningTR: "Her şeyi kusursuz, uyumlu yaratan", latin: "Al Baari", meaningEN: "The Maker of Order"),
        Name(arabic: "الْمُصَوِّرُ", turkish: "el-Musavvir", meaningTR: "Her şeye bir şekil veren", latin: "Al Musawwir", meaningEN: "The Shaper of Beauty"),
        Name(arabic: "الْغَفَّارُ", turkish: "el-Gaffâr", meaningTR: "Günahları çokça örten ve bağışlayan", latin: "Al Ghaffaar", meaningEN: "The Forgiving"),
        Name(arabic: "الْقَهَّارُ", turkish: "el-Kahhâr", meaningTR: "Her şeye galip gelen", latin: "Al Qahhaar", meaningEN: "The Subduer"),
        Name(arabic: "الْوَهَّابُ", turkish: "el-Vehhâb", meaningTR: "Karşılıksız bol nimet veren", latin: "Al Wahhaab", meaningEN: "The Giver of All"),
        Name(arabic: "الرَّزَّاقُ", turkish: "er-Rezzâk", meaningTR: "Bütün canlıların rızkını veren", latin: "Ar Razzaaq", meaningEN: "The Sustainer"),
        Name(arabic: "الْفَتَّاحُ", turkish: "el-Fettâh", meaningTR: "Her türlü zorluğu açan, hayır kapılarını açan", latin: "Al Fattaah", meaningEN: "The Opener"),
        Name(arabic: "اَلْعَلِيْمُ", turkish: "el-Alîm", meaningTR: "Her şeyi en ince ayrıntısıyla bilen", latin: "Al 'Aleem", meaningEN: "The Knower of all"),
        Name(arabic: "الْقَابِضُ", turkish: "el-Kâbıd", meaningTR: "Dilediğine darlık veren", latin: "Al Qaabid", meaningEN: "The Constrictor"),
        Name(arabic: "الْبَاسِطُ", turkish: "el-Bâsıt", meaningTR: "Dilediğine bolluk veren", latin: "Al Baasit", meaningEN: "The Reliever"),
        Name(arabic: "الْخَافِضُ", turkish: "el-Hâfıd", meaningTR: "Dilediğini alçaltan", latin: "Al Khaafid", meaningEN: "The Abaser"),
        Name(arabic: "الرَّافِعُ", turkish: "er-Râfi'", meaningTR: "Dilediğini yükselten", latin: "Ar Raafi'", meaningEN: "The Exalter"),
        Name(arabic: "الْمُعِزُّ", turkish: "el-Muiz", meaningTR: "Dilediğine izzet veren", latin: "Al Mu'iz", meaningEN: "The Bestower of Honour"),
        Name(arabic: "المُذِلُّ", turkish: "el-Müzil", meaningTR: "Dilediğini zillete düşüren", latin: "Al Mudhil", meaningEN: "The Humiliator"),
        Name(arabic: "السَّمِيعُ", turkish: "es-Semî'", meaningTR: "Her şeyi işiten", latin: "As Samee'", meaningEN: "The Hearer of all"),
        Name(arabic: "الْبَصِيرُ", turkish: "el-Basîr", meaningTR: "Her şeyi gören", latin: "Al Baseer", meaningEN: "The Seer of all"),
        Name(arabic: "الْحَكَمُ", turkish: "el-Hakem", meaningTR: "Mutlak hüküm veren", latin: "Al Hakam", meaningEN: "The Judge"),
        Name(arabic: "الْعَدْلُ", turkish: "el-Adl", meaningTR: "Mutlak adaletli", latin: "Al 'Adl", meaningEN: "The Just"),
        Name(arabic: "اللَّطِيفُ", turkish: "el-Latîf", meaningTR: "Lütfu bol, en ince işleri bilen", latin: "Al Lateef", meaningEN: "The Subtle One"),
        Name(arabic: "الْخَبِيرُ", turkish: "el-Habîr", meaningTR: "Her şeyin iç yüzünden haberdar", latin: "Al Khabeer", meaningEN: "The All Aware"),
        Name(arabic: "الْحَلِيمُ", turkish: "el-Halîm", meaningTR: "Cezada acele etmeyen, yumuşak davranan", latin: "Al Haleem", meaningEN: "The Forebearing"),
        Name(arabic: "الْعَظِيمُ", turkish: "el-Azîm", meaningTR: "Pek yüce, pek büyük", latin: "Al 'Azeem", meaningEN: "The Maginificent"),
        Name(arabic: "الْغَفُورُ", turkish: "el-Gafûr", meaningTR: "Bağışlaması çok olan", latin: "Al Ghafoor", meaningEN: "The Great Forgiver"),
        Name(arabic: "الشَّكُورُ", turkish: "eş-Şekûr", meaningTR: "Az amele çok sevap veren", latin: "Ash Shakoor", meaningEN: "The Rewarder of Thankfulness"),
        Name(arabic: "الْعَلِيُّ", turkish: "el-Aliyy", meaningTR: "Yüceler yücesi", latin: "Al 'Aliyy", meaningEN: "The Highest"),
        Name(arabic: "الْكَبِيرُ", turkish: "el-Kebîr", meaningTR: "Büyüklükte benzeri olmayan", latin: "Al Kabeer", meaningEN: "The Greatest"),
        Name(arabic: "الْحَفِيظُ", turkish: "el-Hafîz", meaningTR: "Her şeyi koruyan", latin: "Al Hafeez", meaningEN: "The Preserver"),
        Name(arabic: "المُقيِت", turkish: "el-Mukît", meaningTR: "Her canlının yiyeceğini veren", latin: "Al Muqeet", meaningEN: "The Nourisher"),
        Name(arabic: "الْحسِيبُ", turkish: "el-Hasîb", meaningTR: "Kulların hesabını gören", latin: "Al Haseeb", meaningEN: "The Reckoner"),
        Name(arabic: "الْجَلِيلُ", turkish: "el-Celîl", meaningTR: "Celal ve azamet sahibi", latin: "Al Jaleel", meaningEN: "The Majestic"),
        Name(arabic: "الْكَرِيمُ", turkish: "el-Kerîm", meaningTR: "Cömertliği sonsuz", latin: "Al Kareem", meaningEN: "The Generous"),
        Name(arabic: "الرَّقِيبُ", turkish: "er-Rakîb", meaningTR: "Her şeyi gözetleyen", latin: "Ar Raqeeb", meaningEN: "The Watchful One"),
        Name(arabic: "الْمُجِيبُ", turkish: "el-Mucîb", meaningTR: "Duaları kabul eden", latin: "Al Mujeeb", meaningEN: "The Responder to Prayer"),
        Name(arabic: "الْوَاسِعُ", turkish: "el-Vâsi'", meaningTR: "İlmi ve rahmeti her şeyi kuşatan", latin: "Al Waasi'", meaningEN: "The All Comprehending"),
        Name(arabic: "الْحَكِيمُ", turkish: "el-Hakîm", meaningTR: "Her işi hikmetli olan", latin: "Al Hakeem", meaningEN: "The Perfectly Wise"),
        Name(arabic: "الْوَدُودُ", turkish: "el-Vedûd", meaningTR: "Kullarını seven, sevilmeye layık olan", latin: "Al Wudood", meaningEN: "The Loving One"),
        Name(arabic: "الْمَجِيدُ", turkish: "el-Mecîd", meaningTR: "Şanı yüce, şerefi büyük", latin: "Al Majeed", meaningEN: "The Most Glorious One"),
        Name(arabic: "الْبَاعِثُ", turkish: "el-Bâis", meaningTR: "Ölüleri dirilten", latin: "Al Baa'ith", meaningEN: "The Resurrector"),
        Name(arabic: "الشَّهِيدُ", turkish: "eş-Şehîd", meaningTR: "Her zaman her yerde hazır ve nazır", latin: "Ash Shaheed", meaningEN: "The Witness"),
        Name(arabic: "الْحَقُّ", turkish: "el-Hak", meaningTR: "Varlığı hiç değişmeden duran, gerçek", latin: "Al Haqq", meaningEN: "The Truth"),
        Name(arabic: "الْوَكِيلُ", turkish: "el-Vekîl", meaningTR: "Kendisine güvenilen, işleri yoluna koyan", latin: "Al Wakeel", meaningEN: "The Trustee"),
        Name(arabic: "الْقَوِيُّ", turkish: "el-Kaviyy", meaningTR: "Kudreti en üstün", latin: "Al Qawiyy", meaningEN: "The Possessor of all strength"),
        Name(arabic: "الْمَتِينُ", turkish: "el-Metîn", meaningTR: "Kuvvet ve kudretinde sarsılmaz", latin: "Al Mateen", meaningEN: "The Forceful"),
        Name(arabic: "الْوَلِيُّ", turkish: "el-Veliyy", meaningTR: "İnananların dostu", latin: "Al Waliyy", meaningEN: "The Protector"),
        Name(arabic: "الْحَمِيدُ", turkish: "el-Hamîd", meaningTR: "Övülmeye layık", latin: "Al Hameed", meaningEN: "The Praised"),
        Name(arabic: "الْمُحْصِي", turkish: "el-Muhsî", meaningTR: "Her şeyin sayısını bilen", latin: "Al Muhsi", meaningEN: "The Appraiser"),
        Name(arabic: "الْمُبْدِئُ", turkish: "el-Mübdi'", meaningTR: "Örneksiz yaratan", latin: "Al Mubdi", meaningEN: "The Originator"),
        Name(arabic: "الْمُعِيدُ", turkish: "el-Muîd", meaningTR: "Yarattıklarını yok edip tekrar dirilten", latin: "Al Mu'eed", meaningEN: "The Restorer"),
        Name(arabic: "الْمُحْيِي", turkish: "el-Muhyî", meaningTR: "Can veren", latin: "Al Muhiy", meaningEN: "The Giver of life"),
        Name(arabic: "اَلْمُمِيتُ", turkish: "el-Mümît", meaningTR: "Ölümü yaratan", latin: "Al Mumeet", meaningEN: "The Taker of life"),
        Name(arabic: "الْحَيُّ", turkish: "el-Hayy", meaningTR: "Ezeli ve ebedi diri", latin: "Al Haiyy", meaningEN: "The Ever Living"),
        Name(arabic: "الْقَيُّومُ", turkish: "el-Kayyûm", meaningTR: "Her şeyi ayakta tutan", latin: "Al Qayyoom", meaningEN: "The Self Existing"),
        Name(arabic: "الْوَاجِدُ", turkish: "el-Vâcid", meaningTR: "İstediğini istediği anda bulan", latin: "Al Waajid", meaningEN: "The Finder"),
        Name(arabic: "الْمَاجِدُ", turkish: "el-Mâcid", meaningTR: "Kadri ve şanı yüce", latin: "Al Maajid", meaningEN: "The Glorious"),
        Name(arabic: "الْواحِدُ", turkish: "el-Vâhid", meaningTR: "Tek olan", latin: "Al Waahid", meaningEN: "The Only One"),
        Name(arabic: "اَلاَحَدُ", turkish: "el-Ehad", meaningTR: "Bir olan, eşi ve benzeri olmayan", latin: "Al Ahad", meaningEN: "The One"),
        Name(arabic: "الصَّمَدُ", turkish: "es-Samed", meaningTR: "Hiçbir şeye muhtaç olmayan, her şeyin ona muhtaç olduğu", latin: "As Samad", meaningEN: "The Supreme Provider"),
        Name(arabic: "الْقَادِرُ", turkish: "el-Kâdir", meaningTR: "Her şeye gücü yeten", latin: "Al Qaadir", meaningEN: "The Powerful"),
        Name(arabic: "الْمُقْتَدِرُ", turkish: "el-Muktedir", meaningTR: "Kudret sahiplerinin üstünde kudret sahibi", latin: "Al Muqtadir", meaningEN: "The Creator of all power"),
        Name(arabic: "الْمُقَدِّمُ", turkish: "el-Mukaddim", meaningTR: "Dilediğini öne alan", latin: "Al Muqaddim", meaningEN: "The Expediter"),
        Name(arabic: "الْمُؤَخِّرُ", turkish: "el-Muahhir", meaningTR: "Dilediğini geriye bırakan", latin: "Al Mu’akhir", meaningEN: "The Delayer"),
        Name(arabic: "الأوَّلُ", turkish: "el-Evvel", meaningTR: "Varlığının başlangıcı olmayan", latin: "Al Awwal", meaningEN: "The First"),
        Name(arabic: "الآخِرُ", turkish: "el-Âhir", meaningTR: "Varlığının sonu olmayan", latin: "Al Aakhir", meaningEN: "The Last"),
        Name(arabic: "الظَّاهِرُ", turkish: "ez-Zâhir", meaningTR: "Varlığı açık olan", latin: "Az Zaahir", meaningEN: "The Manifest"),
        Name(arabic: "الْبَاطِنُ", turkish: "el-Bâtın", meaningTR: "Zatının hakikati gizli olan", latin: "Al Baatin", meaningEN: "The Hidden"),
        Name(arabic: "الْوَالِي", turkish: "el-Vâlî", meaningTR: "Bütün kâinatı yöneten", latin: "Al Waali", meaningEN: "The Governor"),
        Name(arabic: "الْمُتَعَالِي", turkish: "el-Müteâlî", meaningTR: "Son derece yüce", latin: "Al Muta’ali", meaningEN: "The Supreme One"),
        Name(arabic: "الْبَرُّ", turkish: "el-Berr", meaningTR: "İyiliği bol olan", latin: "Al Barr", meaningEN: "The Doer of Good"),
        Name(arabic: "التَّوَابُ", turkish: "et-Tevvâb", meaningTR: "Tövbeleri kabul eden", latin: "At Tawwaab", meaningEN: "The Guide to Repentence"),
        Name(arabic: "الْمُنْتَقِمُ", turkish: "el-Müntakim", meaningTR: "Suçluları adaletle cezalandıran", latin: "Al Muntaqim", meaningEN: "The Avenger"),
        Name(arabic: "العَفُوُّ", turkish: "el-Afüvv", meaningTR: "Affı çok olan", latin: "Al Afuww", meaningEN: "The Forgiver"),
        Name(arabic: "الرَّؤُوفُ", turkish: "er-Raûf", meaningTR: "Çok şefkatli", latin: "Ar Ra’oof", meaningEN: "The Clement"),
        Name(arabic: "مَالِكُ الْمُلْكِ", turkish: "Mâlikü'l-Mülk", meaningTR: "Mülkün ebedi sahibi", latin: "Maalik Ul Mulk", meaningEN: "The Owner / Soverign of All"),
        Name(arabic: "ذُوالْجَلاَلِ وَالإكْرَامِ", turkish: "Zü'l-Celâli ve'l-İkrâm", meaningTR: "Celal ve ikram sahibi", latin: "Dhu Al Jalaali Wa Al Ikraam", meaningEN: "Possessor of Majesty and Bounty"),
        Name(arabic: "الْمُقْسِطُ", turkish: "el-Muksit", meaningTR: "Her işi adaletle yapan", latin: "Al Muqsit", meaningEN: "The Equitable One"),
        Name(arabic: "الْجَامِعُ", turkish: "el-Câmi'", meaningTR: "Dilediğini dilediği yerde toplayan", latin: "Al Jaami'", meaningEN: "The Gatherer"),
        Name(arabic: "الْغَنِيُّ", turkish: "el-Ganiyy", meaningTR: "Hiçbir şeye muhtaç olmayan", latin: "Al Ghaniyy", meaningEN: "The Rich One"),
        Name(arabic: "الْمُغْنِي", turkish: "el-Muğnî", meaningTR: "Dilediğini zengin eden", latin: "Al Mughi", meaningEN: "The Enricher"),
        Name(arabic: "اَلْمَانِعُ", turkish: "el-Mâni'", meaningTR: "Dilemediği şeye engel olan", latin: "Al Maani'", meaningEN: "The Preventer of harm"),
        Name(arabic: "الضَّارَّ", turkish: "ed-Dârr", meaningTR: "Elem ve zarar verecek şeyleri yaratan", latin: "Ad Daaarr", meaningEN: "The Creator of the harmful"),
        Name(arabic: "النَّافِعُ", turkish: "en-Nâfi'", meaningTR: "Fayda veren şeyleri yaratan", latin: "An Naafi’", meaningEN: "The Bestower of Benefits"),
        Name(arabic: "النُّورُ", turkish: "en-Nûr", meaningTR: "Âlemleri nurlandıran", latin: "An Noor", meaningEN: "The Light"),
        Name(arabic: "الْهَادِي", turkish: "el-Hâdî", meaningTR: "Hidayet veren", latin: "Al Haadi", meaningEN: "The Guider"),
        Name(arabic: "الْبَدِيعُ", turkish: "el-Bedî'", meaningTR: "Benzeri olmayan güzellikte yaratan", latin: "Al Badi'", meaningEN: "The Originator"),
        Name(arabic: "اَلْبَاقِي", turkish: "el-Bâkî", meaningTR: "Varlığının sonu olmayan, ebedi", latin: "Al Baaqi", meaningEN: "The Everlasting One"),
        Name(arabic: "الْوَارِثُ", turkish: "el-Vâris", meaningTR: "Her şeyin asıl sahibi olarak kalan", latin: "Al Waarith", meaningEN: "The Inhertior"),
        Name(arabic: "الرَّشِيدُ", turkish: "er-Reşîd", meaningTR: "Doğru yolu gösteren", latin: "Ar Rasheed", meaningEN: "The Most Righteous Guide"),
        Name(arabic: "الصَّبُورُ", turkish: "es-Sabûr", meaningTR: "Çok sabırlı", latin: "As Saboor", meaningEN: "The Patient One")
    ]

    /// Günün ismi: yılın gününe göre sırayla (her gün başka bir isim).
    static func nameOfDay(_ date: Date = Date()) -> Name {
        let day = Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: date) ?? 1
        return all[(day - 1) % all.count]
    }
}
