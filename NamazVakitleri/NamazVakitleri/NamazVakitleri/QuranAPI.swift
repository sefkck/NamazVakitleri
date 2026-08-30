import Foundation

struct QuranSurahSummary: Codable, Identifiable {
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

private struct EditionInfo: Codable {
    let identifier: String
}

private struct EditionLanguageResponse: Codable {
    let data: [EditionInfo]
}

/// Sure metnini (Arapça + Latin harfli okunuş + Türkçe meal)
/// alquran.cloud API'sinden çeker, tekrar indirmemek için diske
/// önbelleğe alır. İlk açılışta internet gerektirir, sonra offline çalışır.
final class QuranAPI {
    static let shared = QuranAPI()
    private init() {}

    struct SurahContent {
        let arabic: [QuranAyah]
        let transliteration: [QuranAyah]
        let meal: [QuranAyah]
    }

    private let baseURL = "https://api.alquran.cloud/v1"
    private var cachedTurkishEdition: String?

    private var cacheDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("quran_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func fetchSurahList() async throws -> [QuranSurahSummary] {
        let url = URL(string: "\(baseURL)/surah")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SurahListResponse.self, from: data).data
    }

    func fetchSurahContent(number: Int) async throws -> SurahContent {
        if let cached = loadFromCache(number: number) {
            return cached
        }

        async let arabicTask = fetchEdition(surah: number, edition: "quran-uthmani")
        async let transliterationTask = fetchEdition(surah: number, edition: "en.transliteration")
        let turkishEdition = try await resolveTurkishEdition()
        async let mealTask = fetchEdition(surah: number, edition: turkishEdition)

        let content = try await SurahContent(
            arabic: arabicTask,
            transliteration: transliterationTask,
            meal: mealTask
        )
        saveToCache(number: number, content: content)
        return content
    }

    private func fetchEdition(surah: Int, edition: String) async throws -> [QuranAyah] {
        let url = URL(string: "\(baseURL)/surah/\(surah)/\(edition)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SurahDetailResponse.self, from: data).data.ayahs
    }

    /// Diyanet mealini bulmaya çalışır, yoksa mevcut ilk Türkçe meali kullanır.
    private func resolveTurkishEdition() async throws -> String {
        if let cachedTurkishEdition { return cachedTurkishEdition }
        let url = URL(string: "\(baseURL)/edition/language/tr")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try? JSONDecoder().decode(EditionLanguageResponse.self, from: data)
        let identifier = decoded?.data.first(where: { $0.identifier.contains("diyanet") })?.identifier
            ?? decoded?.data.first?.identifier
            ?? "en.sahih"
        cachedTurkishEdition = identifier
        return identifier
    }

    // MARK: - Disk önbelleği

    private struct CachedSurah: Codable {
        let arabic: [QuranAyah]
        let transliteration: [QuranAyah]
        let meal: [QuranAyah]
    }

    private func cacheFileURL(number: Int) -> URL {
        cacheDirectory.appendingPathComponent("surah_\(number).json")
    }

    private func saveToCache(number: Int, content: SurahContent) {
        let cached = CachedSurah(arabic: content.arabic, transliteration: content.transliteration, meal: content.meal)
        if let data = try? JSONEncoder().encode(cached) {
            try? data.write(to: cacheFileURL(number: number))
        }
    }

    private func loadFromCache(number: Int) -> SurahContent? {
        guard let data = try? Data(contentsOf: cacheFileURL(number: number)),
              let cached = try? JSONDecoder().decode(CachedSurah.self, from: data) else { return nil }
        return SurahContent(arabic: cached.arabic, transliteration: cached.transliteration, meal: cached.meal)
    }
}
