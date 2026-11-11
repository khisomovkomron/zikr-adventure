// ZikrFeedback.swift
// ZKR-52: вибрация и звук экрана «Зикр» — нативно, но по тем же правилам, что веб:
//  • vibrate(p) в index.html → мост "haptic": p ≥ 20 → medium, массив → success, иначе light
//    (onZikr: 25 на каждом 33-м, иначе 10; onUndo: 20; открытие главы: [15, 60, 15]);
//  • tapSound(): синус 660 Гц, 0,1 с, огибающая 0.0001 → 0.08 (10 мс) → 0.0001 (90 мс).
// Звук — только при settings.sound, вибрация — только при settings.haptics (решение Комрона 11.11.2026:
// тот же «бип», что в вебе).

import AVFoundation
import UIKit
import ZikrCore
import ZikrDomain

/// Что произошло на экране (onZikr / onUndo / открытие главы).
enum ZikrFeedbackEvent: Equatable {
    case tap(total: Int64)
    case undo
    case unlock
}

enum ZikrHapticStyle: Equatable {
    case light, medium, success
}

/// Чистое правило «что сыграть» — порт vibrate() / tapSound() (тестируется без устройства).
struct ZikrFeedbackPlan: Equatable {
    var haptic: ZikrHapticStyle?
    var playsSound: Bool

    static func make(_ event: ZikrFeedbackEvent, settings: AppSettings) -> ZikrFeedbackPlan {
        let style: ZikrHapticStyle
        let sound: Bool
        switch event {
        case .tap(let total):
            style = total % 33 == 0 ? .medium : .light // vibrate(25) / vibrate(10)
            sound = true
        case .undo:
            style = .medium // vibrate(20)
            sound = false
        case .unlock:
            style = .success // vibrate([15, 60, 15])
            sound = false
        }
        return ZikrFeedbackPlan(haptic: settings.haptics ? style : nil, playsSound: sound && settings.sound)
    }
}

@MainActor
protocol ZikrFeedbackPerforming: AnyObject {
    func perform(_ plan: ZikrFeedbackPlan)
}

@MainActor
final class ZikrFeedbackService: ZikrFeedbackPerforming {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    private let tone = TapTonePlayer()

    init() {
        light.prepare()
    }

    func perform(_ plan: ZikrFeedbackPlan) {
        switch plan.haptic {
        case .light:
            light.impactOccurred()
            light.prepare()
        case .medium:
            medium.impactOccurred()
        case .success:
            notification.notificationOccurred(.success)
        case nil:
            break
        }
        if plan.playsSound {
            tone.play()
        }
    }
}

/// Тот же «бип», что tapSound() в WebAudio: синус 660 Гц, 0,1 с, экспоненциальная огибающая.
/// Категория .ambient — как Web Audio в WKWebView: смешивается с музыкой и молчит при беззвучном режиме.
@MainActor
final class TapTonePlayer {
    static let frequency: Double = 660
    static let duration: Double = 0.1
    static let attack: Double = 0.01
    static let releaseEnd: Double = 0.09
    static let floor: Float = 0.0001
    static let peak: Float = 0.08
    /// Движок останавливается после паузы в нажатиях (не держит аудиосессию).
    static let idleStop: UInt64 = 10_000_000_000

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var buffer: AVAudioPCMBuffer?
    private var idleTask: Task<Void, Never>?
    private var isSessionConfigured = false

    func play() {
        do {
            try prepareIfNeeded()
            guard let engine, let player, let buffer else { return }
            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !player.isPlaying {
                player.play()
            }
            scheduleIdleStop()
        } catch {
            let nsError = error as NSError
            Log.zikr.error("tap tone failed (domain: \(nsError.domain, privacy: .public), code: \(nsError.code, privacy: .public))")
        }
    }

    private func prepareIfNeeded() throws {
        if !isSessionConfigured {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            isSessionConfigured = true
        }
        guard engine == nil else { return }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate > 0
            ? engine.outputNode.outputFormat(forBus: 0).sampleRate
            : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = Self.makeBuffer(format: format) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        self.engine = engine
        self.player = player
        self.buffer = buffer
    }

    private func scheduleIdleStop() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.idleStop)
            guard !Task.isCancelled, let self else { return }
            self.player?.stop()
            self.engine?.pause()
        }
    }

    /// Огибающая как exponentialRampToValueAtTime: v(t) = v0 · (v1 / v0)^((t − t0) / (t1 − t0)).
    nonisolated static func gain(at t: Double) -> Float {
        func ramp(_ v0: Float, _ v1: Float, _ t0: Double, _ t1: Double) -> Float {
            v0 * powf(v1 / v0, Float((t - t0) / (t1 - t0)))
        }
        if t <= 0 { return floor }
        if t < attack { return ramp(floor, peak, 0, attack) }
        if t < releaseEnd { return ramp(peak, floor, attack, releaseEnd) }
        return floor
    }

    nonisolated static func makeBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount((format.sampleRate * duration).rounded())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            channel[i] = gain(at: t) * Float(sin(2 * Double.pi * frequency * t))
        }
        return buffer
    }
}

/// Объявления VoiceOver (announce() в вебе: aria-live="polite").
@MainActor
protocol AccessibilityAnnouncing: AnyObject {
    func announce(_ message: String)
}

@MainActor
final class VoiceOverAnnouncer: AccessibilityAnnouncing {
    func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
