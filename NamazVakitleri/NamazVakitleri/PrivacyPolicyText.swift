import Foundation

/// Gizlilik politikası metni (uygulama içi). Web sürümüyle aynı içerik:
/// https://kocaksefa.com/safa-app/#gizlilik
/// Metin, uygulamanın GERÇEKTE yaptıklarına göre yazıldı (2026-10-21):
/// sunucumuz yok; konum hesaplaması cihazda; şehir adı ve cami/adres araması
/// için Apple Haritalar; Kur'an metni ve hafız sesi Islamic Network'ten;
/// reklam Google AdMob (AB'de Google izin formu).
enum PrivacyPolicyText {
    static let webURL = URL(string: "https://kocaksefa.com/safa-app/#gizlilik")!
    static let contactEmail = "info@kocaksefa.com"

    struct Section {
        let title: [AppLanguage: String]
        let body: [AppLanguage: String]
    }

    static func updated(_ lang: AppLanguage) -> String {
        [.turkish: "Son güncelleme: 22 Ekim 2026",
         .english: "Last updated: October 22, 2026",
         .german: "Zuletzt aktualisiert: 22. Oktober 2026",
         .arabic: "آخر تحديث: 22 أكتوبر 2026"][lang] ?? "Son güncelleme: 22 Ekim 2026"
    }

