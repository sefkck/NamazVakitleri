import Foundation

/// Hem NotificationManager (ayet bildirimi) hem de ayet widget'ı
/// tarafından kullanılan paylaşılan kısa ayet havuzu. Bu dosya HEM ana
/// uygulama HEM widget hedefine eklenmelidir (Target Membership'te iki
/// kutucuğu da işaretle).
enum AyahPool {
    static let verses: [(reference: String, text: String)] = [
        ("Bakara Suresi, 286. Ayet", "Allah, hiçbir kimseyi gücünün yetmediği şeyle yükümlü kılmaz."),
        ("İnşirah Suresi, 5-6. Ayet", "Şüphesiz güçlükle beraber bir kolaylık vardır."),
        ("Talak Suresi, 3. Ayet", "Kim Allah'a tevekkül ederse, O ona yeter."),
        ("Ra'd Suresi, 28. Ayet", "Bilesiniz ki, kalpler ancak Allah'ı anmakla huzur bulur."),
        ("Zümer Suresi, 53. Ayet", "Allah'ın rahmetinden ümit kesmeyin."),
        ("Bakara Suresi, 153. Ayet", "Sabır ve namazla Allah'tan yardım isteyin.")
    ]

    /// Seçili uygulama diline göre çevrilmiş ayet listesi (ana uygulama).
    static func localized() -> [(reference: String, text: String)] {
        verses.enumerated().map { index, verse in
            (LocalizationManager.shared.t("ayah_\(index + 1)_ref", fallback: verse.reference),
             LocalizationManager.shared.t("ayah_\(index + 1)_text", fallback: verse.text))
        }
    }

    /// Widget için: dili App Group'tan taze okuyarak çevrilmiş liste.
    static func localizedShared() -> [(reference: String, text: String)] {
        verses.enumerated().map { index, verse in
            (LocalizationManager.tShared("ayah_\(index + 1)_ref", fallback: verse.reference),
             LocalizationManager.tShared("ayah_\(index + 1)_text", fallback: verse.text))
        }
    }
}
