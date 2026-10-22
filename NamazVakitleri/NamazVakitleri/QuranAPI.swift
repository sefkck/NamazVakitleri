import Foundation

struct QuranSurahSummary: Codable, Identifiable, Hashable {
    let number: Int
    let name: String
    let englishName: String
    let englishNameTranslation: String
    let numberOfAyahs: Int
    let revelationType: String

    var id: Int { number }
}

struct QuranAyah: Codable, Identifiable {
    let number: Int
    let text: String
    let numberInSurah: Int

    var id: Int { number }
}

private struct QuranSurahDetail: Codable {
    let number: Int
    let ayahs: [QuranAyah]
}

private struct SurahListResponse: Codable {
    let data: [QuranSurahSummary]
}

private struct SurahDetailResponse: Codable {
    let data: QuranSurahDetail
}

/// Sure metnini (Arapça + Latin harfli okunuş + seçili dilde meal)
/// alquran.cloud API'sinden çeker, tekrar indirmemek için diske
/// önbelleğe alır. Sure listesi de önbelleğe alınır; bir kez açılan
/// sureler ve liste internetsiz de çalışır.
final class QuranAPI {
    static let shared = QuranAPI()
    private init() {}

    struct SurahContent {
        let arabic: [QuranAyah]
        let transliteration: [QuranAyah]
        let meal: [QuranAyah]
    }

    enum APIError: Error {
        case badResponse
    }

    private let baseURL = "https://api.alquran.cloud/v1"

    /// Meal baskısı sabit: rastgele bir baskıya ya da başka bir dile
    /// düşmüyoruz. Arapça arayüzde ayrıca meal gösterilmez.
    static func mealEdition(for language: AppLanguage) -> String? {
        switch language {
        // tr.diyanet kaynağı birkaç ayeti tek cümlede birleştirip aynı meali
        // ardışık ayetlerde tekrarlıyor (tüm Kur'an'da 841 ayet). Diyanet
        // Vakfı meali ayet ayet çevrilmiş (sadece 10 tekrar).
        case .turkish: return "tr.vakfi"
        // Pickthall (1930): yazar 1936'da öldü; telifsiz. Saheeh International'ın kullanım izni yoktu.
        case .english: return "en.pickthall"
        // Bubenheim & Elyas için Kral Fahd Kompleksi'nden izin istendi (22.10.2026);
        // izin gelene kadar telifsiz İngilizce Pickthall gösterilir.
        case .german: return "en.pickthall"
        case .arabic: return nil
        }
    }

    /// Okunuş (Latin harfli) baskısı: Türkçede Türkçe yazım ("yâ-sîn"),
    /// diğer dillerde İngilizce yazım ("Yaa-Seeen").
    /// Akademik okunuşu (ḥ, ṣ, ḳ, `, kelime içi tireler) cemaatin okuduğu sade
    /// yazıma çevirir: "Bismi-llâhi-rraḥmâni-rraḥîm" → "Bismillâhirrahmânirrahîm".
    /// Uzatma işaretleri (â, î, û) korunur.
    static func simpleTransliteration(_ text: String) -> String {
        let map: [String: String] = [
            "ḥ": "h", "Ḥ": "H", "ḫ": "h", "Ḫ": "H", "ṣ": "s", "Ṣ": "S", "ḍ": "d", "Ḍ": "D",
            "ṭ": "t", "Ṭ": "T", "ẓ": "z", "Ẓ": "Z", "ḳ": "k", "Ḳ": "K", "ġ": "ğ", "Ġ": "Ğ",
            "ẕ": "z", "ẖ": "h", "ż": "z", "Ż": "Z", "s̱": "s", "ẟ": "z", "`": "", "'": "", "’": "", "ʿ": "", "ʾ": "", "-": ""
        ]
        var out = text
        for (k, v) in map { out = out.replacingOccurrences(of: k, with: v) }
        return out
    }

    static func transliterationEdition(for language: AppLanguage) -> String {
        language == .turkish ? "tr.transliteration" : "en.transliteration"
    }

