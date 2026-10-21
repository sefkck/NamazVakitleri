#if DEBUG
import UIKit

/// Sadece DEBUG: gerçek iPhone'da ekranın resmini almak için.
/// -uiSnapshot <ad> ile açılınca 7 sn sonra ekranı Documents/snap_<ad>.png
/// olarak kaydeder. Mac bu dosyayı devicectl ile kopyalar.
enum DebugSnapshot {
    static func scheduleIfRequested() {
        guard let name = UserDefaults.standard.string(forKey: "uiSnapshot"), !name.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
                  let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let image = renderer.image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try? image.pngData()?.write(to: dir.appendingPathComponent("snap_\(name).png"))
            print("SNAPSHOT saved snap_\(name).png")
        }
    }
}
#endif
