import Foundation

extension String {
    /// Aramada karşılaştırma için sade biçim: Türkçe büyük/küçük harf
    /// kuralları (İ→i, I→ı→i), şapka/nokta gibi işaretler ve kesme/tire/
    /// boşluk yok sayılır. Böylece "ist" → "İstanbul", "yasin" → "Yâsîn" bulunur.
    var searchFolded: String {
        lowercased(with: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { !"'’`-  ".contains($0) }
    }

    /// Türkçe harflere duyarlı "içeriyor mu" araması.
    func matchesSearch(_ query: String) -> Bool {
        let q = query.searchFolded
        return q.isEmpty || searchFolded.contains(q)
    }
}