    static let sections: [Section] = [
        Section(
            title: [.turkish: "1. Kim sorumlu?", .english: "1. Who is responsible?",
                    .german: "1. Wer ist verantwortlich?", .arabic: "1. من المسؤول؟"],
            body: [.turkish: "Safa Namaz Vakitleri uygulamasını Sefa Koçak geliştirir ve yayımlar. Kişisel verileriniz 6698 sayılı KVKK'ya ve Avrupa Birliği Genel Veri Koruma Tüzüğü'ne (GDPR) uygun olarak işlenir. İletişim: info@kocaksefa.com",
                   .english: "The app Safa Prayer Times is developed and published by Sefa Koçak. Your personal data is processed in line with the Turkish Personal Data Protection Law (KVKK, No. 6698) and the EU General Data Protection Regulation (GDPR). Contact: info@kocaksefa.com",
                   .german: "Die App Safa Gebetszeiten wird von Sefa Koçak entwickelt und veröffentlicht. Deine personenbezogenen Daten werden gemäß dem türkischen Datenschutzgesetz (KVKK, Nr. 6698) und der EU-Datenschutz-Grundverordnung (DSGVO) verarbeitet. Kontakt: info@kocaksefa.com",
                   .arabic: "يطوّر تطبيق «صفا مواقيت الصلاة» وينشره Sefa Koçak. تُعالَج بياناتك الشخصية وفق قانون حماية البيانات التركي (KVKK رقم 6698) واللائحة العامة لحماية البيانات في الاتحاد الأوروبي (GDPR). للتواصل: info@kocaksefa.com"]),
        Section(
            title: [.turkish: "2. Konum", .english: "2. Location", .german: "2. Standort", .arabic: "2. الموقع"],
            body: [.turkish: "Konumunuz namaz vakitlerini, kıble yönünü ve yakındaki camileri bulmak için kullanılır. Vakitler ve kıble telefonunuzda hesaplanır. Şehir adını göstermek, cami ve adres aramak için konumunuz Apple'ın harita hizmetine gönderilir. Konumunuz bize gönderilmez; bizim bir sunucumuz yoktur. Son bilinen konum, alarmların ve ekran araçlarının (widget) çalışması için sadece telefonunuzda saklanır. Konum iznini iPhone Ayarları'ndan istediğiniz zaman kapatabilir ya da il seçerek elle konum kullanabilirsiniz.",
                   .english: "Your location is used to find prayer times, the Qibla direction and nearby mosques. Times and the Qibla are calculated on your phone. To show the city name and to search for mosques and addresses, your location is sent to Apple's map service. Your location is not sent to us; we have no server. The last known location is stored only on your phone so that alarms and widgets work. You can turn off location access in iPhone Settings at any time or choose a city manually.",
                   .german: "Dein Standort wird verwendet, um Gebetszeiten, die Qibla-Richtung und Moscheen in der Nähe zu finden. Zeiten und Qibla werden auf deinem Telefon berechnet. Um den Stadtnamen anzuzeigen und Moscheen oder Adressen zu suchen, wird dein Standort an den Kartendienst von Apple gesendet. Dein Standort wird nicht an uns gesendet; wir haben keinen Server. Der letzte bekannte Standort wird nur auf deinem Telefon gespeichert, damit Alarme und Widgets funktionieren. Du kannst den Standortzugriff jederzeit in den iPhone-Einstellungen ausschalten oder eine Stadt manuell wählen.",
                   .arabic: "يُستخدم موقعك لتحديد مواقيت الصلاة واتجاه القبلة والمساجد القريبة. تُحسب المواقيت والقبلة على هاتفك. لعرض اسم المدينة والبحث عن المساجد والعناوين يُرسَل موقعك إلى خدمة الخرائط من Apple. لا يُرسَل موقعك إلينا؛ ليس لدينا خادم. يُحفظ آخر موقع معروف على هاتفك فقط لكي تعمل التنبيهات والأدوات (Widgets). يمكنك إيقاف إذن الموقع من إعدادات iPhone في أي وقت أو اختيار مدينة يدويًا."]),
        Section(
            title: [.turkish: "3. Bildirimler", .english: "3. Notifications", .german: "3. Mitteilungen", .arabic: "3. الإشعارات"],
            body: [.turkish: "Namaz alarmları ve hatırlatmalar telefonunuzda planlanır; bir sunucudan gönderilmez. Bildirim izni sadece sizin onayınızla verilir ve iPhone Ayarları'ndan her zaman kapatılabilir. İsteğe bağlı \"Gerçek alarm\" ve kilit ekranındaki iftar/sahur sayacı da iPhone'un kendi alarm ve Canlı Etkinlik özellikleriyle telefonunuzda çalışır; izinleri iPhone Ayarları'ndan kapatılabilir.",
                   .english: "Prayer alarms and reminders are scheduled on your phone; they are not sent from a server. Notification permission is given only with your consent and can be turned off in iPhone Settings at any time. The optional \"Real alarm\" and the iftar/sahur countdown on the Lock Screen also run on your phone with iPhone's own alarm and Live Activity features; you can turn their permissions off in iPhone Settings.",
                   .german: "Gebetsalarme und Erinnerungen werden auf deinem Telefon geplant; sie werden nicht von einem Server gesendet. Die Mitteilungserlaubnis wird nur mit deiner Zustimmung erteilt und kann jederzeit in den iPhone-Einstellungen ausgeschaltet werden. Der optionale „Echte Wecker“ und der Iftar-/Sahur-Countdown auf dem Sperrbildschirm laufen ebenfalls auf deinem Telefon über die Wecker- und Live-Aktivitäten-Funktionen des iPhone; ihre Erlaubnis lässt sich in den iPhone-Einstellungen ausschalten.",
                   .arabic: "تُجدوَل تنبيهات الصلاة والتذكيرات على هاتفك ولا تُرسَل من خادم. يُمنح إذن الإشعارات بموافقتك فقط، ويمكن إيقافه من إعدادات iPhone في أي وقت. يعمل «المنبّه الحقيقي» الاختياري وعدّاد الإفطار/السحور على شاشة القفل على هاتفك أيضًا عبر ميزتي المنبّه والأنشطة المباشرة في iPhone، ويمكن إيقاف إذنهما من إعدادات iPhone."]),
        Section(
            title: [.turkish: "4. Telefonunuzda saklanan bilgiler", .english: "4. Data stored on your phone",
                    .german: "4. Auf deinem Telefon gespeicherte Daten", .arabic: "4. البيانات المحفوظة على هاتفك"],
            body: [.turkish: "Ayarlarınız, \"Kıldım\" kayıtlarınız, özel günleriniz, kaza namazı ve kaza orucu sayılarınız, zikir sayılarınız, indirilen Kur'an metinleri ve hafız sesleri sadece telefonunuzda saklanır. Uygulamada kullanıcı hesabı yoktur. Bu bilgiler bize ya da başkasına gönderilmez. Uygulamayı silince bu bilgiler de silinir. \"Kayıtları dosyaya yedekle\" düğmesine basarsanız bu kayıtlar bir dosyaya yazılır; dosya sadece sizin seçtiğiniz yere (Dosyalar, iCloud Drive, mesaj vb.) gider.",
                   .english: "Your settings, \"I prayed\" records, excused days, missed (qada) prayer and fasting counts, dhikr counts, downloaded Quran texts and recitations are stored only on your phone. The app has no user accounts. This data is not sent to us or to anyone else. When you delete the app, this data is deleted too. If you tap \"Back up records to a file\", these records are written to a file that goes only where you choose (Files, iCloud Drive, a message, etc.).",
                   .german: "Deine Einstellungen, „Gebetet“-Einträge, befreite Tage, nachzuholende Gebete und Fasten, Dhikr-Zähler, heruntergeladene Korantexte und Rezitationen werden nur auf deinem Telefon gespeichert. Die App hat keine Benutzerkonten. Diese Daten werden weder an uns noch an andere gesendet. Wenn du die App löschst, werden diese Daten ebenfalls gelöscht. Tippst du auf „Einträge in Datei sichern“, werden sie in eine Datei geschrieben, die nur dorthin geht, wo du sie ablegst (Dateien, iCloud Drive, Nachricht usw.).",
                   .arabic: "تُحفظ إعداداتك وسجلات «صلّيت» وأيام العذر وأعداد صلوات وصيام القضاء وعدّاد الذكر ونصوص القرآن والتلاوات المُنزّلة على هاتفك فقط. لا توجد حسابات مستخدمين في التطبيق. لا تُرسَل هذه البيانات إلينا ولا إلى غيرنا. عند حذف التطبيق تُحذف هذه البيانات أيضًا. إذا ضغطت «نسخ السجلات إلى ملف» تُكتب هذه السجلات في ملف لا يذهب إلا إلى حيث تختار (الملفات، iCloud Drive، رسالة…)."]),
        Section(
            title: [.turkish: "5. İnternetten alınan içerik", .english: "5. Content loaded from the internet",
                    .german: "5. Inhalte aus dem Internet", .arabic: "5. المحتوى المُحمَّل من الإنترنت"],
            body: [.turkish: "Kur'an metni, meal, okunuş ve hafız sesi Islamic Network (alquran.cloud) hizmetinden alınır. Bu isteklerde kişisel bilgi gönderilmez; sadece internetin çalışması için gereken teknik bilgiler (ör. IP adresi) bu hizmete ulaşır.",
                   .english: "The Quran text, translation, transliteration and recitation audio are loaded from Islamic Network (alquran.cloud). No personal data is sent in these requests; only the technical data needed for the internet to work (for example the IP address) reaches this service.",
                   .german: "Korantext, Übersetzung, Umschrift und Rezitation werden von Islamic Network (alquran.cloud) geladen. Dabei werden keine personenbezogenen Daten gesendet; nur technische Daten, die für das Internet nötig sind (z. B. die IP-Adresse), erreichen diesen Dienst.",
                   .arabic: "يُحمَّل نص القرآن والترجمة والنطق بالحروف اللاتينية وصوت التلاوة من خدمة Islamic Network ‏(alquran.cloud). لا تُرسَل بيانات شخصية في هذه الطلبات؛ تصل إلى الخدمة فقط البيانات التقنية اللازمة لعمل الإنترنت (مثل عنوان IP)."]),
        Section(
            title: [.turkish: "6. Reklamlar", .english: "6. Ads", .german: "6. Werbung", .arabic: "6. الإعلانات"],
            body: [.turkish: "Uygulamadaki reklamları Google AdMob gösterir. Google, reklamları göstermek ve ölçmek için cihaz tanımlayıcısı gibi bilgileri kendi gizlilik politikasına göre işleyebilir. Avrupa Ekonomik Alanı'ndaki kullanıcılardan reklam için önce Google'ın izin formuyla onay istenir. Tercihinizi Ayarlar > Reklam Gizlilik Tercihleri'nden değiştirebilirsiniz. Uygulama sizi başka uygulamalarda ve sitelerde izlemek için izin istemez.",
                   .english: "Ads in the app are shown by Google AdMob. To show and measure ads, Google can process data such as device identifiers under its own privacy policy. Users in the European Economic Area are first asked for consent with Google's consent form. You can change your choice in Settings > Ad Privacy Choices. The app does not ask for permission to track you across other apps and websites.",
                   .german: "Die Werbung in der App wird von Google AdMob angezeigt. Um Werbung anzuzeigen und zu messen, kann Google Daten wie Gerätekennungen gemäß seiner eigenen Datenschutzerklärung verarbeiten. Nutzer im Europäischen Wirtschaftsraum werden zuerst über das Einwilligungsformular von Google um Zustimmung gebeten. Du kannst deine Wahl unter Einstellungen > Werbe-Datenschutzoptionen ändern. Die App fragt nicht nach der Erlaubnis, dich über andere Apps und Websites hinweg zu verfolgen.",
                   .arabic: "تعرض Google AdMob الإعلانات في التطبيق. لعرض الإعلانات وقياسها قد تعالج Google بيانات مثل معرّف الجهاز وفق سياسة الخصوصية الخاصة بها. يُطلب أولًا من المستخدمين في المنطقة الاقتصادية الأوروبية الموافقة عبر نموذج موافقة Google. يمكنك تغيير اختيارك من الإعدادات > خيارات خصوصية الإعلانات. لا يطلب التطبيق إذنًا لتتبّعك عبر التطبيقات والمواقع الأخرى."]),
        Section(
            title: [.turkish: "7. Haklarınız", .english: "7. Your rights", .german: "7. Deine Rechte", .arabic: "7. حقوقك"],
            body: [.turkish: "KVKK'nın 11. maddesi ve GDPR kapsamında; verilerinizin işlenip işlenmediğini öğrenme, bilgi isteme, düzeltme, silme ve itiraz etme haklarına sahipsiniz. Biz sunucuda kişisel veri tutmadığımız için uygulamayı silmeniz verilerinizi de siler. Sorularınız ve talepleriniz için info@kocaksefa.com adresine yazabilirsiniz.",
                   .english: "Under Article 11 of KVKK and under the GDPR, you have the right to learn whether your data is processed, to request information, and to ask for correction, deletion or to object. Because we keep no personal data on a server, deleting the app also deletes your data. For questions and requests, write to info@kocaksefa.com.",
                   .german: "Nach Artikel 11 KVKK und der DSGVO hast du das Recht auf Auskunft, Berichtigung, Löschung und Widerspruch. Da wir keine personenbezogenen Daten auf einem Server speichern, löscht das Entfernen der App auch deine Daten. Für Fragen und Anfragen schreibe an info@kocaksefa.com.",
                   .arabic: "بموجب المادة 11 من KVKK واللائحة GDPR لك الحق في معرفة ما إذا كانت بياناتك تُعالَج، وطلب المعلومات، والتصحيح والحذف والاعتراض. لأننا لا نحفظ بيانات شخصية على خادم، فإن حذف التطبيق يحذف بياناتك أيضًا. للأسئلة والطلبات راسلنا على info@kocaksefa.com."]),
        Section(
            title: [.turkish: "8. Çocuklar", .english: "8. Children", .german: "8. Kinder", .arabic: "8. الأطفال"],
            body: [.turkish: "Uygulama çocuklardan bilerek kişisel veri toplamak için tasarlanmamıştır.",
                   .english: "The app is not designed to knowingly collect personal data from children.",
                   .german: "Die App ist nicht dafür gedacht, wissentlich personenbezogene Daten von Kindern zu erheben.",
                   .arabic: "لم يُصمَّم التطبيق لجمع بيانات شخصية من الأطفال عن علم."]),
        Section(
            title: [.turkish: "9. Değişiklikler", .english: "9. Changes", .german: "9. Änderungen", .arabic: "9. التغييرات"],
            body: [.turkish: "Bu politika uygulamadaki değişikliklere ve yasal düzenlemelere göre güncellenebilir. Güncel metin hem bu ekranda hem de kocaksefa.com/safa-app adresinde yayımlanır.",
                   .english: "This policy can be updated when the app or the law changes. The current text is published both on this screen and at kocaksefa.com/safa-app.",
                   .german: "Diese Richtlinie kann aktualisiert werden, wenn sich die App oder die Rechtslage ändert. Der aktuelle Text wird auf diesem Bildschirm und unter kocaksefa.com/safa-app veröffentlicht.",
                   .arabic: "قد تُحدَّث هذه السياسة عند تغيّر التطبيق أو القوانين. يُنشر النص الحالي في هذه الشاشة وعلى kocaksefa.com/safa-app."])
    ]
}
