# Safa Namaz Vakitleri (iOS)

Namaz vakitleri (Diyanet yöntemi), ezan alarmı ve sessizde de çalan gerçek alarm (AlarmKit), kıble pusulası ve haritası, Kur'an (meal, okunuş, hafız sesi, internetsiz), zikirmatik, Esmâ-i Hüsnâ, namaz ve kaza takibi (yedekleme ile), imsakiye ve iftar/sahur sayacı (Canlı Etkinlik), dini günler, widget'lar, Siri kestirmeleri ve Apple Watch uygulaması olan SwiftUI uygulaması. Ana ekrandaki adı "Safa".

Diyanet İşleri Başkanlığı'nın ya da Türkiye Diyanet Vakfı'nın resmi uygulaması değildir.

Gizlilik politikası: https://kocaksefa.com/safa-app/#gizlilik

## Derleme
1. `NamazVakitleri/NamazVakitleri.xcodeproj` dosyasını Xcode 26 ile aç.
2. Signing & Capabilities'de kendi Apple ekibini seç (repo'da ekip numarası boş bırakıldı).
3. `Info.plist` içindeki `GADApplicationIdentifier` Google'ın örnek (test) AdMob kimliğidir; yayın için kendi kimliğinle değiştir.
