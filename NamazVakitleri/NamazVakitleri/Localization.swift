import Foundation
import Combine
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Uygulamanın desteklediği diller. Türkçe varsayılan; İngilizce şu an
/// uygulamanın TAMAMINDA çevrili. Arapça ve Almanca için çeviri
/// bulunamayan her metin otomatik olarak İngilizceye düşer.
enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"
    case arabic = "ar"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        case .arabic: return "العربية"
        case .german: return "Deutsch"
        }
    }

    var isRightToLeft: Bool { self == .arabic }

    /// Telefonun sistem dilinden uygulama dilini seçer (sıfırdan kurulum
    /// için). Desteklenmeyen sistem dillerinde İngilizce kullanılır.
    static func fromSystem() -> AppLanguage {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if code.hasPrefix("tr") { return .turkish }
        if code.hasPrefix("ar") { return .arabic }
        if code.hasPrefix("de") { return .german }
        return .english
    }

    /// Tarih biçimlendirme için uygun yerel ayar.
    var locale: Locale {
        switch self {
        case .turkish: return Locale(identifier: "tr_TR")
        case .english: return Locale(identifier: "en_US")
        case .arabic: return Locale(identifier: "ar")
        case .german: return Locale(identifier: "de_DE")
        }
    }
}

/// Dil seçimini tutan ve DEĞİŞTİĞİ ANDA tüm ekranları güncelleyen
/// merkezi nesne. @Published olduğu için bunu gözleyen her View, dil
/// değişince anında yeniden çizilir - uygulamayı kapatıp açmaya gerek yok.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    static let appGroupID = "group.com.kocaksefa.safa"

    /// Sağdan sola ↔ soldan sağa geçişte bütün ekran yeniden kurulur ve açık
    /// Ayarlar penceresi kapanırdı. Bu bayrak, yeniden kurulumdan sonra Ayarlar'ı
    /// tekrar açmak için kullanılır (MainTabView + MoreMenuView okur).
    static var reopenSettingsAfterRebuild = false

    @Published var language: AppLanguage {
        didSet {
            // Sadece Ayarlar'dan değişince (karşılama ekranında değil).
            if oldValue.isRightToLeft != language.isRightToLeft, UserDefaults.standard.bool(forKey: "hasSeenWelcome") {
                Self.reopenSettingsAfterRebuild = true
            }
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            // Widget'lar ayrı bir process'te çalıştığı için dili App Group
            // üzerinden de paylaşıyoruz.
            UserDefaults(suiteName: Self.appGroupID)?.set(language.rawValue, forKey: "appLanguage")
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let group = UserDefaults(suiteName: Self.appGroupID)
        let saved = defaults.string(forKey: "appLanguage") ?? group?.string(forKey: "appLanguage")

        if let saved, let lang = AppLanguage(rawValue: saved) {
            self.language = lang
        } else {
            // Kayıtlı dil yok. Uygulamayı daha önce kullanmış (karşılama
            // ekranını görmüş) kullanıcılar eskisi gibi Türkçe kalır;
            // sıfırdan kurulumda telefonun sistem dilinden başlanır.
            let lang: AppLanguage = defaults.bool(forKey: "hasSeenWelcome") ? .turkish : .fromSystem()
            self.language = lang
            defaults.set(lang.rawValue, forKey: "appLanguage")
            group?.set(lang.rawValue, forKey: "appLanguage")
        }
    }

    // MARK: - Çeviri

    /// Anahtardan, o anki dile göre çevrilmiş metni döndürür.
    /// `fallback`, kodda zaten yazılı olan Türkçe metindir (Türkçe seçiliyken
    /// aynen kullanılır, böylece Türkçe metinler tabloda tekrar edilmez).
    func t(_ key: String, fallback: String? = nil) -> String {
        Self.translate(key, language: language, fallback: fallback)
    }

    /// Biçimlendirmeli çeviri: `tf("zikir_remaining", "Kalan: %d", 5)`
    func tf(_ key: String, _ fallbackFormat: String, _ args: CVarArg...) -> String {
        let format = t(key, fallback: fallbackFormat)
        return String(format: format, arguments: args)
    }

    /// Türkçe kaynak metne (ör. "İmsak", "Regaip Kandili") karşılık gelen
    /// çeviriyi döndürür; bulunamazsa metni olduğu gibi bırakır.
    func x(_ turkish: String) -> String {
        Self.translateFromTurkish(turkish, language: language)
    }

    var locale: Locale { language.locale }

    // MARK: - Widget için paylaşılan (App Group'tan taze okuyan) sürümler

    static func sharedLanguage() -> AppLanguage {
        let raw = UserDefaults(suiteName: appGroupID)?.string(forKey: "appLanguage")
            ?? UserDefaults.standard.string(forKey: "appLanguage")
        // Uygulama hiç açılmadan widget eklenirse telefonun diline göre göster.
        return AppLanguage(rawValue: raw ?? "") ?? .fromSystem()
    }

    static func tShared(_ key: String, fallback: String? = nil) -> String {
        translate(key, language: sharedLanguage(), fallback: fallback)
    }

    static func xShared(_ turkish: String) -> String {
        translateFromTurkish(turkish, language: sharedLanguage())
    }

    // MARK: - İç mantık

    static func translate(_ key: String, language: AppLanguage, fallback: String?) -> String {
        let entry = LocalizationStrings.table[key]
        if language == .turkish {
            return entry?[.turkish] ?? fallback ?? entry?[.english] ?? key
        }
        return entry?[language] ?? entry?[.english] ?? entry?[.turkish] ?? fallback ?? key
    }

    private static let reverseTurkish: [String: String] = {
        var map: [String: String] = [:]
        for (key, values) in LocalizationStrings.table {
            if let tr = values[.turkish] { map[tr] = key }
        }
        return map
    }()

    static func translateFromTurkish(_ turkish: String, language: AppLanguage) -> String {
        guard language != .turkish, let key = reverseTurkish[turkish] else { return turkish }
        return translate(key, language: language, fallback: turkish)
    }
}

typealias Loc = LocalizationManager

