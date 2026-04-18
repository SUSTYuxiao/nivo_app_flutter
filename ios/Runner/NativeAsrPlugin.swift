import Foundation
import Speech
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
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: channels, interleaved: true) else { return }

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
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
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

        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "文件不存在: \(filePath)", details: nil))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false

        if onDevice {
            if #available(iOS 13, *) {
                request.requiresOnDeviceRecognition = true
            }
        }

        recognizer.recognitionTask(with: request) { speechResult, error in
            if let error = error {
                NSLog("[NativeAsr] transcribeFile error: \(error.localizedDescription)")
                result(FlutterError(code: "TRANSCRIBE_ERROR", message: error.localizedDescription, details: nil))
                return
            }

            if let speechResult = speechResult, speechResult.isFinal {
                let text = speechResult.bestTranscription.formattedString
                NSLog("[NativeAsr] transcribeFile result: \(text.prefix(100))...")
                result(text)
            }
        }
    }

    // MARK: - FlutterStreamHandler

    /// Configure audio session mode to control system voice processing.
    /// Note: iOS Voice Isolation is a system-level Control Center feature and cannot
    /// be toggled programmatically. This controls AVAudioSession mode instead.
    /// enabled = voiceChat mode (system voice processing, echo cancellation)
    /// disabled = measurement mode (raw audio, captures all sounds including speakers)
    private func setVoiceIsolation(enabled: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            if enabled {
                try session.setCategory(.playAndRecord, mode: .voiceChat,
                                         options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                try session.setCategory(.playAndRecord, mode: .measurement,
                                         options: [.defaultToSpeaker, .allowBluetooth])
            }
            try session.setActive(true)
            NSLog("[NativeAsr] setVoiceIsolation: \(enabled), mode=\(session.mode.rawValue)")
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
