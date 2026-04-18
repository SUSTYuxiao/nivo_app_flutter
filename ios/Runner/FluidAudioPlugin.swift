import Foundation
import Flutter

/// Platform channel plugin for FluidAudio offline transcription with speaker diarization.
/// Currently a stub — real implementation requires FluidAudio SPM package.
/// Add via Xcode: Package Dependencies → https://github.com/FluidInference/FluidAudio
class FluidAudioPlugin: NSObject {
    static let channelName = "com.nivo/fluid_audio"

    private var methodChannel: FlutterMethodChannel?

    func register(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: FluidAudioPlugin.channelName, binaryMessenger: messenger)
        methodChannel?.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isModelReady":
            result(false)

        case "downloadModels":
            result(FlutterError(code: "NOT_AVAILABLE", message: "FluidAudio SDK 未集成，请在 Xcode 中添加 SPM 依赖", details: nil))

        case "transcribeWithDiarization":
            result(FlutterError(code: "NOT_AVAILABLE", message: "FluidAudio SDK 未集成，请在 Xcode 中添加 SPM 依赖", details: nil))

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
