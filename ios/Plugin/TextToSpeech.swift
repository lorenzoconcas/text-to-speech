import AVFoundation
import Capacitor

enum QUEUE_STRATEGY: Int {
    case QUEUE_ADD = 1, QUEUE_FLUSH = 0
}

@objc public class TextToSpeech: NSObject, AVSpeechSynthesizerDelegate {
    let synthesizer = AVSpeechSynthesizer()
    var calls: [CAPPluginCall] = []
    let queue = DispatchQueue(label: "backgroundAudioSetup", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    private weak var plugin: TextToSpeechPlugin?

    override init() {
        super.init()
        self.synthesizer.delegate = self
        // set session in background to avoid UI hangs.
        queue.async {
            do {
                let avAudioSessionCategory: AVAudioSession.Category = .playback
                try AVAudioSession.sharedInstance().setCategory(avAudioSessionCategory, mode: .default, options: .duckOthers)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Error setting up AVAudioSession: \(error)")
            }
        }
    }

    init(plugin: TextToSpeechPlugin) {
        self.plugin = plugin
        super.init()
        self.synthesizer.delegate = self
        // set session in background to avoid UI hangs.
        queue.async {
            do {
                let avAudioSessionCategory: AVAudioSession.Category = .playback
                try AVAudioSession.sharedInstance().setCategory(avAudioSessionCategory, mode: .default, options: .duckOthers)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Error setting up AVAudioSession: \(error)")
            }
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        self.resolveCurrentCall()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    plugin?.notifyListeners("onDone", data: [:])   
        self.resolveCurrentCall()
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard let plugin = self.plugin else { return }
        
        let start = characterRange.location
        let end = characterRange.location + characterRange.length
        
        if let range = Range(characterRange, in: utterance.speechString) {
            let spokenWord = String(utterance.speechString[range])
            let ret = [
                "start": start,
                "end": end,
                "spokenWord": spokenWord
            ] as [String: Any]
            
            plugin.notifyListeners("onRangeStart", data: ret)
        }
    }

    @objc public func speak(_ text: String, _ lang: String, _ rate: Float, _ pitch: Float, _ category: String, _ volume: Float, _ voice: Int, _ queueStrategy: Int, _ call: CAPPluginCall) throws {
        if queueStrategy == QUEUE_STRATEGY.QUEUE_FLUSH.rawValue {
            self.synthesizer.stopSpeaking(at: .immediate)
        }
        self.calls.append(call)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
        utterance.rate = adjustRate(rate)
        utterance.pitchMultiplier = pitch
        utterance.volume = volume

        // Find the voice associated with the voice parameter if a voice specified.
        // If the specified voice is not available we will fall back to default voice rather than raising an error.
        if voice >= 0 {
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            if voice < allVoices.count {
                utterance.voice = allVoices[voice]
            }
        }

        synthesizer.speak(utterance)
    }

    @objc public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    @objc public func getSupportedLanguages() -> [String] {
        return Array(AVSpeechSynthesisVoice.speechVoices().map {
            return $0.language
        })
    }

    @objc public func isLanguageSupported(_ lang: String) -> Bool {
        let voice = AVSpeechSynthesisVoice(language: lang)
        return voice != nil
    }

    // Adjust rate for a closer match to other platform.
    @objc private func adjustRate(_ rate: Float) -> Float {
        let baseRate: Float = AVSpeechUtteranceDefaultSpeechRate
        if rate >= 1.0 {
            return (0.1 * rate) + (baseRate - 0.1)
        }
        return rate * baseRate
    }

    @objc private func resolveCurrentCall() {
        guard let call = calls.first else {
            return
        }
        call.resolve()
        calls.removeFirst()
    }
}
