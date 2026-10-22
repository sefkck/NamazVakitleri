import Foundation
import Combine
import AVFoundation
import MediaPlayer

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

    /// Ayetin ses adresi: indirildiyse telefondaki dosya, yoksa internet.
    static func audioURL(globalAyahNumber: Int) -> URL? {
        guard (1...6236).contains(globalAyahNumber) else { return nil }
        if QuranAudioStore.hasLocal(globalAyahNumber) {
            return QuranAudioStore.localURL(globalAyahNumber: globalAyahNumber)
        }
        return remoteURL(globalAyahNumber: globalAyahNumber)
    }

    /// Ayetin Kur'an genelindeki sıra numarası (1...6236) için internet adresi.
    static func remoteURL(globalAyahNumber: Int) -> URL? {
        guard (1...6236).contains(globalAyahNumber) else { return nil }
        return URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(globalAyahNumber).mp3")
    }

    /// Kur'an sekmesinin ortak çaları: sure ekranından çıkınca da çalmaya devam eder,
    /// diğer sekmelerde mini çalar olarak görünür.
    static let shared = RecitationPlayer()

    /// Çalan içeriğin kimliği ("surah-36") ve ekranda görünen adı ("Yâsîn").
    @Published private(set) var sourceID: String?
    @Published private(set) var sourceTitle: String?

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
    func play(globalNumbers: [Int], from index: Int = 0, sourceID: String? = nil, title: String? = nil) {
        guard globalNumbers.indices.contains(index) else { return }
        self.sourceID = sourceID
        self.sourceTitle = title
        ayahNumbers = globalNumbers
        errorMessage = nil
        retriedIndex = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        setupRemoteCommands()
        playAyah(at: index)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard player != nil else { return }
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func skip(by offset: Int) {
        guard let i = currentIndex, ayahNumbers.indices.contains(i + offset) else { return }
        playAyah(at: i + offset)
    }

    // MARK: - Kilit ekranı / Denetim Merkezi / kulaklık düğmeleri

    private var remoteCommandsReady = false

    private func setupRemoteCommands() {
        guard !remoteCommandsReady else { return }
        remoteCommandsReady = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.isPlaying ? self.pause() : self.resume()
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.skip(by: 1); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.skip(by: -1); return .success }
    }

    /// Kilit ekranında "Yâsîn · 5. ayet · Mişari Raşid el-Afasi".
    private func updateNowPlaying() {
        guard let index = currentIndex else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        let loc = LocalizationManager.shared
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "\(sourceTitle ?? loc.t("tab_quran", fallback: "Kur'an")) · \(loc.tf("recitation_now", "%d. ayet okunuyor", index + 1))",
            MPMediaItemPropertyArtist: Self.localizedReciterName,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }

    func stop() {
        player?.pause()
        cleanupObservers()
        player = nil
        currentIndex = nil
        isPlaying = false
        isLoading = false
        sourceID = nil
        sourceTitle = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
        newPlayer.isMuted = DebugMute.isOn
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
        updateNowPlaying()
    }

    private func cleanupObservers() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        statusObserver = nil
        timeControlObserver = nil
    }
}
