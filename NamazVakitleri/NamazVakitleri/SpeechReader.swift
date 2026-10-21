import Foundation
import Combine
import SwiftUI
import AVFoundation

/// Cihazın yerleşik metin-okuma (text-to-speech) motoruyla Arapça
/// metni sesli okur. Harici ses dosyası/ağ gerektirmez, tamamen offline
/// çalışır. Profesyonel bir hafız kaydı değildir, telaffuz kütüphane
/// kalitesine göre değişebilir.
final class SpeechReader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    /// Cihazda Arapça ses yüklü değilse true olur; ekran bir uyarı gösterir.
    @Published var missingVoice = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Cihazda yüklü bir Arapça ses (varsa önce ar-SA).
    private static func arabicVoice(preferred languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.first { $0.language == languageCode }
            ?? voices.first { $0.language.hasPrefix("ar") }
    }

    func speak(_ text: String, languageCode: String = "ar-SA") {
        stop()
        guard let voice = Self.arabicVoice(preferred: languageCode) else {
            // Arapça ses yoksa sistem metni Türkçe/İngilizce sesle bozuk
            // okuyordu; okumak yerine kullanıcıya nasıl yükleneceğini söyle.
            missingVoice = true
            return
        }
        // Sessiz modda da duyulsun (kullanıcı bilerek "Sesli Oku"ya bastı).
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.42
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

extension View {
    /// Arapça ses yüklü değilse gösterilen ortak uyarı.
    func missingArabicVoiceAlert(isPresented: Binding<Bool>) -> some View {
        let loc = LocalizationManager.shared
        return alert(loc.t("tts_missing_title", fallback: "Arapça ses yüklü değil"), isPresented: isPresented) {
            Button(loc.t("common_ok", fallback: "Tamam"), role: .cancel) {}
        } message: {
            Text(loc.t("tts_missing_body", fallback: "Sesli okuma için iPhone Ayarlar > Erişilebilirlik > Seslendirilen İçerik > Sesler bölümünden Arapça bir ses indir."))
        }
    }
}
