# ASR 架构设计

## 概述

Nivo App 支持两种 ASR 模式：**自动**和**本地**。

- 自动模式：使用云端 SSE 实时转录（meetAgHK 后端）
- 本地模式：iOS 使用 SFSpeechRecognizer（系统自带），Android 使用 sherpa_onnx

## 音频管道

```
record 包采集 PCM 16kHz 单声道
  │
  ├─→ AudioService 保存 WAV 文件到 Documents/recordings/
  │
  └─→ AsrRouter.sendAudio(pcmData)
        │
        ├─ 自动模式 → CloudAsr → POST /api/speech/audio（SSE 返回转录）
        │
        └─ 本地模式
             ├─ iOS → IosAsr（Platform Channel → SFSpeechRecognizer）
             └─ Android → SherpaAsr（sherpa_onnx 端侧模型）
```

## 关键设计决策

### 为什么不用 speech_to_text 包？

`speech_to_text` 和 `record` 在 iOS 上会冲突：
- 两个包都创建自己的 `AVAudioEngine`
- 都在 `inputNode` bus 0 上 `installTap`
- iOS 同一个 bus 只允许一个 tap，导致崩溃

### Platform Channel 方案

iOS 本地模式采用自定义 Platform Channel（`NativeAsrPlugin.swift`）：

1. `record` 包独占 `AVAudioSession`，采集 PCM stream
2. PCM 数据通过 `MethodChannel` 传给 native 端
3. Native 端将 PCM 转为 `AVAudioPCMBuffer`，喂给 `SFSpeechAudioBufferRecognitionRequest`
4. 识别结果通过 `EventChannel` 流式返回 Flutter

好处：
- 只有一个 audio session owner（record 包），无冲突
- 录音保存和语音识别同时进行
- SFSpeechRecognizer 自动处理在线/离线切换

### iOS SFSpeechRecognizer 特性

- 有网时自动用 Apple 服务器（准确率更高）
- 无网时自动降级到设备端模型（iOS 17+ 中文模型质量好）
- 本地模式通过 `requiresOnDeviceRecognition = true` 强制离线
- 支持 partial/final 结果回调

## 文件清单

| 文件 | 说明 |
|------|------|
| `lib/core/services/asr/asr_backend.dart` | AsrBackend 抽象接口 |
| `lib/core/services/asr/asr_router.dart` | 路由：根据模式和平台选择后端 |
| `lib/core/services/asr/cloud_asr.dart` | 云端 SSE 实时转录 |
| `lib/core/services/asr/ios_asr.dart` | iOS Platform Channel → SFSpeechRecognizer |
| `lib/core/services/asr/sherpa_asr.dart` | Android sherpa_onnx 端侧转录 |
| `lib/core/services/audio_service.dart` | record 包录音 + WAV 文件保存 |
| `ios/Runner/NativeAsrPlugin.swift` | iOS 原生 SFSpeechRecognizer 插件 |

## 转录文本更新逻辑

- partial 结果：原地更新最后一条（避免每个字新增一行）
- final 结果：确认当前行，后续新文本新增一行
- 云端 SSE 通过 `event: partial` / `event: final` 区分
- iOS SFSpeechRecognizer 通过 `result.isFinal` 区分

## AfterMeet 离线转写

AfterMeet 提交时，先对选中的音频文件做离线转写，再拼接文本调用 chatRun：

```
音频文件 → IosAsr.transcribeFile() → SFSpeechURLRecognitionRequest → 文本
用户输入文本 + 转写文本 → chatRun → 纪要结果
```

- iOS: 通过 Platform Channel 调用 `SFSpeechURLRecognitionRequest`
- Android: TODO（sherpa_onnx 离线转写）

## iOS 权限

`Info.plist` 需要：
- `NSMicrophoneUsageDescription` — 麦克风录音
- `NSSpeechRecognitionUsageDescription` — 语音识别

## InMeet 生命周期

### startMeeting 流程

