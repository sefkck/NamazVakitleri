import Foundation

/// Günün hadisi: İmam Nevevî'nin Kırk Hadisi (42 hadis), uygulamanın içinde.
/// Arapça metin klasik metindir. Türkçe ve İngilizce çeviri: hadith-api
/// (github.com/fawazahmed0/hadith-api, Unlicense); çevirmen belirtilmemiş,
/// Arapçasıyla tek tek karşılaştırıldı (bkz. CLAUDE CODE/hadis_kontrol).
enum DailyHadith {
    struct Item: Codable, Identifiable, Equatable {
        let n: Int
        let ar: String
        let tr: String
        let en: String
        var id: Int { n }

        /// Telefonun diline göre çeviri: Türkçe → Türkçe, İngilizce/Almanca → İngilizce, Arapça → yok.
        func translation(in language: AppLanguage) -> String? {
            switch language {
            case .turkish: return tr
            case .english, .german: return en
            case .arabic: return nil
            }
        }
    }

    static let all: [Item] = {
        guard let url = Bundle.main.url(forResource: "Nawawi40", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([Item].self, from: data) else { return [] }
        return items
    }()

    static func ofDay(_ date: Date = Date()) -> Item? {
        guard !all.isEmpty else { return nil }
        let day = Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: date) ?? 1
        return all[(day - 1) % all.count]
    }
}
