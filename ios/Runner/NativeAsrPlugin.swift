import Foundation
import Speech
import AVFoundation
import Flutter

/// Platform channel plugin that receives PCM audio data from Flutter (via record package)
/// and feeds it to iOS native SFSpeechRecognizer for real-time transcription.
class NativeAsrPlugin: NSObject, FlutterStreamHandler {
    static let channelName = "com.nivo/native_asr"
    static let eventChannelName = "com.nivo/native_asr/events"

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isStreaming = false
    private var pcmFormat: AVAudioFormat?
    /// Serial queue to protect recognitionRequest/Task access across threads.
    /// recognitionTask callback runs on arbitrary queue; feedAudio runs on main thread.
    private let asrQueue = DispatchQueue(label: "com.nivo.asr")
    /// Whether to use on-device recognition (cached for restarts)
    private var currentOnDevice = false

    func register(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: NativeAsrPlugin.channelName, binaryMessenger: messenger)
        methodChannel?.setMethodCallHandler(handle)

        eventChannel = FlutterEventChannel(name: NativeAsrPlugin.eventChannelName, binaryMessenger: messenger)
        eventChannel?.setStreamHandler(self)

        // Request speech recognition authorization on registration
        SFSpeechRecognizer.requestAuthorization { status in
            NSLog("[NativeAsr] authorization status: \(status.rawValue)")
        }

