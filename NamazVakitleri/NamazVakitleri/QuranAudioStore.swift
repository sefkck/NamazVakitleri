import Foundation
import Combine

/// Hafız sesini sure sure indirip telefonda saklar; indirilen sure internet
/// olmadan dinlenebilir. Dosyalar ayetin Kur'an genelindeki numarasıyla
/// (1...6236) "Application Support/QuranAudio/<no>.mp3" olarak tutulur ve
/// iCloud yedeğine dahil edilmez (gerektiğinde yeniden indirilebilir).
final class QuranAudioStore: ObservableObject {
    static let shared = QuranAudioStore()

    /// İndirilmekte olan surelerin ilerlemesi (0...1), sure numarasına göre.
    @Published private(set) var progress: [Int: Double] = [:]
    /// İndirmesi biten / silinen sureler değişince ekranlar yenilensin diye.
    @Published private(set) var revision = 0
    @Published var lastError: String?

    private var tasks: [Int: Task<Void, Never>] = [:]

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = base.appendingPathComponent("QuranAudio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return url
    }

    static func localURL(globalAyahNumber: Int) -> URL {
        folder.appendingPathComponent("\(globalAyahNumber).mp3")
    }

    static func hasLocal(_ globalAyahNumber: Int) -> Bool {
        FileManager.default.fileExists(atPath: localURL(globalAyahNumber: globalAyahNumber).path)
    }

    func isDownloaded(_ globalNumbers: [Int]) -> Bool {
        !globalNumbers.isEmpty && globalNumbers.allSatisfy(Self.hasLocal)
    }

    func isDownloading(surah: Int) -> Bool { progress[surah] != nil }

    /// Surenin bütün ayetlerini indirir (aynı anda 4 dosya). Var olanları atlar.
    func download(surah: Int, globalNumbers: [Int]) {
        guard tasks[surah] == nil else { return }
        lastError = nil
        progress[surah] = 0
        let missing = globalNumbers.filter { !Self.hasLocal($0) }
        let total = Double(globalNumbers.count)
        var done = Double(globalNumbers.count - missing.count)
        tasks[surah] = Task { [weak self] in
            var failed = false
            await withTaskGroup(of: Bool.self) { group in
                var iterator = missing.makeIterator()
                func addNext() -> Bool {
                    guard let n = iterator.next() else { return false }
                    group.addTask { await Self.fetch(n) }
                    return true
                }
                for _ in 0..<4 { if !addNext() { break } }
                for await ok in group {
                    if !ok { failed = true }
                    done += 1
                    let value = done / max(total, 1)
                    await MainActor.run { self?.progress[surah] = value }
                    if Task.isCancelled { group.cancelAll(); break }
                    _ = addNext()
                }
            }
            await MainActor.run {
                guard let self else { return }
                self.tasks[surah] = nil
                self.progress[surah] = nil
                self.revision += 1
                if failed {
                    self.lastError = LocalizationManager.shared.t("audio_download_error", fallback: "Bazı ayetler indirilemedi. İnternet bağlantını kontrol edip tekrar dene.")
                }
            }
        }
    }

    func cancel(surah: Int) {
        tasks[surah]?.cancel()
    }

    func delete(_ globalNumbers: [Int]) {
        for n in globalNumbers { try? FileManager.default.removeItem(at: Self.localURL(globalAyahNumber: n)) }
        revision += 1
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: Self.folder)
        revision += 1
    }

    /// İndirilen seslerin toplam boyutu (bayt).
    var totalBytes: Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    private static func fetch(_ n: Int) async -> Bool {
        guard let remote = RecitationPlayer.remoteURL(globalAyahNumber: n) else { return false }
        for attempt in 0..<2 {
            do {
                let (tmp, response) = try await URLSession.shared.download(from: remote)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                let dest = localURL(globalAyahNumber: n)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                return true
            } catch {
                if attempt == 0 { try? await Task.sleep(nanoseconds: 1_000_000_000) }
            }
        }
        return false
    }
}
