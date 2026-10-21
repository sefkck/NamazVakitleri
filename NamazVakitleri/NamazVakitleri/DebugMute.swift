import Foundation

/// Simülatördeki test sürümü sessizdir: testler sırasında Mac'ten hafız sesi,
/// alarm ya da ses önizlemesi duyulmasın (kullanıcının isteği). Gerçek
/// telefonda ve App Store sürümünde hiçbir etkisi yoktur.
enum DebugMute {
    static var isOn: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
