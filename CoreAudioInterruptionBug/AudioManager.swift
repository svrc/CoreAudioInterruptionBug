import AVFoundation
import Observation

/// Demonstrates that CoreAudio silently stops invoking the AudioUnit render callback
/// when a visionOS ImmersiveSpace is dismissed via Digital Crown, without firing
/// any error callback or AVAudioSession interruption notification with .shouldResume.
@Observable
final class AudioManager {
    private(set) var isPlaying = false
    private(set) var renderCallbackCount: UInt64 = 0
    private(set) var lastCallbackTime: Date?
    private(set) var callbackStoppedDetected = false
    private(set) var interruptionBegan = false
    private(set) var interruptionEndedWithResume = false
    private(set) var errorCallbackFired = false
    private(set) var statusLog: [String] = []

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var phase: Double = 0
    private var monitorTimer: Timer?

    init() {
        setupInterruptionObserver()
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        print(entry)
        Task { @MainActor in
            self.statusLog.append(entry)
            if self.statusLog.count > 100 {
                self.statusLog.removeFirst()
            }
        }
    }

    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                self.interruptionBegan = true
                self.log("AVAudioSession interruption BEGAN")
            case .ended:
                let options = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                self.interruptionEndedWithResume = shouldResume
                self.log("AVAudioSession interruption ENDED (shouldResume=\(shouldResume))")
            @unknown default:
                self.log("AVAudioSession interruption UNKNOWN type")
            }
        }
    }

    func startAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            let engine = AVAudioEngine()
            let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

            // Generate a 440Hz sine wave and count render callbacks
            let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, bufferList -> OSStatus in
                guard let self else { return noErr }

                self.renderCallbackCount += 1

                let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
                let frequency: Double = 440.0
                let amplitude: Float = 0.2

                for frame in 0..<Int(frameCount) {
                    let value = Float(sin(self.phase)) * amplitude
                    self.phase += 2.0 * .pi * frequency / sampleRate
                    if self.phase > 2.0 * .pi { self.phase -= 2.0 * .pi }

                    for buffer in ablPointer {
                        let buf = buffer.mData!.assumingMemoryBound(to: Float.self)
                        buf[frame] = value
                    }
                }

                return noErr
            }

            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
            try engine.start()

            self.audioEngine = engine
            self.sourceNode = sourceNode
            self.isPlaying = true
            self.callbackStoppedDetected = false
            self.interruptionBegan = false
            self.interruptionEndedWithResume = false
            self.errorCallbackFired = false
            self.renderCallbackCount = 0

            log("Audio engine started (sampleRate=\(sampleRate))")
            startMonitoring()
        } catch {
            log("Failed to start audio: \(error)")
        }
    }

    func stopAudio() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        audioEngine?.stop()
        if let sourceNode {
            audioEngine?.detach(sourceNode)
        }
        audioEngine = nil
        sourceNode = nil
        isPlaying = false
        log("Audio engine stopped")
    }

    func resetFlags() {
        callbackStoppedDetected = false
        interruptionBegan = false
        interruptionEndedWithResume = false
        errorCallbackFired = false
        statusLog.removeAll()
        log("Flags reset")
    }

    /// Monitors whether the render callback is still being invoked.
    /// If the count stops incrementing for 2 seconds, the callback has silently died.
    private func startMonitoring() {
        var lastCount: UInt64 = 0
        var staleChecks = 0

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }

            let currentCount = self.renderCallbackCount
            self.lastCallbackTime = Date()

            if currentCount == lastCount {
                staleChecks += 1
                if staleChecks >= 2 {
                    self.callbackStoppedDetected = true
                    self.log("RENDER CALLBACK STOPPED (count stuck at \(currentCount) for \(staleChecks)s)")
                }
            } else {
                if staleChecks >= 2 {
                    self.log("Render callback RESUMED (count now \(currentCount))")
                }
                staleChecks = 0
            }
            lastCount = currentCount
        }
    }
}
