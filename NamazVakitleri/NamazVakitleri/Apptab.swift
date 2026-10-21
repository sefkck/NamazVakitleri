import Foundation

/// MainTabView'daki sekmelerin kimlikleri. Bildirime basıldığında hangi
/// sekmenin açılacağını belirtmek için NotificationManager tarafından da
/// kullanılır.
enum AppTab: Hashable {
    case home, zikirmatik, qibla, quran, more
}
