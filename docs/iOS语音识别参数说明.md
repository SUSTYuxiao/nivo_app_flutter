# iOS 语音识别参数说明

## voiceIsolation 原理

`voiceIsolation` 通过 `AVAudioEngine.inputNode.setVoiceProcessingEnabled()` 控制：

| 参数 | 对应功能 | 说明 |
|------|---------|------|
| echoCancel | AEC (Acoustic Echo Cancellation) | 消除扬声器回声 |
| autoGain | AGC (Automatic Gain Control) | 自动增益 + 噪声抑制 |

开启时，inputNode 启用 voice processing，过滤扬声器声音和环境噪声。

## AVAudioSession 配置

```
Category: .playAndRecord
Mode: .default
Options: [.defaultToSpeaker, .allowBluetooth]
```

固定配置，运行时不切换 category/mode。去噪通过 inputNode 级别控制。

## SFSpeechRecognizer 的回声识别限制

SFSpeechRecognizer 对回声音频（扬声器播放的声音被麦克风录到）识别能力有限：
- 本地模式（SFSpeechRecognizer）无法可靠识别扬声器回声
- 云端 ASR（Whisper 级别）能识别扬声器声音

因此"全局收音"功能强制使用 Nivo 云端转写（`useNivoTranscription = true`）。

## 参数保留说明

`echoCancel` 和 `autoGain` 参数在 `AudioService.startRecording()` 中保留：
- 全局收音模式下固定为 `false`（不做去噪，保留扬声器声音供云端识别）
- 未来如果本地 ASR 能力提升，可重新启用