        // A2: Listen for AVAudioSession interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            NSLog("[NativeAsr] audio session interrupted")
        case .ended:
            NSLog("[NativeAsr] audio session interruption ended")
            // Reactivate audio session
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                NSLog("[NativeAsr] failed to reactivate audio session: \(error)")
            }
            // Restart recognition if we were streaming
            asrQueue.async { [weak self] in
                guard let self = self, self.isStreaming else { return }
                NSLog("[NativeAsr] restarting recognition after interruption")
                self.restartRecognitionTask()
            }
        @unknown default:
            break
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            let args = call.arguments as? [String: Any]
            let requireOnDevice = args?["onDevice"] as? Bool ?? false
            startRecognition(onDevice: requireOnDevice, result: result)
        case "feedAudio":
            if let data = call.arguments as? FlutterStandardTypedData {
                feedAudio(pcmData: data.data)
            }
            result(nil)
        case "stop":
            stopRecognition()
            result(nil)
        case "transcribeFile":
            if let args = call.arguments as? [String: Any],
               let filePath = args["filePath"] as? String {
                let onDevice = args["onDevice"] as? Bool ?? false
                transcribeFile(filePath: filePath, onDevice: onDevice, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "缺少 filePath 参数", details: nil))
            }
        case "setVoiceIsolation":
            let enabled = call.arguments as? Bool ?? false
            setVoiceIsolation(enabled: enabled)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startRecognition(onDevice: Bool, result: @escaping FlutterResult) {
        NSLog("[NativeAsr] startRecognition called, onDevice=\(onDevice)")
        currentOnDevice = onDevice

        // Ensure audio session is configured — unified .playAndRecord + .default
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                     options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            NSLog("[NativeAsr] audio session setup error: \(error)")
        }

        // Check authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            NSLog("[NativeAsr] not authorized, status=\(authStatus.rawValue)")
            result(FlutterError(code: "NOT_AUTHORIZED", message: "语音识别未授权", details: nil))
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            NSLog("[NativeAsr] recognizer unavailable")
            result(FlutterError(code: "UNAVAILABLE", message: "语音识别不可用", details: nil))
            return
        }

        asrQueue.sync {
            // Stop any existing task
            recognitionRequest?.endAudio()
            recognitionTask?.finish()
            recognitionTask = nil
            recognitionRequest = nil

            startRecognitionTask(recognizer: recognizer, onDevice: onDevice)
            isStreaming = true
        }

        NSLog("[NativeAsr] streaming started, eventSink=\(self.eventSink != nil)")
        result(nil)
    }

    /// Create a new recognition request + task. Must be called on asrQueue.
    private func startRecognitionTask(recognizer: SFSpeechRecognizer, onDevice: Bool) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        if onDevice {
            if #available(iOS 13, *) {
                request.requiresOnDeviceRecognition = true
            }
        }

        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] speechResult, error in
            guard let self = self else { return }
            // Guard: ignore callbacks from stale tasks (after restart replaced them)
            guard self.recognitionRequest === request else { return }

            if let speechResult = speechResult {
                let text = speechResult.bestTranscription.formattedString
                let isFinal = speechResult.isFinal
                NSLog("[NativeAsr] result: '\(text.prefix(50))...' isFinal=\(isFinal)")
                DispatchQueue.main.async {
                    self.eventSink?([
                        "text": text,
                        "isFinal": isFinal
                    ])
                }
            }

            if let error = error {
                NSLog("[NativeAsr] recognition error: \(error.localizedDescription)")
            }

            // A1: isFinal → auto-restart instead of stop
            if speechResult?.isFinal == true {
                self.asrQueue.async {
                    guard self.isStreaming, self.recognitionRequest === request else { return }
                    NSLog("[NativeAsr] isFinal received, auto-restarting recognition task")
                    self.restartRecognitionTask()
                }
            }
        }
    }

    /// Restart recognition task transparently. Must be called on asrQueue.
    private func restartRecognitionTask() {
        // End old request/task
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            NSLog("[NativeAsr] recognizer unavailable during restart, stopping")
            isStreaming = false
            return
        }

        startRecognitionTask(recognizer: recognizer, onDevice: currentOnDevice)
        NSLog("[NativeAsr] recognition task restarted")
    }

    /// Feed PCM 16-bit 16kHz mono data from record package.
    private func feedAudio(pcmData: Data) {
        asrQueue.async { [weak self] in
            guard let self = self, self.isStreaming, let request = self.recognitionRequest else { return }

            let sampleRate: Double = 16000
            let channels: UInt32 = 1

            // Cache format to avoid allocating on every chunk
            if self.pcmFormat == nil {
                self.pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: channels, interleaved: true)
            }
            guard let format = self.pcmFormat else { return }

            let frameCount = UInt32(pcmData.count) / (channels * 2)
            guard frameCount > 0 else { return }
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount

            pcmData.withUnsafeBytes { rawPtr in
                if let baseAddress = rawPtr.baseAddress {
                    memcpy(buffer.int16ChannelData![0], baseAddress, pcmData.count)
                }
            }

            request.append(buffer)
        }
    }

    private func stopRecognition() {
        asrQueue.sync {
            recognitionRequest?.endAudio()
            recognitionTask?.finish()
            recognitionTask = nil
            recognitionRequest = nil
            isStreaming = false
        }
        NSLog("[NativeAsr] stopped")
    }

    /// Transcribe an audio file offline using SFSpeechURLRecognitionRequest.
    private func transcribeFile(filePath: String, onDevice: Bool, result: @escaping FlutterResult) {
        NSLog("[NativeAsr] transcribeFile: \(filePath), onDevice=\(onDevice)")

        let authStatus = SFSpeechRecognizer.authorizationStatus()
        guard authStatus == .authorized else {
            result(FlutterError(code: "NOT_AUTHORIZED", message: "语音识别未授权", details: nil))
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            result(FlutterError(code: "UNAVAILABLE", message: "语音识别不可用", details: nil))
            return
        }

        let srcURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "文件不存在: \(filePath)", details: nil))
            return
        }

        // Copy file to Documents to avoid tmp/sandbox access issues
        let fm = FileManager.default
        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let transcribeDir = docsDir.appendingPathComponent("transcribe_tmp", isDirectory: true)
        try? fm.createDirectory(at: transcribeDir, withIntermediateDirectories: true)
        let copiedURL = transcribeDir.appendingPathComponent(UUID().uuidString + "." + srcURL.pathExtension)
        do {
            try fm.copyItem(at: srcURL, to: copiedURL)
            NSLog("[NativeAsr] copied to: \(copiedURL.path)")
        } catch {
            NSLog("[NativeAsr] copy failed: \(error.localizedDescription), using original")
            // Try original directly
            doTranscribe(fileURL: srcURL, recognizer: recognizer, onDevice: onDevice, cleanupURL: nil, fallbackSrcURL: nil, result: result)
            return
        }

        // Try transcribing the copied file directly (SFSpeech supports m4a/mp3/caf/wav natively)
        doTranscribe(fileURL: copiedURL, recognizer: recognizer, onDevice: onDevice, cleanupURL: copiedURL, fallbackSrcURL: srcURL, result: result)
    }

    private func doTranscribe(fileURL: URL, recognizer: SFSpeechRecognizer, onDevice: Bool, cleanupURL: URL?, fallbackSrcURL: URL?, result: @escaping FlutterResult) {
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false

        if onDevice {
            if #available(iOS 13, *) {
                request.requiresOnDeviceRecognition = true
            }
        }

        var hasReturned = false
        recognizer.recognitionTask(with: request) { [weak self] speechResult, error in
            guard !hasReturned else { return }

            if let speechResult = speechResult, speechResult.isFinal {
                hasReturned = true
                let text = speechResult.bestTranscription.formattedString
                NSLog("[NativeAsr] transcribeFile result (\(text.count) chars): \(text.prefix(100))...")
                DispatchQueue.main.async {
                    result(text)
                }
                if let url = cleanupURL { try? FileManager.default.removeItem(at: url) }
                return
            }

            if let error = error {
                hasReturned = true
                let nsError = error as NSError
                NSLog("[NativeAsr] transcribeFile error: \(nsError.domain) \(nsError.code) \(error.localizedDescription)")

                // If format-related error and we haven't tried WAV conversion yet, try converting
                if let fallbackSrc = fallbackSrcURL {
                    NSLog("[NativeAsr] attempting WAV conversion fallback...")
                    if let url = cleanupURL { try? FileManager.default.removeItem(at: url) }

                    let fm = FileManager.default
                    let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let wavURL = docsDir.appendingPathComponent("transcribe_tmp", isDirectory: true)
                        .appendingPathComponent(UUID().uuidString + ".wav")

                    DispatchQueue.global(qos: .userInitiated).async {
                        let success = self?.convertToWavSync(srcURL: fallbackSrc, destURL: wavURL) ?? false
                        DispatchQueue.main.async {
                            if success {
                                NSLog("[NativeAsr] WAV fallback: converted, retrying transcribe")
                                self?.doTranscribe(fileURL: wavURL, recognizer: recognizer, onDevice: onDevice, cleanupURL: wavURL, fallbackSrcURL: nil, result: result)
                            } else {
                                NSLog("[NativeAsr] WAV fallback: conversion failed")
                                result(FlutterError(code: "TRANSCRIBE_ERROR", message: error.localizedDescription, details: nil))
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "TRANSCRIBE_ERROR", message: error.localizedDescription, details: nil))
                    }
                    if let url = cleanupURL { try? FileManager.default.removeItem(at: url) }
                }
                return
            }
        }
    }

    /// Convert any audio file to 16kHz mono 16-bit WAV using AVAssetReader (no audio session interaction).
    private func convertToWavSync(srcURL: URL, destURL: URL) -> Bool {
        let asset = AVAsset(url: srcURL)

        guard let track = asset.tracks(withMediaType: .audio).first else {
            NSLog("[NativeAsr] convertToWav: no audio track found")
            return false
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        guard let reader = try? AVAssetReader(asset: asset) else {
            NSLog("[NativeAsr] convertToWav: failed to create AVAssetReader")
            return false
        }

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else {
            NSLog("[NativeAsr] convertToWav: reader failed to start: \(reader.error?.localizedDescription ?? "unknown")")
            return false
        }

        // Collect all PCM data
        var pcmData = Data()
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)
                data.withUnsafeMutableBytes { ptr in
                    if let baseAddress = ptr.baseAddress {
                        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
                    }
                }
                pcmData.append(data)
            }
        }

        guard reader.status == .completed, !pcmData.isEmpty else {
            NSLog("[NativeAsr] convertToWav: reader status=\(reader.status.rawValue), data=\(pcmData.count) bytes")
            return false
        }

        // Write WAV file
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let dataSize = UInt32(pcmData.count)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        var header = Data(capacity: 44)
        header.append(contentsOf: "RIFF".utf8)
        header.append(withUnsafeBytes(of: (36 + dataSize).littleEndian) { Data($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        header.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        header.append(contentsOf: "data".utf8)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        var wavData = header
        wavData.append(pcmData)

        do {
            try wavData.write(to: destURL)
            NSLog("[NativeAsr] convertToWav: done, \(wavData.count) bytes")
            return true
        } catch {
            NSLog("[NativeAsr] convertToWav: write error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - FlutterStreamHandler

    /// Voice processing is now controlled at AVAudioEngine inputNode level
    /// via record package's echoCancel/autoGain config, not at session level.
    /// This method only ensures the session is in the correct base state.
    private func setVoiceIsolation(enabled: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            // Always use .playAndRecord + .default — never change category at runtime
            try session.setCategory(.playAndRecord, mode: .default,
                                     options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            NSLog("[NativeAsr] setVoiceIsolation: \(enabled) (session unchanged, controlled via inputNode)")
        } catch {
            NSLog("[NativeAsr] setVoiceIsolation error: \(error)")
        }
    }

    // MARK: - FlutterStreamHandler (EventChannel)

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        NSLog("[NativeAsr] eventSink connected")
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NSLog("[NativeAsr] eventSink cancelled")
        eventSink = nil
        return nil
    }
}
