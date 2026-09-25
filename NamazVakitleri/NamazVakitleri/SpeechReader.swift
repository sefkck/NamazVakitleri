import Foundation
import AVFoundation
import Foundation
import Combine
import AVFoundation

/// Cihazın yerleşik metin-okuma (text-to-speech) motoruyla Arapça
/// metni sesli okur. Harici ses dosyası/ağ gerektirmez, tamamen offline
/// çalışır. Profesyonel bir hafız kaydı değildir, telaffuz kütüphane
/// kalitesine göre değişebilir.
final class SpeechReader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, languageCode: String = "ar-SA") {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode) ?? AVSpeechSynthesisVoice(language: "ar")
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
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