```
1. 如果全局收音 ON:
   a. durationService.fetchConfig(userId)  ← 拉取远端时长配置
   b. 检查 isLimitReached → 超限则阻止
   c. durationService.startSegment()       ← 开始段计时 + 60s 周期上报
2. asrRouter.startStream()                 ← 启动 ASR（全局收音时走云端）
3. audioService.startRecording(echoCancel: false, autoGain: false)
   └→ onAudioData → asrRouter.sendAudio()  ← PCM 喂给 ASR
```

### endMeeting 流程

```
1. timer.cancel()
2. audioService.stopRecording()  ← 停止录音，保存 WAV 文件，返回路径
3. asrRouter.stopStream()        ← 停止 ASR
4. chatRun(transcript)           ← 生成纪要
5. phase → result
```

### reset 流程（放弃会议）

```
1. timer.cancel()
2. audioService.stopRecording()  ← 必须停止录音
3. asrRouter.stopStream()        ← 必须停止 ASR
4. 清除所有状态（transcriptions, result, elapsed 等）
5. phase → idle
```

重要：reset 必须停止录音和 ASR，否则下次 startMeeting 会出现残留状态。

### pauseTimer / resumeTimer

- 点击"结束会议"时暂停计时器
- 用户取消弹窗时恢复计时器
- 录音和 ASR 不暂停（只暂停计时器显示）

## iOS AVAudioSession 配置

### 核心原则

统一使用 `.playAndRecord` + `.default` mode，永远不在运行时切换 category/mode。
去噪通过 record 包的 `AVAudioEngine.inputNode.setVoiceProcessingEnabled()` 控制。

### 高精度去噪开关

> **已废弃**：高精度去噪开关已替换为"全局收音"模式。以下内容保留供参考。

| 状态 | record 包参数 | inputNode 行为 | 效果 |
|------|-------------|---------------|------|
| 关闭（默认） | `echoCancel: false, autoGain: false` | voice processing OFF | 录到所有声音，包括扬声器 |
| 开启 | `echoCancel: true, autoGain: true` | voice processing ON (AEC+AGC+NS) | 过滤杂音和扬声器声音 |

### 全局收音模式（新）

全局收音开关替代了高精度去噪，作为 VIP 会员功能：

| 状态 | useNivoTranscription | echoCancel | autoGain | 效果 |
|------|---------------------|------------|----------|------|
| 关闭（默认） | false | false | false | 本地 ASR，不做去噪 |
| 开启 | true | false | false | 云端转写，保留扬声器声音供 Whisper 识别 |

开启全局收音时：
- 强制使用 Nivo 云端转写（Whisper 级别 ASR，能识别扬声器回声）
- 关闭 echoCancel/autoGain（保留扬声器声音）
- 启动 DurationService 计费（段时长 + 60s 周期上报）
- 非 VIP 用户无法开启，弹窗引导至 ChargePage

### 为什么不用 session 级别切换？

之前尝试过的方案及问题：
- `.record` + `.measurement`：禁用所有 DSP，但 `listInputDevices()` 会覆盖为 `.playAndRecord`
- `.playAndRecord` + `.voiceChat`：强制 AEC，运行时切换 mode 会导致 AVAudioEngine tap 格式失效
- `setPrefersEchoCancelledInput(false)`：仅 iOS 18.2+ 特定硬件有效

最终方案：session 配置固定不变，通过 inputNode 级别的 `setVoiceProcessingEnabled` 开关控制。
record 包的 `RecordConfig(echoCancel, autoGain)` 直接映射到这个开关。

### 关键约束

- 去噪开关只在录音开始前生效（通过 `RecordConfig` 传入）
- 录音中不切换 AVAudioSession category/mode
- record 包 `manageAudioSession=false`（默认），不会覆盖 session
- 但 `listInputDevices()` 会无条件设 `.playAndRecord`（已知风险，当前不调用）

## 后端 API 响应格式注意

- 历史 API：`{success: true, data: {list: [...]}}`
- chatRun API（Coze 转发）：`{code: 0, msg: "Success", data: "{\"data\": \"...\"}"}`
  - 成功码是 `code: 0`，不是 `200`
  - `data` 是嵌套 JSON 字符串，需要二次 parse
  - 错误信息字段是 `msg`，不是 `message`
- 必须同时检查 `code==0`、`code==200`、`success==true` 三种格式
