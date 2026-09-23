//
//  OnboardAnnouncer.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import AVFoundation
import UIKit
import UserNotifications

@MainActor
final class OnboardAnnouncer: NSObject, AVSpeechSynthesizerDelegate {
    enum Urgency {
        case guidance
        case notice
        case critical
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpoken: (text: String, at: Date)?
    var voiceEnabled: Bool
    var alertSink: ((_ title: String, _ body: String?) -> Bool)?

    private nonisolated static let audioQueue = DispatchQueue(label: "ch.cclerc.lux.onboard.audio", qos: .userInitiated)

    init(voiceEnabled: Bool) {
        self.voiceEnabled = voiceEnabled
        super.init()
        synthesizer.delegate = self
        Self.audioQueue.async {
            try? AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
        }
    }

    func prepare() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func announce(_ text: String, notificationTitle: String? = nil, urgency: Urgency) {
        let isActive = UIApplication.shared.applicationState == .active

        switch urgency {
        case .guidance:
            break
        case .notice:
            if isActive { HapticFeedback.notification(type: .warning) }
        case .critical:
            if isActive {
                HapticFeedback.notification(type: .warning)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    HapticFeedback.notification(type: .warning)
                }
            }
        }

        if urgency != .guidance && !isActive,
           alertSink?(notificationTitle ?? text, notificationTitle == nil ? nil : text) != true {
            postNotification(title: notificationTitle ?? text, body: notificationTitle == nil ? nil : text, critical: urgency == .critical)
        }

        speak(text)
    }

    func speak(_ text: String) {
        guard voiceEnabled else { return }
        if let lastSpoken, lastSpoken.text == text, Date().timeIntervalSince(lastSpoken.at) < 20 { return }
        lastSpoken = (text, Date())

        Self.audioQueue.async { [weak self] in
            try? AVAudioSession.sharedInstance().setActive(true)
            Task { @MainActor in
                guard let self, self.voiceEnabled else { return }
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = Self.bestVoice
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.02
                self.synthesizer.speak(utterance)
            }
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        Self.deactivateAudioSession()
    }

    private nonisolated static func deactivateAudioSession() {
        audioQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static let bestVoice: AVSpeechSynthesisVoice? = {
        let language = voiceLanguage
        let prefix = String(language.prefix(2))
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
        func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
            let quality: Int
            switch voice.quality {
            case .premium: quality = 3
            case .enhanced: quality = 2
            default: quality = 1
            }
            let exactLanguage = voice.language == language ? 1 : 0
            let isNovelty = voice.voiceTraits.contains(.isNoveltyVoice) ? -10 : 0
            return quality * 10 + exactLanguage + isNovelty
        }
        return candidates.max { rank($0) < rank($1) } ?? AVSpeechSynthesisVoice(language: language)
    }()

    private static var voiceLanguage: String {
        let appLanguage = Bundle.main.preferredLocalizations.first ?? "fr"
        if appLanguage.hasPrefix("fr") { return "fr-FR" }
        return Locale.preferredLanguages.first { $0.hasPrefix(appLanguage) } ?? appLanguage
    }

    private func postNotification(title: String, body: String?, critical: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let body { content.body = body }
        content.sound = .default
        content.interruptionLevel = critical ? .timeSensitive : .active
        content.threadIdentifier = "onboard"
        let request = UNNotificationRequest(identifier: "onboard-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking else { return }
            Self.deactivateAudioSession()
        }
    }
}
