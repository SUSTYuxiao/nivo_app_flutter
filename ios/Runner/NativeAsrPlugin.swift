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

    func register(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: NativeAsrPlugin.channelName, binaryMessenger: messenger)
        methodChannel?.setMethodCallHandler(handle)

        eventChannel = FlutterEventChannel(name: NativeAsrPlugin.eventChannelName, binaryMessenger: messenger)
        eventChannel?.setStreamHandler(self)

        // Request speech recognition authorization on registration
        SFSpeechRecognizer.requestAuthorization { status in
            NSLog("[NativeAsr] authorization status: \(status.rawValue)")
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

        // Ensure audio session is configured — unified .playAndRecord + .default
        // Voice processing is controlled at AVAudioEngine inputNode level, not session level
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

        // Stop any existing task
        stopRecognition()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            result(FlutterError(code: "REQUEST_FAILED", message: "无法创建识别请求", details: nil))
            return
        }

        request.shouldReportPartialResults = true

        if onDevice {
            if #available(iOS 13, *) {
                request.requiresOnDeviceRecognition = true
            }
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] speechResult, error in
            guard let self = self else { return }

            if let speechResult = speechResult {
                let text = speechResult.bestTranscription.formattedString
                let isFinal = speechResult.isFinal
                NSLog("[NativeAsr] result: '\(text.prefix(50))...' isFinal=\(isFinal)")
                self.eventSink?([
                    "text": text,
                    "isFinal": isFinal
                ])
            }

            if let error = error {
                NSLog("[NativeAsr] error: \(error.localizedDescription)")
                // Don't stop on transient errors, only on final
            }

            // Only stop if the task itself reports final (system decided to end)
            if speechResult?.isFinal == true {
                NSLog("[NativeAsr] final result received, stopping")
                self.stopRecognition()
            }
        }

        isStreaming = true
        NSLog("[NativeAsr] streaming started, eventSink=\(self.eventSink != nil)")
        result(nil)
    }

    /// Feed PCM 16-bit 16kHz mono data from record package.
    private func feedAudio(pcmData: Data) {
        guard isStreaming, let request = recognitionRequest else { return }

        let sampleRate: Double = 16000
        let channels: UInt32 = 1

        // Cache format to avoid allocating on every chunk
        if pcmFormat == nil {
            pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: channels, interleaved: true)
        }
        guard let format = pcmFormat else { return }

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

    private func stopRecognition() {
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        isStreaming = false
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
                result(text)
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
                    result(FlutterError(code: "TRANSCRIBE_ERROR", message: error.localizedDescription, details: nil))
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