    private var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("quran_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func fetchSurahList() async throws -> [QuranSurahSummary] {
        let fileURL = cacheDirectory.appendingPathComponent("surah_list.json")
        if let data = try? Data(contentsOf: fileURL),
           let cached = try? JSONDecoder().decode([QuranSurahSummary].self, from: data),
           cached.count == 114 {
            return cached
        }
        let data = try await download("\(baseURL)/surah")
        let list = try JSONDecoder().decode(SurahListResponse.self, from: data).data
        if list.count == 114, let encoded = try? JSONEncoder().encode(list) {
            try? encoded.write(to: fileURL)
        }
        return list
    }

    func fetchSurahContent(number: Int, language: AppLanguage) async throws -> SurahContent {
        let mealEdition = Self.mealEdition(for: language)
        let translitEdition = Self.transliterationEdition(for: language)
        if let cached = loadFromCache(number: number, mealEdition: mealEdition, translitEdition: translitEdition) {
            return cached
        }

        async let arabicTask = fetchEdition(surah: number, edition: "quran-uthmani")
        async let transliterationTask = fetchEdition(surah: number, edition: translitEdition)
        let meal: [QuranAyah]
        if let mealEdition {
            meal = try await fetchEdition(surah: number, edition: mealEdition)
        } else {
            meal = []
        }

        let content = try await SurahContent(
            arabic: Self.removingLeadingBasmala(arabicTask, surah: number),
            transliteration: transliterationTask,
            meal: meal
        )
        saveToCache(number: number, mealEdition: mealEdition, translitEdition: translitEdition, content: content)
        return content
    }

    private func fetchEdition(surah: Int, edition: String) async throws -> [QuranAyah] {
        let data = try await download("\(baseURL)/surah/\(surah)/\(edition)")
        return try JSONDecoder().decode(SurahDetailResponse.self, from: data).data.ayahs
    }

    static let basmala = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"

    /// Kaynak, Fâtiha ve Tevbe dışındaki her surenin 1. ayetinin başına
    /// Besmele'yi ekliyor. Ekranda sure başlığında Besmele zaten
    /// gösterildiği için ayetteki tekrarı kaldırıyoruz.
    static func removingLeadingBasmala(_ ayahs: [QuranAyah], surah: Int) -> [QuranAyah] {
        guard surah != 1, surah != 9, let first = ayahs.first else { return ayahs }
        let text = first.text.replacingOccurrences(of: "\u{FEFF}", with: "")
        guard text.hasPrefix(basmala) else { return ayahs }
        let rest = String(text.dropFirst(basmala.count)).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return ayahs }
        return [QuranAyah(number: first.number, text: rest, numberInSurah: first.numberInSurah)] + ayahs.dropFirst()
    }

    /// Sadece HTTP 200 yanıtlarını kabul eder; hata sayfası önbelleğe girmez.
    private func download(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw APIError.badResponse }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.badResponse }
        return data
    }

    // MARK: - Disk önbelleği

    private struct CachedSurah: Codable {
        let arabic: [QuranAyah]
        let transliteration: [QuranAyah]
        let meal: [QuranAyah]
    }

    /// Dosya adında meal baskısı var: dil değişince ya da baskı
    /// değişince eski (yanlış dildeki) önbellek kullanılmaz.
    private func cacheFileURL(number: Int, mealEdition: String?, translitEdition: String) -> URL {
        cacheDirectory.appendingPathComponent("surah_\(number)_\(mealEdition ?? "none")_\(translitEdition).json")
    }

    private func saveToCache(number: Int, mealEdition: String?, translitEdition: String, content: SurahContent) {
        let cached = CachedSurah(arabic: content.arabic, transliteration: content.transliteration, meal: content.meal)
        if let data = try? JSONEncoder().encode(cached) {
            try? data.write(to: cacheFileURL(number: number, mealEdition: mealEdition, translitEdition: translitEdition))
        }
    }

    private func loadFromCache(number: Int, mealEdition: String?, translitEdition: String) -> SurahContent? {
        guard let data = try? Data(contentsOf: cacheFileURL(number: number, mealEdition: mealEdition, translitEdition: translitEdition)),
              let cached = try? JSONDecoder().decode(CachedSurah.self, from: data) else { return nil }
        return SurahContent(arabic: cached.arabic, transliteration: cached.transliteration, meal: cached.meal)
    }
}