/// Çeviri tablosu. Her anahtar için diller: .turkish yalnızca Türkçe metnin
/// tersine aranması (x fonksiyonu) gereken kısa metinlerde tutuluyor; diğer
/// anahtarlarda Türkçe metin kodun içinde `fallback:` olarak duruyor.
/// Yeni bir dil eklemek için ilgili anahtarlara `.arabic:` / `.german:`
/// satırı eklemek yeterli; eksik olanlar İngilizceye düşer.
enum LocalizationStrings {
    static let table: [String: [AppLanguage: String]] = [

        // MARK: - Genel
        "common_close": [.turkish: "Kapat", .english: "Close", .arabic: "إغلاق", .german: "Schließen"],
        "common_settings": [.turkish: "Ayarlar", .english: "Settings", .arabic: "الإعدادات", .german: "Einstellungen"],
        "common_continue": [.turkish: "Hadi Başlayalım", .english: "Let's Get Started", .arabic: "لنبدأ", .german: "Los geht's"],
        "common_done": [.english: "Done", .arabic: "تم", .german: "Fertig"],

        // MARK: - Sekmeler
        "tab_home": [.turkish: "Ana Sayfa", .english: "Home", .arabic: "الرئيسية", .german: "Start"],
        "tab_zikirmatik": [.turkish: "Zikirmatik", .english: "Dhikr Counter", .arabic: "عداد الذكر", .german: "Dhikr-Zähler"],
        "tab_qibla": [.turkish: "Kıble Bul", .english: "Find Qibla", .arabic: "اتجاه القبلة", .german: "Qibla finden"],
        "tab_quran": [.turkish: "Kuran", .english: "Quran", .arabic: "القرآن", .german: "Koran"],
        "tab_more": [.turkish: "Daha Fazla", .english: "More", .arabic: "المزيد", .german: "Mehr"],

        // MARK: - Karşılama / Açılış
        "welcome_title": [.turkish: "Merhaba, ben Safa 👋", .english: "Hi, I'm Safa 👋", .arabic: "مرحباً، أنا صفا 👋", .german: "Hallo, ich bin Safa 👋"],
        "welcome_body": [
            .turkish: "Bulunduğun yere göre namaz vakitlerini hatırlatır, kıbleyi bulmana yardımcı olur, zikir çekmeni ve Kur'an okumanı kolaylaştırırım. Seni doğru anda nazikçe hatırlatmalarla desteklemek için buradayım.",
            .english: "I remind you of prayer times based on your location, help you find the Qibla, and make it easier to track your dhikr and read the Quran. I'm here to gently support you with timely reminders.",
            .arabic: "أذكّرك بمواقيت الصلاة حسب موقعك، وأساعدك في العثور على اتجاه القبلة، وأسهّل عليك عد الذكر وقراءة القرآن. أنا هنا لدعمك بتذكيرات لطيفة في الوقت المناسب.",
            .german: "Ich erinnere dich an die Gebetszeiten basierend auf deinem Standort, helfe dir die Qibla zu finden und erleichtere dir das Dhikr-Zählen und Koranlesen. Ich bin hier, um dich mit sanften Erinnerungen zu unterstützen."
        ],
        "splash_subtitle": [.turkish: "Namaz Vakitleri", .english: "Prayer Times", .arabic: "مواقيت الصلاة", .german: "Gebetszeiten"],

        // MARK: - Namaz vakti adları (Türkçe değerler x() ile ters arama için şart)
        "prayer_fajr": [.turkish: "İmsak", .english: "Fajr", .arabic: "الفجر", .german: "Fajr"],
        "prayer_sunrise": [.turkish: "Güneş", .english: "Sunrise", .arabic: "الشروق", .german: "Sonnenaufgang"],
        "prayer_dhuhr": [.turkish: "Öğle", .english: "Dhuhr", .arabic: "الظهر", .german: "Dhuhr"],
        "prayer_asr": [.turkish: "İkindi", .english: "Asr", .arabic: "العصر", .german: "Asr"],
        "prayer_maghrib": [.turkish: "Akşam", .english: "Maghrib", .arabic: "المغرب", .german: "Maghrib"],
        "prayer_isha": [.turkish: "Yatsı", .english: "Isha", .arabic: "العشاء", .german: "Isha"],
        "prayer_tomorrow_fajr": [.turkish: "Yarın İmsak", .english: "Tomorrow's Fajr", .arabic: "فجر الغد", .german: "Fajr morgen"],
        "prayer_after_isha": [.turkish: "Yatsı sonrası", .english: "After Isha", .arabic: "بعد العشاء", .german: "Nach Isha"],

        // MARK: - Ana Sayfa
        "home_next_prayer": [.turkish: "Sıradaki Namaz", .english: "Next Prayer", .arabic: "الصلاة القادمة", .german: "Nächstes Gebet"],
        "home_prayer_times_title": [.turkish: "Namaz Vakitleri", .english: "Prayer Times", .arabic: "مواقيت الصلاة", .german: "Gebetszeiten"],
        "home_retry": [.turkish: "Tekrar Dene", .english: "Try Again", .arabic: "أعد المحاولة", .german: "Erneut versuchen"],
        "home_greet_morning": [.english: "Good Morning", .arabic: "صباح الخير", .german: "Guten Morgen"],
        "home_greet_day": [.english: "Good Day", .arabic: "نهارك سعيد", .german: "Guten Tag"],
        "home_greet_evening": [.english: "Good Evening", .arabic: "مساء الخير", .german: "Guten Abend"],
        "home_greet_night": [.english: "Good Night", .arabic: "تصبح على خير", .german: "Gute Nacht"],
        "home_dua": [.english: "May Allah accept all our prayers.", .arabic: "اللهم تقبّل جميع أدعيتنا.", .german: "Möge Allah alle unsere Gebete annehmen."],
        "home_manual_hint": [.english: "For more accurate results, you can enter a manual location in Settings.", .arabic: "للحصول على نتائج أدق، يمكنك إدخال موقع يدوي من الإعدادات.", .german: "Für genauere Ergebnisse kannst du in den Einstellungen einen Standort manuell eingeben."],
        "home_cached_notice": [.english: "Internet and GPS are off, so the last known location is being used temporarily.", .arabic: "الإنترنت وGPS غير مفعّلَين، لذا يُستخدم آخر موقع معروف مؤقتًا.", .german: "Internet und GPS sind aus, daher wird vorübergehend der zuletzt bekannte Standort verwendet."],
        "home_hijri": [.english: "Hijri: %@", .arabic: "هجري: %@", .german: "Hidschri: %@"],
        "home_calculating": [.english: "Calculating prayer times...", .arabic: "جارٍ حساب مواقيت الصلاة...", .german: "Gebetszeiten werden berechnet..."],
        "home_loc_unavailable": [.english: "Can't get your location. Check location services or select a city manually.", .arabic: "تعذّر تحديد موقعك. تحقق من خدمات الموقع أو اختر مدينة يدويًا.", .german: "Standort nicht verfügbar. Prüfe die Ortungsdienste oder wähle eine Stadt manuell aus."],
        "home_no_city": [.english: "No city selected", .arabic: "لم يتم اختيار مدينة", .german: "Keine Stadt ausgewählt"],

        // MARK: - Konum hataları
        "loc_waiting": [.english: "Waiting for location...", .arabic: "بانتظار الموقع...", .german: "Warte auf Standort..."],
        "loc_unknown": [.english: "Unknown location", .arabic: "موقع غير معروف", .german: "Unbekannter Standort"],
        "loc_denied_short": [.english: "Location permission wasn't granted. Please allow it in Settings.", .arabic: "لم يتم منح إذن الموقع. يرجى السماح به من الإعدادات.", .german: "Die Standortberechtigung wurde nicht erteilt. Bitte erlaube sie in den Einstellungen."],
        "loc_failed_retry": [.english: "Couldn't get your location; will try again shortly.", .arabic: "تعذّر تحديد الموقع، ستتم إعادة المحاولة بعد قليل.", .german: "Standort konnte nicht ermittelt werden; es wird gleich erneut versucht."],
        "loc_denied_full": [.english: "Couldn't get your location. In your phone's Settings > Privacy & Security > Location Services, make sure both Location Services and this app's location permission are turned on.", .arabic: "تعذّر تحديد الموقع. من إعدادات الهاتف > الخصوصية والأمان > خدمات الموقع، تأكد من تفعيل خدمات الموقع العامة وإذن الموقع لهذا التطبيق.", .german: "Standort konnte nicht ermittelt werden. Stelle in den iPhone-Einstellungen unter Datenschutz & Sicherheit > Ortungsdienste sicher, dass sowohl die Ortungsdienste als auch die Standortberechtigung dieser App aktiviert sind."],
        "loc_network": [.english: "A network problem occurred while finding your location. Check your internet connection and try again.", .arabic: "حدثت مشكلة في الشبكة أثناء تحديد الموقع. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.", .german: "Beim Ermitteln des Standorts ist ein Netzwerkproblem aufgetreten. Prüfe deine Internetverbindung und versuche es erneut."],
        "loc_unavailable_now": [.english: "Location is unavailable right now; will try again shortly.", .arabic: "الموقع غير متاح حاليًا، ستتم إعادة المحاولة بعد قليل.", .german: "Der Standort ist gerade nicht verfügbar; es wird gleich erneut versucht."],

        // MARK: - Zikirmatik
        "zikir_goal": [.english: "Goal", .arabic: "الهدف", .german: "Ziel"],
        "zikir_unlimited": [.turkish: "Sınırsız", .english: "Unlimited", .arabic: "غير محدود", .german: "Frei"],
        "zikir_custom": [.turkish: "Özel", .english: "Custom", .arabic: "مخصص", .german: "Eigenes"],
        "zikir_goal_label": [.english: "Target count:", .arabic: "العدد المستهدف:", .german: "Zielanzahl:"],
        "zikir_placeholder": [.english: "e.g. 250", .arabic: "مثال: 250", .german: "z. B. 250"],
        "zikir_remaining": [.english: "Remaining: %d", .arabic: "المتبقي: %d", .german: "Verbleibend: %d"],
        "zikir_rounds": [.english: "Completed rounds: %d", .arabic: "الجولات المكتملة: %d", .german: "Abgeschlossene Runden: %d"],
        "zikir_reset": [.english: "Reset", .arabic: "إعادة تعيين", .german: "Zurücksetzen"],
        "zikir_tap": [.english: "Tap", .arabic: "اضغط", .german: "Tippen"],
        "zikir_hint": [.english: "Tap the button to count dhikr", .arabic: "اضغط على الزر لعدّ الذكر", .german: "Tippe auf den Button, um Dhikr zu zählen"],

        // MARK: - Kıble
        "qibla_waiting": [.english: "Waiting for location and compass...", .arabic: "بانتظار الموقع والبوصلة...", .german: "Warte auf Standort und Kompass..."],
        "qibla_direction": [.english: "Qibla Direction", .arabic: "اتجاه القبلة", .german: "Qibla-Richtung"],
        "qibla_hint": [.english: "Hold your phone flat and turn until the arrow points toward the Kaaba.", .arabic: "أمسك هاتفك بشكل مسطّح وأدِره حتى يشير السهم نحو الكعبة.", .german: "Halte dein Telefon flach und drehe es, bis der Pfeil zur Kaaba zeigt."],
        "qibla_no_compass": [.english: "No compass sensor found on your device.", .arabic: "لم يتم العثور على مستشعر البوصلة في جهازك.", .german: "Auf deinem Gerät wurde kein Kompasssensor gefunden."],
        "qibla_no_location": [.english: "Qibla direction can't be calculated because location is unavailable. Check your internet and GPS connection.", .arabic: "لا يمكن حساب اتجاه القبلة لأن الموقع غير متاح. تحقق من اتصالك بالإنترنت وGPS.", .german: "Die Qibla-Richtung kann nicht berechnet werden, da kein Standort verfügbar ist. Prüfe deine Internet- und GPS-Verbindung."],
        "qibla_denied": [.english: "We need location permission to calculate the Qibla direction. Allow it in Settings > Privacy & Security > Location Services.", .arabic: "نحتاج إلى إذن الموقع لحساب اتجاه القبلة. اسمح به من الإعدادات > الخصوصية والأمان > خدمات الموقع.", .german: "Zur Berechnung der Qibla-Richtung benötigen wir die Standortberechtigung. Erlaube sie unter Einstellungen > Datenschutz & Sicherheit > Ortungsdienste."],

        // MARK: - Daha Fazla
        "more_religious_days": [.english: "Religious Days", .arabic: "الأيام الدينية", .german: "Religiöse Feiertage"],
        "more_duas": [.english: "Prayer Supplications", .arabic: "أدعية الصلاة", .german: "Gebete und Bittgebete"],
        "more_mosques": [.english: "Nearby Mosques", .arabic: "المساجد القريبة", .german: "Moscheen in der Nähe"],

        // MARK: - Dini günler (Türkçe değerler x() için şart)
        "rd_three_months": [.turkish: "Üç Ayların Başlangıcı (Recep)", .english: "Start of the Three Holy Months (Rajab)", .arabic: "بداية الأشهر الثلاثة (رجب)", .german: "Beginn der drei heiligen Monate (Radschab)"],
        "rd_regaib": [.turkish: "Regaip Kandili", .english: "Raghaib Night", .arabic: "ليلة الرغائب", .german: "Raghaib-Nacht"],
        "rd_miraj": [.turkish: "Miraç Kandili", .english: "Mi'raj Night (Isra and Mi'raj)", .arabic: "ليلة المعراج", .german: "Miradsch-Nacht (Isra und Miradsch)"],
        "rd_baraat": [.turkish: "Berat Kandili", .english: "Baraat Night (Mid-Sha'ban)", .arabic: "ليلة البراءة (النصف من شعبان)", .german: "Bara'at-Nacht (Mitte Scha'ban)"],
        "rd_ramadan": [.turkish: "Ramazan Başlangıcı", .english: "Start of Ramadan", .arabic: "بداية رمضان", .german: "Beginn des Ramadan"],
        "rd_qadr": [.turkish: "Kadir Gecesi", .english: "Laylat al-Qadr (Night of Power)", .arabic: "ليلة القدر", .german: "Nacht der Bestimmung (Laylat al-Qadr)"],
        "rd_fitr_eve": [.turkish: "Ramazan Bayramı Arefesi", .english: "Eve of Eid al-Fitr", .arabic: "عشية عيد الفطر", .german: "Vorabend des Fitr-Festes"],
        "rd_fitr": [.turkish: "Ramazan Bayramı", .english: "Eid al-Fitr", .arabic: "عيد الفطر", .german: "Fitr-Fest (Id al-Fitr)"],
        "rd_adha_eve": [.turkish: "Kurban Bayramı Arefesi", .english: "Eve of Eid al-Adha", .arabic: "يوم عرفة (عشية عيد الأضحى)", .german: "Vorabend des Opferfestes"],
        "rd_adha": [.turkish: "Kurban Bayramı", .english: "Eid al-Adha", .arabic: "عيد الأضحى", .german: "Opferfest (Id al-Adha)"],
        "rd_new_year": [.turkish: "Hicri Yılbaşı", .english: "Islamic New Year", .arabic: "رأس السنة الهجرية", .german: "Islamisches Neujahr"],
        "rd_ashura": [.turkish: "Aşure Günü", .english: "Day of Ashura", .arabic: "يوم عاشوراء", .german: "Aschura-Tag"],
        "rd_mawlid": [.turkish: "Mevlid Kandili", .english: "Mawlid Night (Prophet's Birthday)", .arabic: "ليلة المولد النبوي", .german: "Mawlid-Nacht (Geburtstag des Propheten)"],
        "rd_note_night": [.turkish: "Gece idrak edilir", .english: "Observed at night", .arabic: "تُحيا في الليل", .german: "Wird nachts begangen"],
        "rd_note_approx": [.turkish: "Yaklaşık tarih", .english: "Approximate date", .arabic: "تاريخ تقريبي", .german: "Ungefähres Datum"],
        "rd_footer": [.english: "Dates are based on the religious days calendar published by the Presidency of Religious Affairs (Diyanet). Start dates that depend on moon sighting, such as Ramadan and Eid al-Adha, are officially confirmed as the month approaches and may change by ±1 day.", .arabic: "التواريخ مبنية على تقويم الأيام الدينية الصادر عن رئاسة الشؤون الدينية (ديانت). تُعلن رسميًا التواريخ المرتبطة برؤية الهلال، مثل رمضان وعيد الأضحى، مع اقتراب الشهر، وقد تتغير بمقدار ±1 يوم.", .german: "Die Daten basieren auf dem Kalender der religiösen Tage der Religionsbehörde (Diyanet). Von der Mondsichtung abhängige Beginndaten wie Ramadan und Opferfest werden offiziell erst kurz vor dem Monat bestätigt und können sich um ±1 Tag ändern."],
        "rd_today": [.english: "Today", .arabic: "اليوم", .german: "Heute"],
        "rd_days_left": [.english: "%d days left", .arabic: "متبقي %d أيام", .german: "noch %d Tage"],
        "rd_one_day_left": [.english: "1 day left", .arabic: "متبقي يوم واحد", .german: "noch 1 Tag"],

        // MARK: - Dualar (başlık / okunuş / anlam; Türkçe metinler kodda duruyor)
        "dua1_title": [.english: "Subhanaka (Opening Supplication)", .arabic: "سبحانك اللهم (دعاء الاستفتاح)", .german: "Subhanaka (Eröffnungsbittgebet)"],
        "dua1_trans": [.english: "Subḥānaka Allāhumma wa bi-ḥamdika, wa tabārakasmuka, wa taʿālā jadduka, wa lā ilāha ghayruka.", .arabic: "Subḥānaka Allāhumma wa bi-ḥamdika, wa tabārakasmuka, wa taʿālā jadduka, wa lā ilāha ghayruka.", .german: "Subḥānaka Allāhumma wa bi-ḥamdika, wa tabārakasmuka, wa taʿālā jadduka, wa lā ilāha ghayruka."],
        "dua1_meal": [.english: "O Allah, You are glorified and praised. Blessed is Your name, exalted is Your majesty, and there is no god but You.", .arabic: "تنزيه لله وحمده، وإقرار بتبارك اسمه وعلوّ عظمته وأنه لا إله غيره.", .german: "O Allah, Du bist gepriesen und gelobt. Gesegnet ist Dein Name, erhaben ist Deine Majestät, und es gibt keinen Gott außer Dir."],
        "dua2_title": [.english: "At-Tahiyyat (Tashahhud)", .arabic: "التحيات", .german: "At-Tahiyyat (Tashahhud)"],
        "dua2_trans": [.english: "At-taḥiyyātu lillāhi waṣ-ṣalawātu waṭ-ṭayyibāt. As-salāmu ʿalayka ayyuhan-Nabiyyu wa raḥmatullāhi wa barakātuh. As-salāmu ʿalaynā wa ʿalā ʿibādillāhiṣ-ṣāliḥīn. Ashhadu an lā ilāha illallāh wa ashhadu anna Muḥammadan ʿabduhū wa rasūluh.", .arabic: "At-taḥiyyātu lillāhi waṣ-ṣalawātu waṭ-ṭayyibāt. As-salāmu ʿalayka ayyuhan-Nabiyyu wa raḥmatullāhi wa barakātuh. As-salāmu ʿalaynā wa ʿalā ʿibādillāhiṣ-ṣāliḥīn. Ashhadu an lā ilāha illallāh wa ashhadu anna Muḥammadan ʿabduhū wa rasūluh.", .german: "At-taḥiyyātu lillāhi waṣ-ṣalawātu waṭ-ṭayyibāt. As-salāmu ʿalayka ayyuhan-Nabiyyu wa raḥmatullāhi wa barakātuh. As-salāmu ʿalaynā wa ʿalā ʿibādillāhiṣ-ṣāliḥīn. Ashhadu an lā ilāha illallāh wa ashhadu anna Muḥammadan ʿabduhū wa rasūluh."],
        "dua2_meal": [.english: "All greetings, prayers and good words are for Allah. Peace be upon you, O Prophet, and the mercy of Allah and His blessings. Peace be upon us and upon the righteous servants of Allah. I bear witness that there is no god but Allah, and I bear witness that Muhammad is His servant and Messenger.", .arabic: "تحية لله بكل الثناء والصلوات والطيبات، والسلام على النبي وعلى عباد الله الصالحين، وشهادة التوحيد والرسالة.", .german: "Alle Grüße, Gebete und guten Worte gehören Allah. Friede sei mit dir, o Prophet, sowie Allahs Barmherzigkeit und Seine Segnungen. Friede sei mit uns und mit den rechtschaffenen Dienern Allahs. Ich bezeuge, dass es keinen Gott außer Allah gibt, und ich bezeuge, dass Muhammad Sein Diener und Gesandter ist."],
        "dua3_title": [.english: "Allahumma Salli", .arabic: "اللهم صلِّ", .german: "Allahumma Salli"],
        "dua3_trans": [.english: "Allāhumma ṣalli ʿalā Muḥammadin wa ʿalā āli Muḥammad, kamā ṣallayta ʿalā Ibrāhīma wa ʿalā āli Ibrāhīm, innaka Ḥamīdun Majīd.", .arabic: "Allāhumma ṣalli ʿalā Muḥammadin wa ʿalā āli Muḥammad, kamā ṣallayta ʿalā Ibrāhīma wa ʿalā āli Ibrāhīm, innaka Ḥamīdun Majīd.", .german: "Allāhumma ṣalli ʿalā Muḥammadin wa ʿalā āli Muḥammad, kamā ṣallayta ʿalā Ibrāhīma wa ʿalā āli Ibrāhīm, innaka Ḥamīdun Majīd."],
        "dua3_meal": [.english: "O Allah, send blessings upon Muhammad and the family of Muhammad, as You sent blessings upon Ibrahim and the family of Ibrahim. Indeed, You are Praiseworthy and Glorious.", .arabic: "دعاء بالصلاة على النبي محمد وآله كما صُلّي على إبراهيم وآله، إنك حميد مجيد.", .german: "O Allah, sende Deine Segnungen auf Muhammad und die Familie Muhammads herab, so wie Du sie auf Ibrahim und die Familie Ibrahims herabgesandt hast. Wahrlich, Du bist lobenswert und ruhmvoll."],
        "dua4_title": [.english: "Allahumma Barik", .arabic: "اللهم بارك", .german: "Allahumma Barik"],
        "dua4_trans": [.english: "Allāhumma bārik ʿalā Muḥammadin wa ʿalā āli Muḥammad, kamā bārakta ʿalā Ibrāhīma wa ʿalā āli Ibrāhīm, innaka Ḥamīdun Majīd.", .arabic: "Allāhumma bārik ʿalā Muḥammadin wa ʿalā āli Muḥammad, kamā bārakta ʿalā Ibrāhīma wa ʿalā āli Ibrāhīm, innaka Ḥamīdun Majīd.", .german: "Allāhumma bārik ʿalā Muḥammadin wa ʿalā āli Muḥammad, kamā bārakta ʿalā Ibrāhīma wa ʿalā āli Ibrāhīm, innaka Ḥamīdun Majīd."],
        "dua4_meal": [.english: "O Allah, bless Muhammad and the family of Muhammad, as You blessed Ibrahim and the family of Ibrahim. Indeed, You are Praiseworthy and Glorious.", .arabic: "دعاء بالبركة على النبي محمد وآله كما بورك على إبراهيم وآله، إنك حميد مجيد.", .german: "O Allah, segne Muhammad und die Familie Muhammads, so wie Du Ibrahim und die Familie Ibrahims gesegnet hast. Wahrlich, Du bist lobenswert und ruhmvoll."],
        "dua5_title": [.english: "Rabbana Atina", .arabic: "ربنا آتنا", .german: "Rabbana Atina"],
        "dua5_trans": [.english: "Rabbanā ātinā fid-dunyā ḥasanatan wa fil-ākhirati ḥasanatan wa qinā ʿadhāban-nār.", .arabic: "Rabbanā ātinā fid-dunyā ḥasanatan wa fil-ākhirati ḥasanatan wa qinā ʿadhāban-nār.", .german: "Rabbanā ātinā fid-dunyā ḥasanatan wa fil-ākhirati ḥasanatan wa qinā ʿadhāban-nār."],
        "dua5_meal": [.english: "Our Lord, grant us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.", .arabic: "دعاء بخير الدنيا وخير الآخرة والوقاية من عذاب النار.", .german: "Unser Herr, gib uns Gutes im Diesseits und Gutes im Jenseits und bewahre uns vor der Strafe des Feuers."],
        "dua6_title": [.english: "Rabbighfir Li", .arabic: "رب اغفر لي", .german: "Rabbighfir Li"],
        "dua6_trans": [.english: "Rabbighfir lī wa li-wālidayya wa lil-muʾminīna yawma yaqūmul-ḥisāb.", .arabic: "Rabbighfir lī wa li-wālidayya wa lil-muʾminīna yawma yaqūmul-ḥisāb.", .german: "Rabbighfir lī wa li-wālidayya wa lil-muʾminīna yawma yaqūmul-ḥisāb."],
        "dua6_meal": [.english: "My Lord, forgive me, my parents, and the believers on the Day when the account is established.", .arabic: "دعاء بالمغفرة للنفس وللوالدين وللمؤمنين يوم الحساب.", .german: "Mein Herr, vergib mir, meinen Eltern und den Gläubigen an dem Tag, an dem die Abrechnung stattfindet."],
        "dua7_title": [.english: "Qunut Supplication 1", .arabic: "دعاء القنوت 1", .german: "Qunut-Bittgebet 1"],
        "dua7_trans": [.english: "Allāhumma innā nastaʿīnuka wa nastaghfiruka wa nastahdīk, wa nuʾminu bika wa natūbu ilayk, wa natawakkalu ʿalayka wa nuthnī ʿalaykal-khayra kullahu nashkuruk, wa lā nakfuruka wa nakhlaʿu wa natruku man yafjuruk.", .arabic: "—", .german: "Allāhumma innā nastaʿīnuka wa nastaghfiruka wa nastahdīk, wa nuʾminu bika wa natūbu ilayk, wa natawakkalu ʿalayka wa nuthnī ʿalaykal-khayra kullahu nashkuruk, wa lā nakfuruka wa nakhlaʿu wa natruku man yafjuruk."],
        "dua7_meal": [.english: "O Allah, we seek Your help, Your forgiveness and Your guidance. We believe in You and turn to You in repentance. We trust in You and praise You with all good. We thank You and are not ungrateful to You. We cast off and leave whoever disobeys You.", .arabic: "استعانة بالله واستغفار واستهداء، وإيمان وتوبة وتوكّل، وثناء وشكر، وترك من يعصيه.", .german: "O Allah, wir bitten Dich um Hilfe, um Vergebung und um Rechtleitung. Wir glauben an Dich und wenden uns Dir in Reue zu. Wir vertrauen auf Dich und loben Dich mit allem Guten. Wir danken Dir und sind Dir nicht undankbar. Wir sagen uns los von dem, der sich Dir widersetzt."],
        "dua8_title": [.english: "Qunut Supplication 2", .arabic: "دعاء القنوت 2", .german: "Qunut-Bittgebet 2"],
        "dua8_trans": [.english: "Allāhumma iyyāka naʿbudu wa laka nuṣallī wa nasjud, wa ilayka nasʿā wa naḥfid, narjū raḥmataka wa nakhshā ʿadhābak, inna ʿadhābaka bil-kuffāri mulḥiq.", .arabic: "Allāhumma iyyāka naʿbudu wa laka nuṣallī wa nasjud, wa ilayka nasʿā wa naḥfid, narjū raḥmataka wa nakhshā ʿadhābak, inna ʿadhābaka bil-kuffāri mulḥiq.", .german: "Allāhumma iyyāka naʿbudu wa laka nuṣallī wa nasjud, wa ilayka nasʿā wa naḥfid, narjū raḥmataka wa nakhshā ʿadhābak, inna ʿadhābaka bil-kuffāri mulḥiq."],
        "dua8_meal": [.english: "O Allah, we worship You alone, pray and prostrate to You alone. We hasten toward You and strive to draw near. We hope for Your mercy and fear Your punishment. Indeed, Your punishment overtakes the disbelievers.", .arabic: "إخلاص العبادة لله، والسعي إليه رجاءً لرحمته وخوفًا من عذابه.", .german: "O Allah, Dir allein dienen wir, zu Dir beten wir und vor Dir werfen wir uns nieder. Zu Dir eilen wir und streben wir. Wir hoffen auf Deine Barmherzigkeit und fürchten Deine Strafe. Wahrlich, Deine Strafe ereilt die Ungläubigen."],
        "dua9_title": [.english: "Ayat al-Kursi (Al-Baqarah 255)", .arabic: "آية الكرسي (البقرة 255)", .german: "Ayat al-Kursi (Al-Baqara 255)"],
        "dua9_trans": [.english: "Allahu laaa ilaaha illaa Huwal Haiyul Qaiyoom; laa taakhuzuhoo sinatunw wa laa nawm; lahoo maa fissamaawaati wa maa fil ard; man zal lazee yashfa'u indahooo illaa bi-iznih; ya'lamu maa baina aydeehim wa mww khalfahum wa laa yuheetoona bishai'im min 'ilmihee illaa bimaa shaaa'; wasi'a Kursiyyuhus samaawaati wal arda wa laa ya'ooduho hifzuhumaa; wa Huwal Aliyyul 'Azeem", .arabic: "—", .german: "Allahu laaa ilaaha illaa Huwal Haiyul Qaiyoom; laa taakhuzuhoo sinatunw wa laa nawm; lahoo maa fissamaawaati wa maa fil ard; man zal lazee yashfa'u indahooo illaa bi-iznih; ya'lamu maa baina aydeehim wa mww khalfahum wa laa yuheetoona bishai'im min 'ilmihee illaa bimaa shaaa'; wasi'a Kursiyyuhus samaawaati wal arda wa laa ya'ooduho hifzuhumaa; wa Huwal Aliyyul 'Azeem"],
        "dua9_meal": [.english: "Allah - there is no deity except Him, the Ever-Living, the Sustainer of [all] existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is [presently] before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.", .arabic: "آية الكرسي: توحيد الله وعظمته وسعة علمه وكرسيّه.", .german: "Allah - es gibt keinen Gott außer Ihm, dem Lebendigen und Beständigen. Ihn überkommt weder Schlummer noch Schlaf. Ihm gehört (alles), was in den Himmeln und was auf der Erde ist. Wer ist es denn, der bei Ihm Fürsprache einlegen könnte - außer mit Seiner Erlaubnis? Er weiß, was vor ihnen und was hinter ihnen liegt, sie aber umfassen nichts von Seinem Wissen - außer, was Er will. Sein Thronschemel umfaßt die Himmel und die Erde, und ihre Behütung beschwert Ihn nicht. Er ist der Erhabene und Allgewaltige."],
        "dua10_title": [.english: "Rabbi-shrah li (Ta-Ha 25-28)", .arabic: "رب اشرح لي صدري (طه 25-28)", .german: "Rabbi-schrah li (Ta-Ha 25-28)"],
        "dua10_trans": [.english: "Rabbish-raḥ lī ṣadrī, wa yassir lī amrī, waḥlul ʿuqdatan min lisānī, yafqahū qawlī.", .arabic: "—", .german: "Rabbish-raḥ lī ṣadrī, wa yassir lī amrī, waḥlul ʿuqdatan min lisānī, yafqahū qawlī."],
        "dua10_meal": [.english: "My Lord, expand for me my breast, ease for me my task, and untie the knot from my tongue, that they may understand my speech.", .arabic: "دعاء بشرح الصدر وتيسير الأمر وحلّ عقدة اللسان.", .german: "Mein Herr, weite mir meine Brust, erleichtere mir meine Angelegenheit und löse den Knoten meiner Zunge, damit sie mein Wort verstehen."],
        "dua11_title": [.english: "Amana r-Rasul (Al-Baqarah 285-286)", .arabic: "آمن الرسول (البقرة 285-286)", .german: "Amana r-Rasul (Al-Baqara 285-286)"],
        "dua11_trans": [.english: "Aamanar-Rasoolu bimaaa unzila ilaihi mir-Rabbihee walmu'minoon; kullun aamana billaahi wa Malaaa'ikathihee wa Kutubhihee wa Rusulih laa nufarriqu baina ahadim-mir-Rusulihee wa qaaloo sami'naa wa ata'naa ghufraanaka Rabbanaa wa ilaikal-maseer Laa yukalliful-laahu nafsan illaa wus'ahaa; lahaa maa kasabat wa 'alaihaa maktasabat; Rabbanaa la tu'aakhiznaa in naseenaaa aw akhtaanaa; Rabbanaa wa laa tahmil-'alainaaa isran kamaa hamaltahoo 'alal-lazeena min qablinaa; Rabbanaa wa laa tuhammilnaa maa laa taaqata lanaa bih wa'fu 'annaa waghfir lanaa warhamnaa; Anta mawlaanaa fansurnaa 'alal qawmil kaafireen", .arabic: "—", .german: "Aamanar-Rasoolu bimaaa unzila ilaihi mir-Rabbihee walmu'minoon; kullun aamana billaahi wa Malaaa'ikathihee wa Kutubhihee wa Rusulih laa nufarriqu baina ahadim-mir-Rusulihee wa qaaloo sami'naa wa ata'naa ghufraanaka Rabbanaa wa ilaikal-maseer Laa yukalliful-laahu nafsan illaa wus'ahaa; lahaa maa kasabat wa 'alaihaa maktasabat; Rabbanaa la tu'aakhiznaa in naseenaaa aw akhtaanaa; Rabbanaa wa laa tahmil-'alainaaa isran kamaa hamaltahoo 'alal-lazeena min qablinaa; Rabbanaa wa laa tuhammilnaa maa laa taaqata lanaa bih wa'fu 'annaa waghfir lanaa warhamnaa; Anta mawlaanaa fansurnaa 'alal qawmil kaafireen"],
        "dua11_meal": [.english: "The Messenger has believed in what was revealed to him from his Lord, and [so have] the believers. All of them have believed in Allah and His angels and His books and His messengers, [saying], \"We make no distinction between any of His messengers.\" And they say, \"We hear and we obey. [We seek] Your forgiveness, our Lord, and to You is the [final] destination.\" Allah does not charge a soul except [with that within] its capacity. It will have [the consequence of] what [good] it has gained, and it will bear [the consequence of] what [evil] it has earned. \"Our Lord, do not impose blame upon us if we have forgotten or erred. Our Lord, and lay not upon us a burden like that which You laid upon those before us. Our Lord, and burden us not with that which we have no ability to bear. And pardon us; and forgive us; and have mercy upon us. You are our protector, so give us victory over the disbelieving people.\"", .arabic: "خواتيم سورة البقرة: إيمان الرسول والمؤمنين ودعاؤهم بالمغفرة والرحمة.", .german: "Der Gesandte (Allahs) glaubt an das, was zu ihm von seinem Herrn (als Offenbarung) herabgesandt worden ist, und ebenso die Gläubigen; alle glauben an Allah, Seine Engel, Seine Bücher und Seine Gesandten - Wir machen keinen Unterschied bei jemandem von Seinen Gesandten. Und sie sagen: \"Wir hören und gehorchen. (Gewähre uns) Deine Vergebung, unser Herr! Und zu Dir ist der Ausgang.\" Allah erlegt keiner Seele mehr auf, als sie zu leisten vermag. Ihr kommt (nur) zu, was sie verdient hat, und angelastet wird ihr (nur), was sie verdient hat. \"Unser Herr, belange uns nicht, wenn wir (etwas) vergessen oder einen Fehler begehen. Unser Herr, lege uns keine Bürde auf, wie Du sie denjenigen vor uns auferlegt hast. Unser Herr, bürde uns nichts auf, wozu wir keine Kraft haben. Verzeihe uns, vergib uns und erbarme Dich unser! Du bist unser Schutzherr. So verhilf uns zum Sieg über das ungläubige Volk!"],

        // MARK: - Kuran
        "quran_surahs": [.english: "Surahs", .arabic: "السور", .german: "Suren"],
        "quran_search": [.english: "Search surah", .arabic: "ابحث عن سورة", .german: "Sure suchen"],
        "quran_filter": [.english: "Filter", .arabic: "تصفية", .german: "Filter"],
        "quran_all": [.turkish: "Tümü", .english: "All", .arabic: "الكل", .german: "Alle"],
        "quran_meccan": [.turkish: "Mekki", .english: "Meccan", .arabic: "مكية", .german: "Mekkanisch"],
        "quran_medinan": [.turkish: "Medeni", .english: "Medinan", .arabic: "مدنية", .german: "Medinensisch"],
        "quran_ayah_count": [.english: "%d verses", .arabic: "%d آية", .german: "%d Verse"],
        "quran_listen": [.english: "Listen", .arabic: "استمع", .german: "Anhören"],
        "quran_stop": [.english: "Stop", .arabic: "إيقاف", .german: "Stopp"],
        "quran_loading_surahs": [.english: "Loading surahs...", .arabic: "جارٍ تحميل السور...", .german: "Suren werden geladen..."],
        "quran_loading": [.english: "Loading...", .arabic: "جارٍ التحميل...", .german: "Wird geladen..."],
        "quran_err_surahs": [.english: "Couldn't load the surahs. Check your internet connection.", .arabic: "تعذّر تحميل السور. تحقق من اتصالك بالإنترنت.", .german: "Die Suren konnten nicht geladen werden. Prüfe deine Internetverbindung."],
        "quran_err_surah": [.english: "Couldn't load the surah. Check your internet connection.", .arabic: "تعذّر تحميل السورة. تحقق من اتصالك بالإنترنت.", .german: "Die Sure konnte nicht geladen werden. Prüfe deine Internetverbindung."],

        // MARK: - Yakındaki camiler
        "mosque_searching": [.english: "Searching for nearby mosques...", .arabic: "جارٍ البحث عن المساجد القريبة...", .german: "Moscheen in der Nähe werden gesucht..."],
        "mosque_err_location": [.english: "Couldn't get location: %@", .arabic: "تعذّر تحديد الموقع: %@", .german: "Standort konnte nicht ermittelt werden: %@"],
        "mosque_none": [.english: "No mosques found nearby.", .arabic: "لا توجد مساجد قريبة.", .german: "Keine Moscheen in der Nähe gefunden."],
        "mosque_default": [.english: "Mosque", .arabic: "مسجد", .german: "Moschee"],
        "mosque_query": [.english: "mosque", .arabic: "مسجد", .german: "Moschee"],

        // MARK: - Arama ekranları
        "addr_prompt": [.english: "Type a neighborhood, district or address", .arabic: "اكتب حيًّا أو منطقة أو عنوانًا", .german: "Gib ein Viertel, einen Bezirk oder eine Adresse ein"],
        "addr_title": [.english: "Search Address", .arabic: "البحث عن عنوان", .german: "Adresse suchen"],
        "province_prompt": [.english: "Search city", .arabic: "ابحث عن مدينة", .german: "Stadt suchen"],
        "province_title": [.english: "Select City", .arabic: "اختر المدينة", .german: "Stadt auswählen"],

        // MARK: - Alarm / değerlendirme
        "alarm_prayed": [.turkish: "Kıldım", .english: "I Prayed", .arabic: "صلّيت", .german: "Gebetet"],
        "alarm_snooze": [.turkish: "Birazdan Hatırlat", .english: "Remind Me Later", .arabic: "ذكّرني لاحقًا", .german: "Später erinnern"],
        "alarm_default_title": [.english: "Prayer Time", .arabic: "وقت الصلاة", .german: "Gebetszeit"],
        "review_title": [.english: "Would you like to rate us?", .arabic: "هل تودّ تقييم التطبيق؟", .german: "Möchtest du uns bewerten?"],
        "review_rate": [.english: "Rate", .arabic: "قيّم", .german: "Bewerten"],
        "review_later": [.english: "Later", .arabic: "لاحقًا", .german: "Später"],
        "review_msg": [.english: "If you enjoy the app, would you take a few seconds to rate it on the App Store? It helps us a lot.", .arabic: "إذا أعجبك التطبيق، هل تخصص بضع ثوانٍ لتقييمه على App Store؟ هذا يساعدنا كثيرًا.", .german: "Wenn dir die App gefällt, würdest du sie bitte kurz im App Store bewerten? Das hilft uns sehr."],

        // MARK: - Ayarlar
        "settings_title": [.turkish: "Ayarlar", .english: "Settings", .arabic: "الإعدادات", .german: "Einstellungen"],
        "settings_appearance": [.turkish: "Görünüm", .english: "Appearance", .arabic: "المظهر", .german: "Erscheinungsbild"],
        "settings_language": [.turkish: "Dil", .english: "Language", .arabic: "اللغة", .german: "Sprache"],
        "settings_general": [.turkish: "Genel", .english: "General", .arabic: "عام", .german: "Allgemein"],
        "settings_support": [.turkish: "Destek", .english: "Support", .arabic: "الدعم", .german: "Support"],
        "settings_rate_us": [.turkish: "Bizi Değerlendir", .english: "Rate Us", .arabic: "قيّمنا", .german: "Bewerte uns"],
        "settings_contact": [.turkish: "İletişim", .english: "Contact", .arabic: "اتصل بنا", .german: "Kontakt"],
        "settings_light": [.turkish: "Açık", .english: "Light", .arabic: "فاتح", .german: "Hell"],
        "settings_dark": [.turkish: "Koyu", .english: "Dark", .arabic: "داكن", .german: "Dunkel"],
        "settings_theme": [.english: "Theme", .arabic: "السمة", .german: "Design"],
        "settings_location_usage": [.english: "Location Usage", .arabic: "استخدام الموقع", .german: "Standortnutzung"],
        "settings_location_usage_sub": [.english: "When off, GPS is used; when on, the location you select manually is used.", .arabic: "عند الإيقاف يُستخدم GPS، وعند التفعيل يُستخدم الموقع الذي تختاره يدويًا.", .german: "Wenn aus, wird GPS verwendet; wenn an, wird der manuell gewählte Standort verwendet."],
        "settings_manual_location": [.english: "Manual Location", .arabic: "الموقع اليدوي", .german: "Manueller Standort"],
        "settings_not_selected": [.english: "Not selected", .arabic: "غير محدد", .german: "Nicht ausgewählt"],
        "settings_search_address": [.english: "Search Neighborhood / Address", .arabic: "ابحث عن حي / عنوان", .german: "Viertel / Adresse suchen"],
        "settings_pick_province": [.english: "Select from City Center", .arabic: "اختر من مركز المدينة", .german: "Aus Stadtzentrum wählen"],
        "settings_notif_time": [.english: "Notification Time", .arabic: "وقت التنبيه", .german: "Benachrichtigungszeit"],
        "settings_on_time": [.english: "At prayer time", .arabic: "عند دخول الوقت", .german: "Zur Gebetszeit"],
        "settings_3min": [.english: "3 Minutes Before", .arabic: "قبل 3 دقائق", .german: "3 Minuten vorher"],
        "settings_try_alarm": [.english: "Try the Alarm Now", .arabic: "جرّب التنبيه الآن", .german: "Alarm jetzt testen"],
        "settings_prayer_notifs": [.english: "Prayer Time Notifications", .arabic: "إشعارات مواقيت الصلاة", .german: "Gebetszeit-Benachrichtigungen"],
        "settings_reminders": [.english: "Reminders", .arabic: "التذكيرات", .german: "Erinnerungen"],
        "settings_reminders_footer": [.english: "A gentle reminder notification is sent at random times during the day.", .arabic: "يُرسل إشعار تذكير لطيف في أوقات عشوائية خلال اليوم.", .german: "Zu zufälligen Zeiten am Tag wird eine sanfte Erinnerung gesendet."],
        "settings_zikir_reminder": [.english: "Dhikr Reminder", .arabic: "تذكير الذكر", .german: "Dhikr-Erinnerung"],
        "settings_quran_reminder": [.english: "Quran Reading Reminder", .arabic: "تذكير قراءة القرآن", .german: "Koran-Leseerinnerung"],
        "settings_ayah_of_day": [.english: "Verse of the Day", .arabic: "آية اليوم", .german: "Vers des Tages"],
        "settings_adjust": [.english: "Fine-Tune Times", .arabic: "ضبط المواقيت", .german: "Zeiten feinjustieren"],
        "settings_adjust_footer": [.english: "Times are calculated with the Diyanet method and match the official table on most days (at most 1 minute off). You can fine-tune the minutes here to match your local mosque.", .arabic: "تُحسب الأوقات بطريقة ديانت وتطابق الجدول الرسمي في معظم الأيام (بفارق دقيقة واحدة على الأكثر). يمكنك ضبط الدقائق هنا حسب مسجدك.", .german: "Die Zeiten werden nach der Diyanet-Methode berechnet und stimmen an den meisten Tagen mit der offiziellen Tabelle überein (höchstens 1 Minute Abweichung). Hier kannst du die Minuten an deine Moschee anpassen."],
        "settings_not_adjusted": [.english: "Not adjusted", .arabic: "غير مضبوط", .german: "Nicht angepasst"],
        "settings_min_suffix": [.english: "%d min", .arabic: "%d د", .german: "%d Min."],
        "settings_other": [.english: "Other", .arabic: "أخرى", .german: "Sonstiges"],
        "settings_about": [.english: "About", .arabic: "حول التطبيق", .german: "Über die App"],
        "settings_privacy": [.english: "Privacy Policy", .arabic: "سياسة الخصوصية", .german: "Datenschutzerklärung"],
        "settings_ad": [.english: "Advertisement", .arabic: "إعلان", .german: "Werbung"],
        "settings_version": [.english: "Version", .arabic: "الإصدار", .german: "Version"],
        "settings_about_text": [.english: "Safa Prayer Times brings daily prayer times, the Qibla direction, the Holy Quran and more together in one place.", .arabic: "يجمع تطبيق صفا مواقيت الصلاة أوقات الصلاة اليومية واتجاه القبلة والقرآن الكريم وغيرها في مكان واحد.", .german: "Safa Gebetszeiten vereint tägliche Gebetszeiten, die Qibla-Richtung, den Heiligen Koran und mehr an einem Ort."],
        "sound_notif": [.turkish: "Bildirim Sesi", .english: "Notification Sound", .arabic: "صوت الإشعار", .german: "Benachrichtigungston"],
        "sound_adhan": [.turkish: "Ezan Sesi", .english: "Adhan Sound", .arabic: "صوت الأذان", .german: "Adhan-Ton"],

        // MARK: - Gizlilik politikası

        // MARK: - Bildirimler
        "notif_before_title": [.english: "%@ is in %d minutes", .arabic: "%@ بعد %d دقائق", .german: "%@ in %d Minuten"],
        "notif_before_body": [.english: "You can start getting ready.", .arabic: "يمكنك البدء بالاستعداد.", .german: "Du kannst dich langsam bereit machen."],
        "notif_now_title": [.english: "%@ Time Has Started", .arabic: "حان وقت %@", .german: "%@-Zeit hat begonnen"],
        "notif_now_body": [.english: "Don't forget to pray %@.", .arabic: "لا تنسَ أداء صلاة %@.", .german: "Vergiss nicht, das %@-Gebet zu verrichten."],
        "notif_test_title": [.english: "Sample: Prayer Time", .arabic: "مثال: وقت الصلاة", .german: "Beispiel: Gebetszeit"],
        "notif_test_body": [.english: "This is a test notification - real prayer times will look like this too.", .arabic: "هذا إشعار تجريبي - ستظهر مواقيت الصلاة الحقيقية بالشكل نفسه.", .german: "Dies ist eine Testbenachrichtigung – so sehen auch echte Gebetszeiten aus."],
        "notif_snooze_body": [.english: "Reminder - don't forget to pray.", .arabic: "تذكير - لا تنسَ أداء الصلاة.", .german: "Erinnerung – vergiss nicht zu beten."],
        "friday_eve_title": [.english: "Tomorrow Is Friday", .arabic: "غدًا الجمعة", .german: "Morgen ist Freitag"],
        "friday_eve_body": [.english: "Blessed Friday ahead! Remember to get ready for the Friday (Jumu'ah) prayer.", .arabic: "جمعة مباركة! لا تنسَ الاستعداد لصلاة الجمعة.", .german: "Gesegneten Freitag! Denk daran, dich auf das Freitagsgebet vorzubereiten."],
        "friday_title": [.english: "Friday Prayer Today", .arabic: "اليوم صلاة الجمعة", .german: "Heute ist Freitagsgebet"],
        "friday_body": [.english: "One hour until the Friday prayer. Blessed Friday!", .arabic: "بقيت ساعة على صلاة الجمعة. جمعة مباركة!", .german: "Noch eine Stunde bis zum Freitagsgebet. Gesegneten Freitag!"],
        "settings_friday_reminder": [.english: "Friday Reminder", .arabic: "تذكير الجمعة", .german: "Freitags-Erinnerung"],
        "rd_next": [.english: "NEXT RELIGIOUS DAY", .arabic: "اليوم الديني القادم", .german: "NÄCHSTER RELIGIÖSER TAG"],
        "settings_group_appearance": [.english: "Appearance & Language", .arabic: "المظهر واللغة", .german: "Darstellung & Sprache"],
        "settings_group_location": [.english: "Location", .arabic: "الموقع", .german: "Standort"],
        "settings_group_notifications": [.english: "Notifications", .arabic: "الإشعارات", .german: "Benachrichtigungen"],
        "settings_auto_gps": [.english: "Automatic (GPS)", .arabic: "تلقائي (GPS)", .german: "Automatisch (GPS)"],
        "settings_location_method": [.english: "Location method", .arabic: "طريقة اختيار الموقع", .german: "Methode zur Standortwahl"],
        "notif_reminder": [.english: "Reminder", .arabic: "تذكير", .german: "Erinnerung"],
        "zikir_msg_1_t": [.english: "Time for Dhikr", .arabic: "حان وقت الذكر", .german: "Zeit für Dhikr"], "zikir_msg_1_b": [.english: "Take a minute: Subhanallah, Alhamdulillah, Allahu Akbar.", .arabic: "خذ دقيقة: سبحان الله، الحمد لله، الله أكبر.", .german: "Nimm dir eine Minute: Subhanallah, Alhamdulillah, Allahu Akbar."],
        "zikir_msg_2_t": [.english: "Calm Your Heart", .arabic: "أرِح قلبك", .german: "Beruhige dein Herz"], "zikir_msg_2_b": [.english: "How about spending a moment in dhikr?", .arabic: "ما رأيك أن تنشغل بالذكر قليلًا؟", .german: "Wie wäre es, kurz Dhikr zu machen?"],
        "zikir_msg_3_t": [.english: "Reminder", .arabic: "تذكير", .german: "Erinnerung"], "zikir_msg_3_b": [.english: "Don't forget to seek forgiveness today.", .arabic: "لا تنسَ الاستغفار اليوم.", .german: "Vergiss heute nicht, um Vergebung zu bitten."],
        "zikir_msg_4_t": [.english: "Your Dhikr Counter Is Waiting", .arabic: "عدّاد الذكر بانتظارك", .german: "Dein Dhikr-Zähler wartet"], "zikir_msg_4_b": [.english: "Would you like to spend a few minutes on dhikr?", .arabic: "هل تود تخصيص بضع دقائق للذكر؟", .german: "Möchtest du ein paar Minuten für Dhikr nehmen?"],
        "quran_msg_1_t": [.english: "Time to Read the Quran", .arabic: "وقت قراءة القرآن", .german: "Zeit, den Koran zu lesen"], "quran_msg_1_b": [.english: "How about reading a few verses today?", .arabic: "ما رأيك بقراءة بضع آيات اليوم؟", .german: "Wie wäre es, heute ein paar Verse zu lesen?"],
        "quran_msg_2_t": [.english: "Reminder", .arabic: "تذكير", .german: "Erinnerung"], "quran_msg_2_b": [.english: "Even a little regular Quran reading is a blessing.", .arabic: "القراءة المنتظمة للقرآن ولو قليلًا خير.", .german: "Auch wenig regelmäßiges Koranlesen ist wertvoll."],
        "quran_msg_3_t": [.english: "The Holy Quran", .arabic: "القرآن الكريم", .german: "Der Heilige Koran"], "quran_msg_3_b": [.english: "Have you had a chance to read a page of the Quran today?", .arabic: "هل سنحت لك فرصة لقراءة صفحة من القرآن اليوم؟", .german: "Hattest du heute die Gelegenheit, eine Seite im Koran zu lesen?"],
        "ayah_1_ref": [.english: "Al-Baqarah 286", .arabic: "البقرة 286", .german: "Al-Baqara 286"], "ayah_1_text": [.english: "Allah does not burden a soul beyond what it can bear.", .arabic: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا", .german: "Allah fordert von keiner Seele mehr, als sie zu leisten vermag."],
        "ayah_2_ref": [.english: "Ash-Sharh 5-6", .arabic: "الشرح 5-6", .german: "Asch-Scharh 5-6"], "ayah_2_text": [.english: "Indeed, with hardship comes ease.", .arabic: "فَإِنَّ مَعَ الْعُسْرِ يُسْرًا ۝ إِنَّ مَعَ الْعُسْرِ يُسْرًا", .german: "Wahrlich, mit der Erschwernis kommt die Erleichterung."],
        "ayah_3_ref": [.english: "At-Talaq 3", .arabic: "الطلاق 3", .german: "At-Talaq 3"], "ayah_3_text": [.english: "Whoever relies upon Allah — He is sufficient for him.", .arabic: "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ", .german: "Wer auf Allah vertraut, dem genügt Er."],
        "ayah_4_ref": [.english: "Ar-Ra'd 28", .arabic: "الرعد 28", .german: "Ar-Ra'd 28"], "ayah_4_text": [.english: "Surely, in the remembrance of Allah do hearts find rest.", .arabic: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", .german: "Wahrlich, im Gedenken Allahs finden die Herzen Ruhe."],
        "ayah_5_ref": [.english: "Az-Zumar 53", .arabic: "الزمر 53", .german: "Az-Zumar 53"], "ayah_5_text": [.english: "Do not despair of the mercy of Allah.", .arabic: "لَا تَقْنَطُوا مِن رَّحْمَةِ اللَّهِ", .german: "Verzweifelt nicht an der Barmherzigkeit Allahs."],
        "ayah_6_ref": [.english: "Al-Baqarah 153", .arabic: "البقرة 153", .german: "Al-Baqara 153"], "ayah_6_text": [.english: "Seek help through patience and prayer.", .arabic: "وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ", .german: "Sucht Hilfe in Geduld und im Gebet."],

        // MARK: - Widget'lar
        "widget_open_app": [.english: "Open the App", .arabic: "افتح التطبيق", .german: "App öffnen"],
        "widget_waiting": [.english: "Waiting for data", .arabic: "بانتظار البيانات", .german: "Warte auf Daten"],
        "widget_today": [.english: "TODAY", .arabic: "اليوم", .german: "HEUTE"],
        "widget_open_hint": [.english: "Open the app once to load prayer times.", .arabic: "افتح التطبيق مرة واحدة لتحميل مواقيت الصلاة.", .german: "Öffne die App einmal, um die Gebetszeiten zu laden."],
        "widget_next_name": [.english: "Next Prayer", .arabic: "الصلاة القادمة", .german: "Nächstes Gebet"],
        "widget_next_desc": [.english: "Shows the next prayer time and a countdown on your home screen.", .arabic: "يعرض موعد الصلاة القادمة والعدّ التنازلي على شاشتك الرئيسية.", .german: "Zeigt die nächste Gebetszeit und einen Countdown auf deinem Home-Bildschirm."],
        "widget_daily_name": [.english: "Today's Prayer Times", .arabic: "مواقيت صلاة اليوم", .german: "Gebetszeiten heute"],
        "widget_daily_desc": [.english: "Lists all of today's prayer times from Fajr to Isha.", .arabic: "يعرض جميع مواقيت صلاة اليوم من الفجر إلى العشاء.", .german: "Listet alle heutigen Gebetszeiten von Fajr bis Isha auf."],
        "widget_ayah_name": [.english: "Verse of the Day", .arabic: "آية اليوم", .german: "Vers des Tages"],
        "widget_ayah_desc": [.english: "Shows a short verse that changes every few hours.", .arabic: "يعرض آية قصيرة تتغير كل بضع ساعات.", .german: "Zeigt einen kurzen Vers, der sich alle paar Stunden ändert."],

        // MARK: - Denetim düzeltmeleri (2026-10-20)
        "common_ok": [.english: "OK", .arabic: "حسناً", .german: "OK"],
        "home_calc_failed": [.english: "Prayer times can't be calculated for this location. Please choose another location.", .arabic: "لا يمكن حساب مواقيت الصلاة لهذا الموقع. يرجى اختيار موقع آخر.", .german: "Für diesen Ort können keine Gebetszeiten berechnet werden. Bitte wähle einen anderen Ort."],
        "notif_keepalive_title": [.english: "Prayer alarms will stop soon", .arabic: "ستتوقف تنبيهات الصلاة قريباً", .german: "Gebetsalarme enden bald"],
        "notif_keepalive_body": [.english: "Open the app once to keep your alarms going.", .arabic: "افتح التطبيق مرة واحدة لتستمر التنبيهات.", .german: "Öffne die App einmal, damit deine Alarme weiterlaufen."],
        "settings_notif_denied": [.english: "Notifications are off. Prayer alarms won't arrive.", .arabic: "الإشعارات متوقفة. لن تصل تنبيهات الصلاة.", .german: "Mitteilungen sind aus. Gebetsalarme kommen nicht an."],
        "settings_open_ios_settings": [.english: "Open iPhone Settings", .arabic: "افتح إعدادات iPhone", .german: "iPhone-Einstellungen öffnen"],
        "settings_ad_privacy": [.english: "Ad Privacy Choices", .arabic: "خيارات خصوصية الإعلانات", .german: "Werbe-Datenschutzoptionen"],
        "qibla_calibrate": [.english: "Compass accuracy is low. Move your phone in a figure 8 to calibrate.", .arabic: "دقة البوصلة منخفضة. حرّك هاتفك على شكل 8 لمعايرتها.", .german: "Die Kompassgenauigkeit ist gering. Bewege dein Telefon in Form einer 8, um es zu kalibrieren."],
        "tts_missing_title": [.english: "No Arabic voice installed", .arabic: "لا يوجد صوت عربي مثبت", .german: "Keine arabische Stimme installiert"],
        "tts_missing_body": [.english: "To listen, download an Arabic voice in iPhone Settings > Accessibility > Spoken Content > Voices.", .arabic: "للاستماع، نزّل صوتاً عربياً من إعدادات iPhone > تسهيلات الاستخدام > المحتوى المنطوق > الأصوات.", .german: "Lade zum Anhören eine arabische Stimme unter iPhone-Einstellungen > Bedienungshilfen > Gesprochene Inhalte > Stimmen."],
        "settings_prayer_notifs_footer2": [.english: "Choose the prayer times you want to be notified for; they all use the same timing. Tap a sound to select it; the ▶︎ button plays it. Prayer notifications are sent as \"Time Sensitive\": they still appear in Focus and Do Not Disturb. In silent mode the phone does not play a sound, it only vibrates. For the \"I Prayed\" / \"Remind Me Later\" buttons, touch and hold the notification. The test button sends a sample notification in 5 seconds.", .arabic: "اختر مواقيت الصلاة التي تريد إشعارًا بها؛ جميعها تستخدم نفس التوقيت. اضغط على صوت لاختياره، وزر ▶︎ يشغّله. تُرسل إشعارات الصلاة كـ«حساسة للوقت»: تظهر حتى في وضع التركيز وعدم الإزعاج. في الوضع الصامت لا يُصدر الهاتف صوتًا بل يهتز فقط. لأزرار «صلّيت» / «ذكّرني لاحقًا» اضغط مطولًا على الإشعار. زر الاختبار يرسل إشعارًا تجريبيًا بعد 5 ثوانٍ.", .german: "Wähle die Gebetszeiten, für die du benachrichtigt werden möchtest; alle nutzen dieselbe Zeiteinstellung. Tippe auf einen Ton, um ihn auszuwählen; die ▶︎-Taste spielt ihn ab. Gebetsmitteilungen werden als „Dringlich“ gesendet: Sie erscheinen auch im Fokus- und Nicht-stören-Modus. Im Stumm-Modus spielt das Telefon keinen Ton, es vibriert nur. Für „Gebetet“ / „Später erinnern“ halte die Mitteilung gedrückt. Die Testtaste sendet in 5 Sekunden eine Beispielmitteilung."],
        "settings_manual_toggle": [.english: "Choose location manually", .arabic: "اختيار الموقع يدويًا", .german: "Standort manuell wählen"],
        "settings_manual_toggle_sub": [.english: "When off, the phone finds your location itself. When on, the city or address you choose is used.", .arabic: "عند الإيقاف يحدد الهاتف موقعك تلقائيًا. عند التفعيل تُستخدم المدينة أو العنوان الذي تختاره.", .german: "Wenn aus, findet das Telefon deinen Standort selbst. Wenn an, wird die von dir gewählte Stadt oder Adresse verwendet."],
        "settings_auto_location": [.english: "Automatic", .arabic: "تلقائي", .german: "Automatisch"],
        "contact_copied_title": [.english: "Email address copied", .arabic: "تم نسخ البريد الإلكتروني", .german: "E-Mail-Adresse kopiert"],
        "contact_copied_body": [.english: "No email app was found on this phone. Our address was copied: %@", .arabic: "لم يتم العثور على تطبيق بريد في هذا الهاتف. تم نسخ عنواننا: %@", .german: "Auf diesem Telefon wurde keine Mail-App gefunden. Unsere Adresse wurde kopiert: %@"],
        "qibla_no_compass_hint": [.english: "This device has no compass, so the arrow does not turn. The Qibla is %d° clockwise from north. Point the top of your phone north and the arrow shows the Qibla.", .arabic: "لا توجد بوصلة في هذا الجهاز، لذلك لا يدور السهم. القبلة على بعد %d° باتجاه عقارب الساعة من الشمال. وجّه أعلى الهاتف نحو الشمال ليشير السهم إلى القبلة.", .german: "Dieses Gerät hat keinen Kompass, daher dreht sich der Pfeil nicht. Die Qibla liegt %d° im Uhrzeigersinn von Norden. Richte die Oberkante des Telefons nach Norden, dann zeigt der Pfeil zur Qibla."],
        "mosque_directions": [.english: "Directions", .arabic: "الاتجاهات", .german: "Route"],
        "quran_no_match": [.english: "No surah found with this name. Try typing less (e.g. \"yas\").", .arabic: "لم يتم العثور على سورة بهذا الاسم. جرّب كتابة أقل.", .german: "Keine Sure mit diesem Namen gefunden. Versuche es kürzer (z. B. „yas“)."],
        "primer_title": [.english: "Shall we notify you at prayer times?", .arabic: "هل ننبّهك عند أوقات الصلاة؟", .german: "Sollen wir dich zu den Gebetszeiten benachrichtigen?"],
        "primer_yes": [.english: "Yes, notify me", .arabic: "نعم، نبّهني", .german: "Ja, benachrichtigen"],
        "primer_later": [.english: "Not now", .arabic: "ليس الآن", .german: "Nicht jetzt"],
        "primer_body": [.english: "Your phone will alert you when a prayer time begins. On the next screen just tap \"Allow\". You can change this later in Settings > Notifications.", .arabic: "سينبّهك هاتفك عند دخول وقت الصلاة. في الشاشة التالية اضغط «السماح» فقط. يمكنك تغيير ذلك لاحقًا من الإعدادات > الإشعارات.", .german: "Dein Telefon erinnert dich, wenn eine Gebetszeit beginnt. Tippe auf dem nächsten Bildschirm einfach auf „Erlauben“. Du kannst das später unter Einstellungen > Mitteilungen ändern."],
        "home_bell_hint": [.english: "Tap the bell for an alarm", .arabic: "اضغط على الجرس للتنبيه", .german: "Für Alarm auf die Glocke tippen"],
        "home_alarm_on": [.english: "%@ alarm on", .arabic: "تنبيه %@ مفعّل", .german: "%@-Alarm an"],
        "home_alarm_off": [.english: "%@ alarm off", .arabic: "تنبيه %@ متوقف", .german: "%@-Alarm aus"],
        "home_alarm_denied_body": [.english: "To turn on the alarm, allow notifications for this app in iPhone Settings.", .arabic: "لتفعيل التنبيه، اسمح بإشعارات هذا التطبيق من إعدادات iPhone.", .german: "Um den Alarm einzuschalten, erlaube Mitteilungen für diese App in den iPhone-Einstellungen."],
        "ramadan_to_iftar": [.english: "Time to iftar", .arabic: "الوقت المتبقي للإفطار", .german: "Zeit bis zum Iftar"],
        "ramadan_to_sahur": [.english: "Time until sahur ends (Fajr)", .arabic: "الوقت المتبقي لانتهاء السحور", .german: "Zeit bis Sahur-Ende (Fajr)"],
        "home_prayed_count": [.english: "%d/5 prayed", .arabic: "صُلّيت %d/5", .german: "%d/5 gebetet"],
        "home_row_hint": [.english: "Tap ○ to mark as prayed · tap 🔔 for the alarm", .arabic: "اضغط ○ لتسجيل الصلاة · اضغط 🔔 للتنبيه", .german: "○ tippen: als gebetet markieren · 🔔 tippen: Alarm"],
        "home_prayed_on": [.english: "%@ prayed", .arabic: "تمت صلاة %@", .german: "%@ gebetet"],
        "home_prayed_off": [.english: "%@ not prayed", .arabic: "لم تُصلَّ %@", .german: "%@ nicht gebetet"],
        "sahur_title": [.english: "Sahur time", .arabic: "وقت السحور", .german: "Sahur-Zeit"],
        "sahur_body": [.english: "%d minutes until Fajr. Have a blessed sahur!", .arabic: "بقي %d دقيقة على الفجر. سحورًا مباركًا!", .german: "Noch %d Minuten bis Fajr. Gesegnetes Sahur!"],
        "religious_night_title": [.english: "Tonight is %@", .arabic: "الليلة %@", .german: "Heute Nacht: %@"],
        "religious_night_body": [.english: "Blessed night! Remember to spend it with worship and prayer.", .arabic: "ليلة مباركة! لا تنسَ أن تقضيها بالعبادة والدعاء.", .german: "Gesegnete Nacht! Verbringe sie mit Gebet und Bittgebet."],
        "religious_day_title": [.english: "Today is %@", .arabic: "اليوم %@", .german: "Heute ist %@"],
        "religious_day_body": [.english: "We wish you a blessed day.", .arabic: "نتمنى لك يومًا مباركًا.", .german: "Wir wünschen dir einen gesegneten Tag."],
        "settings_religious_reminder": [.english: "Holy Nights & Eid Reminder", .arabic: "تذكير الليالي المباركة والأعياد", .german: "Erinnerung an heilige Nächte & Feste"],
        "tracking_title": [.english: "Prayer Tracker", .arabic: "متابعة الصلاة", .german: "Gebetsprotokoll"],
        "tracking_no_location": [.english: "Open the home screen once to see today's times.", .arabic: "افتح الشاشة الرئيسية مرة لرؤية مواقيت اليوم.", .german: "Öffne einmal den Startbildschirm, um die heutigen Zeiten zu sehen."],
        "tracking_prayed": [.english: "Prayed", .arabic: "صُلّيت", .german: "Gebetet"],
        "tracking_not_prayed": [.english: "Not prayed", .arabic: "لم تُصلَّ", .german: "Nicht gebetet"],
        "tracking_not_yet": [.english: "Not yet time", .arabic: "لم يحن الوقت", .german: "Noch nicht Zeit"],
        "tracking_today": [.english: "Today · %d/5", .arabic: "اليوم · %d/5", .german: "Heute · %d/5"],
        "tracking_today_footer": [.english: "The \"I Prayed\" button in the notification or alarm screen also records here.", .arabic: "زر «صلّيت» في الإشعار أو شاشة التنبيه يسجّل هنا أيضًا.", .german: "Die Taste „Gebetet“ in der Mitteilung oder im Alarm speichert ebenfalls hier."],
        "tracking_streak": [.english: "%d days in a row", .arabic: "%d يوم متتالٍ", .german: "%d Tage in Folge"],
        "tracking_streak_sub": [.english: "Consecutive days with all 5 prayers", .arabic: "أيام متتالية بالصلوات الخمس كاملة", .german: "Aufeinanderfolgende Tage mit allen 5 Gebeten"],
        "tracking_day_a11y": [.english: "%@: %d/5 prayed", .arabic: "%@: صُلّي %d/5", .german: "%@: %d/5 gebetet"],
        "tracking_last7": [.english: "Last 7 days", .arabic: "آخر 7 أيام", .german: "Letzte 7 Tage"],
        "tracking_kaza": [.english: "Missed (qada) prayers · total %d", .arabic: "صلوات القضاء · المجموع %d", .german: "Nachzuholende Gebete · gesamt %d"],
        "tracking_kaza_footer": [.english: "Add owed qada prayers with +. Reduce with − as you make them up.", .arabic: "أضف صلوات القضاء بـ +. وأنقص بـ − كلما قضيتها.", .german: "Füge offene Gebete mit + hinzu. Verringere mit −, wenn du sie nachholst."],
        "imsakiye_title": [.english: "Ramadan Timetable", .arabic: "إمساكية رمضان", .german: "Ramadan-Kalender"],
        "imsakiye_footer": [.english: "Dates follow the Hijri calendar; the official announcement can differ by one day. Times are for your location.", .arabic: "التواريخ حسب التقويم الهجري؛ قد يختلف الإعلان الرسمي بيوم. المواقيت حسب موقعك.", .german: "Die Daten folgen dem Hidschri-Kalender; die offizielle Ankündigung kann um einen Tag abweichen. Zeiten gelten für deinen Standort."],
        "imsakiye_day": [.english: "Day", .arabic: "اليوم", .german: "Tag"],
        "imsakiye_sahur": [.english: "Fajr", .arabic: "الإمساك", .german: "Fajr"],
        "imsakiye_iftar": [.english: "Iftar", .arabic: "الإفطار", .german: "Iftar"],
        "imsakiye_day_n": [.english: "Day %d", .arabic: "اليوم %d", .german: "Tag %d"],
        "settings_sahur": [.english: "Sahur Alarm", .arabic: "منبّه السحور", .german: "Sahur-Alarm"],
        "settings_sahur_before": [.english: "Before Fajr", .arabic: "قبل الفجر", .german: "Vor Fajr"],
        "settings_ramadan": [.english: "Ramadan", .arabic: "رمضان", .german: "Ramadan"],
        "settings_sahur_footer": [.english: "Only on Ramadan days, it rings the chosen time before Fajr.", .arabic: "في أيام رمضان فقط، يرنّ قبل الفجر بالمدة المختارة.", .german: "Nur an Ramadan-Tagen, die gewählte Zeit vor Fajr."],
        "recitation_error": [.english: "Audio could not be loaded. Check your internet connection and try again.", .arabic: "تعذّر تحميل الصوت. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.", .german: "Audio konnte nicht geladen werden. Prüfe deine Internetverbindung und versuche es erneut."],
        "recitation_error_title": [.english: "Could not play audio", .arabic: "تعذّر تشغيل الصوت", .german: "Audio konnte nicht abgespielt werden"],
        "recitation_from_ayah": [.english: "Listen from verse %d", .arabic: "استمع من الآية %d", .german: "Ab Vers %d anhören"],
        "recitation_reciter": [.english: "Reciter", .arabic: "القارئ", .german: "Rezitator"],
        "recitation_now": [.english: "Reciting verse %d", .arabic: "تُتلى الآية %d", .german: "Vers %d wird rezitiert"],
        "recitation_pause": [.english: "Pause", .arabic: "إيقاف مؤقت", .german: "Pause"],
        "sources_title": [.english: "Sources", .arabic: "المصادر", .german: "Quellen"],
        "sources_quran_text": [.english: "Quran text", .arabic: "نص القرآن", .german: "Korantext"],
        "sources_meal": [.english: "Translation", .arabic: "الترجمة", .german: "Übersetzung"],
        "sources_audio": [.english: "Recitation audio", .arabic: "صوت التلاوة", .german: "Rezitation"],
        "sources_times": [.english: "Prayer times", .arabic: "مواقيت الصلاة", .german: "Gebetszeiten"],
        "sources_times_value": [.english: "Adhan library, Turkey (Diyanet) calculation method", .arabic: "مكتبة Adhan، طريقة حساب تركيا (ديانت)", .german: "Adhan-Bibliothek, Berechnungsmethode Türkei (Diyanet)"],
        "sources_note": [.english: "Rights to the recitations belong to the reciter. Audio is offered free of charge.", .arabic: "حقوق التلاوات تعود للقارئ. يُقدَّم الصوت مجانًا.", .german: "Die Rechte an den Rezitationen liegen beim Rezitator. Das Audio ist kostenlos."],
        "zikir_reset_confirm_title": [.english: "Reset the counter?", .arabic: "إعادة ضبط العداد؟", .german: "Zähler zurücksetzen?"],
        "zikir_reset_confirm_body": [.english: "The current count (%d) and completed rounds in this mode will be deleted.", .arabic: "سيتم حذف العدد الحالي (%d) والجولات المكتملة في هذا الوضع.", .german: "Der aktuelle Stand (%d) und die abgeschlossenen Runden in diesem Modus werden gelöscht."],
        "zikir_mode_tesbihat": [.turkish: "Tesbihat", .english: "Tasbih", .arabic: "التسبيح", .german: "Tasbih"],
        "tesbih_subhanallah": [.english: "Subhanallah", .arabic: "سبحان الله", .german: "Subhanallah"],
        "tesbih_elhamdulillah": [.english: "Alhamdulillah", .arabic: "الحمد لله", .german: "Alhamdulillah"],
        "tesbih_allahuekber": [.english: "Allahu Akbar", .arabic: "الله أكبر", .german: "Allahu Akbar"],
        "tesbih_step": [.english: "Step %d of 3", .arabic: "الخطوة %d من 3", .german: "Schritt %d von 3"],
        "privacy_read_web": [.english: "Read on the web: kocaksefa.com/safa-app", .arabic: "اقرأ على الويب: kocaksefa.com/safa-app", .german: "Im Web lesen: kocaksefa.com/safa-app"],
        "lock_widget_name": [.english: "Next Prayer (Lock Screen)", .arabic: "الصلاة التالية (شاشة القفل)", .german: "Nächstes Gebet (Sperrbildschirm)"],
        "lock_widget_desc": [.english: "Shows the next prayer and the time left on the Lock Screen.", .arabic: "يعرض الصلاة التالية والوقت المتبقي على شاشة القفل.", .german: "Zeigt das nächste Gebet und die verbleibende Zeit auf dem Sperrbildschirm."],
        "kerahat_now_title": [.english: "Makruh prayer time (approx.)", .arabic: "وقت كراهة الصلاة (تقريبًا)", .german: "Makruh-Gebetszeit (ungefähr)"],
        "kerahat_israk": [.english: "Morning (after sunrise)", .arabic: "الصباح (بعد الشروق)", .german: "Morgens (nach Sonnenaufgang)"],
        "kerahat_istiva": [.english: "Noon (sun at its peak)", .arabic: "الظهيرة (الاستواء)", .german: "Mittags (Sonnenhöchststand)"],
        "kerahat_isfirar": [.english: "Evening (before sunset)", .arabic: "المساء (قبل الغروب)", .german: "Abends (vor Sonnenuntergang)"],
        "settings_kerahat": [.english: "Show Makruh Times", .arabic: "إظهار أوقات الكراهة", .german: "Makruh-Zeiten anzeigen"],
        "settings_kerahat_footer": [.english: "During a makruh time, a notice appears on the home screen: about 45 minutes after sunrise and before sunset, and about 10 minutes before noon prayer (sun at its peak). These durations follow common calendar practice; exact times change by place and day. You can ask Siri: \"Safa next prayer\".", .arabic: "في وقت الكراهة يظهر تنبيه في الشاشة الرئيسية: نحو 45 دقيقة بعد الشروق وقبل الغروب، ونحو 10 دقائق قبل الظهر (الاستواء). هذه المدد حسب العرف الشائع في التقاويم، والأوقات الدقيقة تختلف حسب المكان واليوم.", .german: "Während einer Makruh-Zeit erscheint auf der Startseite ein Hinweis: etwa 45 Minuten nach Sonnenaufgang und vor Sonnenuntergang sowie etwa 10 Minuten vor dem Mittagsgebet (Sonnenhöchststand). Die Dauer folgt der üblichen Kalenderpraxis; genaue Zeiten hängen von Ort und Tag ab."],
        "siri_no_location": [.english: "Open the app once first so it can find your location.", .arabic: "افتح التطبيق مرة واحدة أولًا لتحديد موقعك.", .german: "Öffne die App zuerst einmal, damit sie deinen Standort findet."],
        "siri_no_times": [.english: "Prayer times could not be calculated.", .arabic: "تعذّر حساب مواقيت الصلاة.", .german: "Die Gebetszeiten konnten nicht berechnet werden."],
        "siri_next_answer": [.english: "The next prayer is %@ at %@. %@ left.", .arabic: "الصلاة التالية %@ في الساعة %@. المتبقي %@.", .german: "Das nächste Gebet ist %@ um %@. Noch %@."],
        "siri_remaining_hm": [.english: "%d hours %d minutes", .arabic: "%d ساعة و%d دقيقة", .german: "%d Stunden %d Minuten"],
        "siri_remaining_m": [.english: "%d minutes", .arabic: "%d دقيقة", .german: "%d Minuten"],
        "siri_kerahat_now": [.english: "It is a makruh time now: %@. It lasts until about %@.", .arabic: "الآن وقت كراهة: %@. يستمر حتى نحو %@.", .german: "Jetzt ist eine Makruh-Zeit: %@. Sie dauert bis etwa %@."],
        "siri_kerahat_next": [.english: "It is not a makruh time now. The next one is about %@ to %@.", .arabic: "ليس الآن وقت كراهة. الوقت التالي تقريبًا من %@ إلى %@.", .german: "Jetzt ist keine Makruh-Zeit. Die nächste ist etwa von %@ bis %@."],
        "siri_kerahat_none": [.english: "It is not a makruh time now. There are no more makruh times today.", .arabic: "ليس الآن وقت كراهة. لا توجد أوقات كراهة أخرى اليوم.", .german: "Jetzt ist keine Makruh-Zeit. Heute gibt es keine weitere."],
        "qibla_kaaba": [.english: "Kaaba", .arabic: "الكعبة", .german: "Kaaba"],
        "qibla_you": [.english: "You", .arabic: "أنت", .german: "Du"],
        "qibla_map_info": [.english: "Qibla: %d° from north · %@ km to the Kaaba", .arabic: "القبلة: %d° من الشمال · %@ كم إلى الكعبة", .german: "Qibla: %d° von Norden · %@ km bis zur Kaaba"],
        "qibla_map_info2": [.english: "Qibla: %d° from north · %@ to the Kaaba", .arabic: "القبلة: %d° من الشمال · %@ إلى الكعبة", .german: "Qibla: %d° von Norden · %@ bis zur Kaaba"],
        "qibla_map_hint": [.english: "The map is turned so that the Qibla is at the top. The red line is the Qibla direction. Match it with a building or road around you.", .arabic: "الخريطة مُدارة بحيث تكون القبلة في الأعلى. الخط الأحمر هو اتجاه القبلة. طابقه مع مبنى أو طريق حولك.", .german: "Die Karte ist so gedreht, dass die Qibla oben ist. Die rote Linie ist die Qibla-Richtung. Vergleiche sie mit einem Gebäude oder einer Straße."],
        "qibla_map_near": [.english: "Nearby", .arabic: "قريب", .german: "Nah"],
        "qibla_map_whole": [.english: "Whole route", .arabic: "المسار كاملًا", .german: "Ganze Strecke"],
        "qibla_map_title": [.english: "Qibla Map", .arabic: "خريطة القبلة", .german: "Qibla-Karte"],
        "qibla_map_button": [.english: "Map", .arabic: "خريطة", .german: "Karte"],
        "home_alarm_toast_on": [.english: "%@ alarm turned on", .arabic: "تم تشغيل منبه %@", .german: "%@-Alarm eingeschaltet"],
        "home_alarm_toast_off": [.english: "%@ alarm turned off", .arabic: "تم إيقاف منبه %@", .german: "%@-Alarm ausgeschaltet"],
        "imsakiye_ramadan_year": [.english: "Ramadan %@", .arabic: "رمضان %@", .german: "Ramadan %@"],
        "settings_kerahat_page": [.english: "Makruh Times", .arabic: "أوقات الكراهة", .german: "Makruh-Zeiten"],
        "kerahat_today": [.english: "Today (approx.)", .arabic: "اليوم (تقريبًا)", .german: "Heute (ungefähr)"],
        "common_on": [.english: "On", .arabic: "تشغيل", .german: "An"],
        "common_off": [.english: "Off", .arabic: "إيقاف", .german: "Aus"],
        "qibla_map_north": [.english: "North up", .arabic: "الشمال للأعلى", .german: "Norden oben"],
        "qibla_map_hint_north": [.english: "The map shows north at the top. The red line is the Qibla direction.", .arabic: "الخريطة باتجاه الشمال للأعلى. الخط الأحمر هو اتجاه القبلة.", .german: "Norden ist oben. Die rote Linie ist die Qibla-Richtung."],
        "prayer_sabah": [.english: "Fajr", .arabic: "الفجر", .german: "Fajr"],
        "prayer_vitir": [.english: "Witr", .arabic: "الوتر", .german: "Witr"],
        "method_title": [.english: "Calculation method", .arabic: "طريقة الحساب", .german: "Berechnungsmethode"],
        "method_diyanet": [.english: "Diyanet (Türkiye)", .arabic: "ديانت (تركيا)", .german: "Diyanet (Türkei)"],
        "method_isna": [.english: "ISNA (North America)", .arabic: "ISNA (أمريكا الشمالية)", .german: "ISNA (Nordamerika)"],
        "method_mwl": [.english: "Muslim World League (Europe)", .arabic: "رابطة العالم الإسلامي (أوروبا)", .german: "Islamische Weltliga (Europa)"],
        "method_ummAlQura": [.english: "Umm al-Qura (Makkah)", .arabic: "أم القرى (مكة)", .german: "Umm al-Qura (Mekka)"],
        "method_footer": [.english: "In Türkiye use the Diyanet method. Abroad, if the times differ from your mosque's calendar (especially Fajr and Isha), choose the method used in that country.", .arabic: "في تركيا استخدم طريقة ديانت. خارجها، إذا اختلفت الأوقات عن تقويم مسجدك (خاصة الفجر والعشاء) فاختر الطريقة المستخدمة في ذلك البلد.", .german: "In der Türkei nutze die Diyanet-Methode. Im Ausland: Wenn die Zeiten vom Kalender deiner Moschee abweichen (vor allem Fajr und Isha), wähle die dort übliche Methode."],
        "common_cancel": [.english: "Cancel", .arabic: "إلغاء", .german: "Abbrechen"],
        "audio_download": [.english: "Download to listen offline", .arabic: "تنزيل للاستماع دون إنترنت", .german: "Für Offline-Hören laden"],
        "audio_downloaded": [.english: "Downloaded, plays without internet", .arabic: "تم التنزيل، يعمل دون إنترنت", .german: "Geladen, offline abspielbar"],
        "audio_downloading": [.english: "Downloading %d%%", .arabic: "جارٍ التنزيل %d%%", .german: "Wird geladen %d%%"],
        "audio_delete_title": [.english: "Delete the downloaded audio?", .arabic: "حذف الصوت المُنزَّل؟", .german: "Geladenes Audio löschen?"],
        "audio_delete": [.english: "Delete Audio", .arabic: "حذف الصوت", .german: "Audio löschen"],
        "audio_delete_body": [.english: "This surah's recitation is removed from the phone. You can still listen when online.", .arabic: "سيُحذف صوت هذه السورة من الهاتف. يمكنك الاستماع عند الاتصال بالإنترنت.", .german: "Die Rezitation dieser Sure wird vom Telefon gelöscht. Online kannst du sie weiter hören."],
        "audio_download_error": [.english: "Some verses could not be downloaded. Check your internet connection and try again.", .arabic: "تعذّر تنزيل بعض الآيات. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.", .german: "Einige Verse konnten nicht geladen werden. Prüfe die Internetverbindung und versuche es erneut."],
        "audio_download_error_title": [.english: "Download not completed", .arabic: "لم يكتمل التنزيل", .german: "Download nicht abgeschlossen"],
        "audio_storage_title": [.english: "Downloaded Recitations", .arabic: "التلاوات المُنزَّلة", .german: "Geladene Rezitationen"],
        "audio_storage_size": [.english: "Storage used", .arabic: "المساحة المستخدمة", .german: "Belegter Speicher"],
        "audio_delete_all": [.english: "Delete All", .arabic: "حذف الكل", .german: "Alle löschen"],
        "watch_open_phone": [.english: "Open the app on your iPhone once to get the location.", .arabic: "افتح التطبيق على iPhone مرة واحدة للحصول على الموقع.", .german: "Öffne die App einmal auf dem iPhone, um den Standort zu laden."],
        "watch_qibla_hint": [.english: "Clockwise from north", .arabic: "باتجاه عقارب الساعة من الشمال", .german: "Im Uhrzeigersinn von Norden"],
        "settings_adjust_footer_other": [.english: "Times are calculated with the %@ method. You can fine-tune the minutes here to match your mosque's calendar.", .arabic: "تُحسب الأوقات بطريقة %@. يمكنك ضبط الدقائق هنا حسب تقويم مسجدك.", .german: "Die Zeiten werden nach der Methode %@ berechnet. Hier kannst du die Minuten an den Kalender deiner Moschee anpassen."],
        "tracking_marked": [.english: "%@ marked as prayed", .arabic: "تم تسجيل %@ كمُصلّاة", .german: "%@ als gebetet markiert"],
        "tracking_unmarked": [.english: "%@ mark removed", .arabic: "أُزيلت علامة %@", .german: "Markierung für %@ entfernt"],
        "common_undo": [.english: "Undo", .arabic: "تراجع", .german: "Rückgängig"],
        "settings_current_place": [.english: "Current location", .arabic: "الموقع الحالي", .german: "Aktueller Ort"],
        "home_time_left": [.english: "left", .arabic: "متبقٍ", .german: "übrig"],
        "settings_adjust_footer_abroad": [.english: "Times are calculated with the Diyanet method. Abroad, Diyanet's own calendar for that city can differ by a few minutes, especially for Fajr and Isha. You can fine-tune the minutes here to match your mosque.", .arabic: "تُحسب الأوقات بطريقة ديانت. خارج تركيا قد يختلف تقويم ديانت لتلك المدينة ببضع دقائق، خاصة في الفجر والعشاء. يمكنك ضبط الدقائق هنا حسب مسجدك.", .german: "Die Zeiten werden nach der Diyanet-Methode berechnet. Im Ausland kann der Diyanet-Kalender der Stadt, vor allem bei Fajr und Isha, einige Minuten abweichen. Hier kannst du die Minuten an deine Moschee anpassen."],
        "duas_jump": [.english: "Go to", .arabic: "انتقل إلى", .german: "Springe zu"],
        "quran_offline": [.english: "No internet. The surah will open by itself when the connection is back.", .arabic: "لا يوجد اتصال بالإنترنت. ستُفتح السورة تلقائيًا عند عودة الاتصال.", .german: "Kein Internet. Die Sure öffnet sich von selbst, sobald die Verbindung zurück ist."],
        "siri_prayer_today": [.english: "Today %@ is at %@. %@ left.", .arabic: "اليوم %@ في الساعة %@. المتبقي %@.", .german: "Heute ist %@ um %@. Noch %@."],
        "siri_prayer_passed": [.english: "Today %@ was at %@. Tomorrow at %@.", .arabic: "اليوم كان %@ في الساعة %@. غدًا في الساعة %@.", .german: "Heute war %@ um %@. Morgen um %@."],
        "siri_today_list": [.english: "Today's prayer times: %@.", .arabic: "مواقيت اليوم: %@.", .german: "Heutige Gebetszeiten: %@."],
        "tracking_excused": [.english: "Today I am excused (menstruation)", .arabic: "اليوم عندي عذر شرعي (الحيض)", .german: "Heute vom Gebet befreit (Menstruation)"],
        "tracking_fast_days": [.english: "Missed fasts (days)", .arabic: "أيام الصيام الفائتة", .german: "Nachzuholende Fastentage"],
        "tracking_fast_title": [.english: "Missed fasts", .arabic: "قضاء الصيام", .german: "Nachzuholendes Fasten"],
        "tracking_fast_footer": [.english: "Add the Ramadan days you could not fast with +. Use − as you make them up.", .arabic: "أضف أيام رمضان التي لم تصمها بـ +، وأنقصها بـ − كلما قضيت يومًا.", .german: "Füge versäumte Ramadan-Tage mit + hinzu. Ziehe mit − ab, wenn du sie nachholst."],
        "esma_title": [.english: "The 99 Names of Allah", .arabic: "أسماء الله الحسنى", .german: "Die 99 Namen Allahs"],
        "esma_today": [.english: "Name of the day", .arabic: "اسم اليوم", .german: "Name des Tages"],
        "esma_search": [.english: "Search name or meaning", .arabic: "ابحث عن اسم أو معنى", .german: "Name oder Bedeutung suchen"],
        "live_toggle": [.english: "Iftar/sahur countdown on Lock Screen", .arabic: "عدّاد الإفطار/السحور على شاشة القفل", .german: "Iftar-/Sahur-Countdown auf dem Sperrbildschirm"],
        "live_footer": [.english: "By day, the time left until iftar; after sunset, the time left until sahur ends (Fajr), shown on the Lock Screen and in the Dynamic Island. When the time comes, opening the app moves it to the next time.", .arabic: "في النهار يظهر الوقت المتبقي للإفطار، وبعد المغرب الوقت المتبقي لانتهاء السحور (الفجر) على شاشة القفل وفي Dynamic Island. عند دخول الوقت ينتقل العدّاد إلى الوقت التالي حين تفتح التطبيق.", .german: "Tagsüber die Zeit bis zum Iftar, nach Sonnenuntergang bis zum Ende des Sahur (Fajr) – auf dem Sperrbildschirm und in der Dynamic Island. Ist die Zeit erreicht, wechselt die App beim Öffnen zur nächsten."],
        "live_disabled": [.english: "Live Activities are off. Turn them on in Settings > Safa > Live Activities.", .arabic: "الأنشطة المباشرة متوقفة. فعّلها من الإعدادات > Safa > الأنشطة المباشرة.", .german: "Live-Aktivitäten sind aus. Aktiviere sie unter Einstellungen > Safa > Live-Aktivitäten."],
        "live_iftar_left": [.english: "Time to iftar", .arabic: "المتبقي للإفطار", .german: "Bis zum Iftar"],
        "live_sahur_left": [.english: "Time until sahur ends", .arabic: "المتبقي لانتهاء السحور", .german: "Bis Sahur-Ende"],
        "live_iftar_now": [.english: "Iftar time", .arabic: "حان وقت الإفطار", .german: "Iftar-Zeit"],
        "live_sahur_now": [.english: "Fajr has begun", .arabic: "دخل وقت الفجر", .german: "Fajr hat begonnen"],
        "settings_real_alarm": [.english: "Real alarm (rings in silent mode too)", .arabic: "منبّه حقيقي (يرنّ في الوضع الصامت أيضًا)", .german: "Echter Wecker (klingelt auch im Lautlos-Modus)"],
        "settings_real_alarm_denied": [.english: "Alarm permission was not given. You can turn it on in Settings > Safa > Alarms.", .arabic: "لم يُمنح إذن المنبّه. يمكنك تفعيله من الإعدادات > Safa > المنبّهات.", .german: "Wecker-Erlaubnis wurde nicht erteilt. Du kannst sie unter Einstellungen > Safa > Wecker aktivieren."],
        "settings_real_alarm_footer": [.english: "A real alarm rings like a Clock app alarm, also in silent mode and Focus, and shows full screen on the Lock Screen. So at first only Fajr (to wake up) is selected; in daytime an alarm also rings in a meeting, class or mosque. The next 3 days of the selected times are set; \"Snooze\" rings again after 10 minutes. Times with an alarm get a silent notification; the \"I Prayed\" button stays in it.", .arabic: "المنبّه الحقيقي يرنّ مثل منبّه تطبيق الساعة، حتى في الوضع الصامت والتركيز، ويظهر بملء الشاشة على شاشة القفل. لذلك يُختار الفجر فقط في البداية (للاستيقاظ)؛ في النهار يرنّ المنبّه أيضًا في اجتماع أو درس أو مسجد. تُضبط الأيام الثلاثة القادمة للأوقات المختارة؛ زر «غفوة» يعيد الرنين بعد 10 دقائق. الأوقات ذات المنبّه يصل إشعارها بلا صوت، ويبقى فيه زر «صلّيت».", .german: "Ein echter Wecker klingelt wie ein Wecker der Uhr-App, auch im Lautlos-Modus und bei aktivem Fokus, und erscheint im Vollbild auf dem Sperrbildschirm. Deshalb ist anfangs nur Fajr (zum Aufwachen) gewählt; tagsüber klingelt ein Wecker auch im Meeting, im Unterricht oder in der Moschee. Für die gewählten Zeiten werden die nächsten 3 Tage gestellt; \"Schlummern\" klingelt nach 10 Minuten erneut. Zeiten mit Wecker bekommen eine lautlose Mitteilung; die Taste \"Gebetet\" bleibt darin."],
        "settings_alarm_for": [.english: "%@: alarm", .arabic: "%@: منبّه", .german: "%@: Wecker"],
        "settings_alarm_skip_friday": [.english: "No alarm at Friday Dhuhr", .arabic: "لا منبّه في ظهر الجمعة", .german: "Freitags kein Wecker zu Dhuhr"],
        "widget_esma_name": [.english: "Name of the Day", .arabic: "اسم اليوم", .german: "Name des Tages"],
        "widget_esma_desc": [.english: "Shows one of the 99 Names of Allah with its meaning; changes every day.", .arabic: "يعرض اسمًا من أسماء الله الحسنى كل يوم.", .german: "Zeigt jeden Tag einen der 99 Namen Allahs mit Bedeutung."],
        "alarm_snooze_real": [.turkish: "Ertele", .english: "Snooze", .arabic: "غفوة", .german: "Schlummern"],
        "recitation_open_hint": [.english: "Returns to the Quran tab", .arabic: "يعود إلى تبويب القرآن", .german: "Zurück zum Koran-Tab"],
        "backup_title": [.english: "Backup", .arabic: "النسخ الاحتياطي", .german: "Sicherung"],
        "backup_export": [.english: "Back up records to a file", .arabic: "نسخ السجلات إلى ملف", .german: "Einträge in Datei sichern"],
        "backup_import": [.english: "Restore from backup", .arabic: "استعادة من نسخة احتياطية", .german: "Aus Sicherung wiederherstellen"],
        "backup_file_name": [.english: "Safa Prayer Times backup", .arabic: "نسخة صفا مواقيت الصلاة الاحتياطية", .german: "Safa-Gebetszeiten-Sicherung"],
        "backup_footer": [.english: "Prayer records, excused days, missed prayers and fasts, and dhikr counts are written to one file. Save it to Files, iCloud Drive or send it to yourself; on a new phone, restore it here. The file goes only where you choose.", .arabic: "تُكتب سجلات الصلاة وأيام العذر والقضاء وأعداد الذكر في ملف واحد. احفظه في «الملفات» أو iCloud Drive أو أرسله لنفسك، ثم استعده هنا على الهاتف الجديد. لا يذهب الملف إلا إلى حيث تختار.", .german: "Gebetseinträge, befreite Tage, nachzuholende Gebete und Fasten sowie Dhikr-Zähler werden in eine Datei geschrieben. Speichere sie in „Dateien“, iCloud Drive oder schicke sie dir selbst; auf einem neuen Telefon stellst du sie hier wieder her. Die Datei geht nur dorthin, wo du sie ablegst."],
        "backup_confirm_title": [.english: "Restore the backup?", .arabic: "استعادة النسخة الاحتياطية؟", .german: "Sicherung wiederherstellen?"],
        "backup_confirm_msg": [.english: "Found %d days of prayer records and %d missed prayers/fasts. They will replace the records on this phone.", .arabic: "تم العثور على سجلات صلاة لـ %d يومًا و%d من القضاء. ستحل محل السجلات على هذا الهاتف.", .german: "%d Tage mit Gebetseinträgen und %d Nachholgebete/-fasten gefunden. Sie ersetzen die Einträge auf diesem Telefon."],
        "backup_restore": [.english: "Restore", .arabic: "استعادة", .german: "Wiederherstellen"],
        "backup_done": [.english: "Backup restored.", .arabic: "تمت استعادة النسخة الاحتياطية.", .german: "Sicherung wiederhergestellt."],
        "backup_invalid": [.english: "This file is not a Safa Prayer Times backup.", .arabic: "هذا الملف ليس نسخة احتياطية من صفا مواقيت الصلاة.", .german: "Diese Datei ist keine Sicherung von Safa Gebetszeiten."],
        "about_disclaimer": [.english: "Safa Prayer Times is not an official app of the Presidency of Religious Affairs of Türkiye (Diyanet) or the Türkiye Diyanet Foundation and is not affiliated with them. Prayer times are calculated on your phone with Diyanet's calculation method.", .arabic: "تطبيق صفا مواقيت الصلاة ليس تطبيقًا رسميًا لرئاسة الشؤون الدينية التركية (ديانت) أو لوقف ديانت التركي، ولا يرتبط بهما. تُحسب مواقيت الصلاة على هاتفك بطريقة حساب ديانت.", .german: "Safa Gebetszeiten ist keine offizielle App des türkischen Präsidiums für Religionsangelegenheiten (Diyanet) oder der Türkiye-Diyanet-Stiftung und steht in keiner Verbindung zu ihnen. Die Gebetszeiten werden auf deinem Telefon mit der Berechnungsmethode von Diyanet berechnet."],
        "hadith_title": [.english: "Hadith of the Day", .arabic: "حديث اليوم", .german: "Hadith des Tages"],
        "hadith_today": [.english: "Hadith of the day", .arabic: "حديث اليوم", .german: "Hadith des Tages"],
        "hadith_all": [.english: "Forty Hadith (Imam an-Nawawi)", .arabic: "الأربعون النووية", .german: "Vierzig Hadithe (Imam an-Nawawi)"],
        "hadith_number": [.english: "Hadith %d", .arabic: "الحديث %d", .german: "Hadith %d"],
        "hadith_source": [.english: "Imam an-Nawawi, Forty Hadith · no. %d", .arabic: "الإمام النووي، الأربعون النووية · الحديث %d", .german: "Imam an-Nawawi, Vierzig Hadithe · Nr. %d"],
        "hadith_footer": [.english: "One hadith every day. Source: Imam an-Nawawi, al-Arba'in (Forty Hadith). The Arabic is the classical text; the translation is from the open-source hadith-api project and was checked against the Arabic.", .arabic: "حديث كل يوم. المصدر: الإمام النووي، الأربعون النووية.", .german: "Jeden Tag ein Hadith. Quelle: Imam an-Nawawi, al-Arba'in (Vierzig Hadithe). Der arabische Text ist der klassische Text; die englische Übersetzung stammt aus dem Open-Source-Projekt hadith-api und wurde mit dem Arabischen verglichen. Eine deutsche Übersetzung gibt es noch nicht."],
        "sources_hadith": [.english: "Hadith", .arabic: "الحديث", .german: "Hadith"],
        "sources_hadith_value": [.english: "Imam an-Nawawi, Forty Hadith · hadith-api (open source)", .arabic: "الإمام النووي، الأربعون النووية · hadith-api", .german: "Imam an-Nawawi, Vierzig Hadithe · hadith-api (Open Source)"],
        "common_clear": [.english: "Clear", .arabic: "مسح", .german: "Löschen"],
        "mosque_err_search": [.english: "Couldn't search for mosques. Check your internet connection and try again.", .arabic: "تعذّر البحث عن المساجد. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.", .german: "Moscheesuche fehlgeschlagen. Prüfe deine Internetverbindung und versuche es erneut."]
    ]
}
