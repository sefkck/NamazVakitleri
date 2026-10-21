import Foundation
import Combine
import AVFoundation

/// Hafız sesiyle ayet ayet Kur'an okuma (Mişari Raşid el-Afasi).
/// Ses, Islamic Network (alquran.cloud) sunucusundan ayet ayet çalınır;
/// bir ayet bitince sıradakine geçilir ve ekrandaki ayet vurgulanır.
/// Ses dosyalarının telif hakkı okuyucuya aittir; ses asla ücretli yapılmaz,
/// kaynak Ayarlar > Hakkında > Kaynaklar'da belirtilir.
final class RecitationPlayer: ObservableObject {
    static let reciterName = "Mişari Raşid el-Afasi"

    /// Hafız adı seçili dilde.
    static var localizedReciterName: String {
        switch LocalizationManager.shared.language {
        case .turkish: return reciterName
        case .arabic: return "مشاري راشد العفاسي"
        case .english, .german: return "Mishary Rashid Alafasy"
        }
    }

    /// Ayetin Kur'an genelindeki sıra numarası (1...6236) için ses adresi.
    static func audioURL(globalAyahNumber: Int) -> URL? {
        guard (1...6236).contains(globalAyahNumber) else { return nil }
        return URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(globalAyahNumber).mp3")
    }

    /// Okunan ayetin sure içindeki sırası (0'dan başlar); okunmuyorsa nil.
    @Published private(set) var currentIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var ayahNumbers: [Int] = []
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    /// Kısa internet kesintilerinde aynı ayet bir kez daha denenir.
    private var retriedIndex: Int?

    deinit { stop() }

    /// `globalNumbers`: suredeki ayetlerin genel numaraları; `index`'ten başlar.
    func play(globalNumbers: [Int], from index: Int = 0) {
        guard globalNumbers.indices.contains(index) else { return }
        ayahNumbers = globalNumbers
        errorMessage = nil
        retriedIndex = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        playAyah(at: index)
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        guard player != nil else { return }
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        cleanupObservers()
        player = nil
        currentIndex = nil
        isPlaying = false
        isLoading = false
    }

    /// Sıradaki ayetin sırası; son ayetten sonra nil.
    static func nextIndex(after index: Int, count: Int) -> Int? {
        index + 1 < count ? index + 1 : nil
    }

    private func playAyah(at index: Int) {
        cleanupObservers()
        guard let url = Self.audioURL(globalAyahNumber: ayahNumbers[index]) else { stop(); return }
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        currentIndex = index
        isLoading = true

        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            if let next = Self.nextIndex(after: index, count: self.ayahNumbers.count) {
                self.playAyah(at: next)
            } else {
                self.stop()
            }
        }
        statusObserver = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                if self.retriedIndex != index {
                    // Bir kez daha dene (kısa kesinti olabilir).
                    self.retriedIndex = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        guard let self, self.currentIndex == index else { return }
                        self.playAyah(at: index)
                    }
                    return
                }
                self.stop()
                self.errorMessage = LocalizationManager.shared.t("recitation_error", fallback: "Ses yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.")
            }
        }
        timeControlObserver = newPlayer.observe(\.timeControlStatus) { [weak self] p, _ in
            DispatchQueue.main.async {
                self?.isLoading = p.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
        newPlayer.play()
        isPlaying = true
    }

    private func cleanupObservers() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        statusObserver = nil
        timeControlObserver = nil
    }
}
