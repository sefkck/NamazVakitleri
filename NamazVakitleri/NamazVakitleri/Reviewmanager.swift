import Foundation
import UIKit

/// Kullanıcı üst üste birkaç gün uygulamayı kullandığında Apple'ın kendi
/// değerlendirme penceresini (StoreKit `requestReview`) gösterir. Apple
/// kuralı (App Review 5.6.4) gereği kendi özel değerlendirme uyarımızı
/// kullanmıyoruz. Pencereyi gerçekten gösterip göstermemeye iOS karar
/// verir (yılda en fazla 3 kez).
enum ReviewManager {
    private static let lastLaunchDateKey = "review_lastLaunchDate"
    private static let consecutiveDaysKey = "review_consecutiveDays"
    private static let nextPromptDateKey = "review_nextPromptDate"

    /// 3 gün üst üste kullanım sonrası ilk istek gösterilir.
    private static let requiredConsecutiveDays = 3
    /// Bir istekten sonra kaç gün sonra tekrar denenir.
    private static let repromptIntervalDays = 120

    /// TODO: Uygulama App Store'a yüklendiğinde gerçek App Store ID'sini
    /// yaz (yalnızca rakamlar, ör. "6501234567"). Boşken Ayarlar'daki
    /// "Bizi Değerlendir" Apple'ın penceresini kullanır.
    static let appStoreID = ""

    /// Uygulama her açıldığında çağrılır. Değerlendirme isteğinin şimdi
    /// gösterilip gösterilmeyeceğini döner.
    static func trackLaunchAndShouldPrompt() -> Bool {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today = Date()

        if let lastLaunch = defaults.object(forKey: lastLaunchDateKey) as? Date {
            if calendar.isDateInToday(lastLaunch) {
                // Bugün zaten sayıldı, tekrar sayma.
            } else if calendar.isDateInYesterday(lastLaunch) {
                let newCount = defaults.integer(forKey: consecutiveDaysKey) + 1
                defaults.set(newCount, forKey: consecutiveDaysKey)
                defaults.set(today, forKey: lastLaunchDateKey)
            } else {
                defaults.set(1, forKey: consecutiveDaysKey)
                defaults.set(today, forKey: lastLaunchDateKey)
            }
        } else {
            defaults.set(1, forKey: consecutiveDaysKey)
            defaults.set(today, forKey: lastLaunchDateKey)
        }

        if let nextDate = defaults.object(forKey: nextPromptDateKey) as? Date {
            return Date() >= nextDate
        }

        return defaults.integer(forKey: consecutiveDaysKey) >= requiredConsecutiveDays
    }

    /// İstek gösterildi; bir sonraki denemeyi ileri tarihe at.
    static func markPrompted() {
        let next = Calendar.current.date(byAdding: .day, value: repromptIntervalDays, to: Date()) ?? Date()
        UserDefaults.standard.set(next, forKey: nextPromptDateKey)
    }

    /// App Store yorum yazma sayfası. App Store ID girilmediyse nil.
    static var writeReviewURL: URL? {
        guard !appStoreID.isEmpty, appStoreID.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}
