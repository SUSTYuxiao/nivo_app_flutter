# ASR 架构与转写链路

## 一、服务/模块清单

| 模块 | 文件路径 | 职责 | 依赖 |
|------|----------|------|------|
| AudioService | `lib/core/services/audio_service.dart` | 麦克风采集 PCM 16kHz mono，写 WAV 文件，提供 PCM 流回调 | `record` 包 |
| AsrBackend | `lib/core/services/asr/asr_backend.dart` | 抽象接口：`startStream` / `sendAudio` / `stopStream` | — |
| AsrRouter | `lib/core/services/asr/asr_router.dart` | 路由层，根据 mode + useNivoTranscription 选择具体后端 | CloudAsr, IosAsr, SherpaAsr |
| CloudAsr | `lib/core/services/asr/cloud_asr.dart` | 云端实时 SSE 转写，POST PCM → 服务端返回流式文本 | dio, `/api/speech/*` |
| IosAsr | `lib/core/services/asr/ios_asr.dart` | iOS 本地实时转写 + 离线文件转写，通过 MethodChannel 调用原生 | NativeAsrPlugin.swift |
| NativeAsrPlugin | `ios/Runner/NativeAsrPlugin.swift` | iOS 原生层，SFSpeechRecognizer 实时识别 + 文件识别 | Speech framework |
| SherpaAsr | `lib/core/services/asr/sherpa_asr.dart` | Android 本地离线转写，sherpa_onnx 模型，Isolate 批量转写 | `sherpa_onnx` 包 |
| AsrModelInfo | `lib/core/services/asr/asr_models.dart` | 本地模型元数据（paraformer-zh, qwen3-asr），下载地址/文件列表 | — |
| OssService | `lib/core/services/oss_service.dart` | 阿里云 OSS STS 签名上传音频文件 | ApiService, dio, `crypto` |
| TranscriptionService | `lib/core/services/transcription_service.dart` | 编排 OSS 上传 → processV2 云端转写 → 格式化 Markdown | OssService, ApiService |
| FluidAudioPlugin | `ios/Runner/FluidAudioPlugin.swift` [TODO] | iOS 本地离线转写 + 说话人分离（CoreML + Apple Neural Engine） | FluidAudio SDK (SPM) |
| DurationService | `lib/core/services/duration_service.dart` | 云端转写计时计费，每 60s 上报用量，超限自动停止 | ApiService |
| SettingsProvider | `lib/features/settings/settings_provider.dart` | 持久化 asrMode / transcribeMode / useNivoTranscription 等配置 | SharedPreferences |

---

## 二、实时转写（InMeet）

### 音频管道总览

```
┌──────────────┐
│  Microphone   │
└──────┬───────┘
       │ PCM 16kHz mono
       v
┌──────────────┐
│ AudioService  │──────────────────────────────┐
│  (record pkg) │                              │
└──────┬───────┘                              │
       │ onAudioData(pcmData)                  │ 写 WAV 文件
       v                                       v
┌──────────────┐                        ┌─────────────┐
│  AsrRouter    │                        │ Documents/   │
│  .sendAudio() │                        │ recordings/  │
└──────┬───────┘                        └─────────────┘
       │
       ├── globalCapture ON ──────> CloudAsr (SSE)
       │                              │
       ├── iOS + local ───────────> IosAsr (SFSpeechRecognizer)
       │                              │
       └── Android + local ───────> SherpaAsr (sherpa_onnx)
                                      │
                                      v
                               ┌─────────────┐
                               │ onTranscription│
                               │ (text, isFinal)│
                               └──────┬──────┘
                                      │
                                      v
                               ┌─────────────┐
                               │  UI 文本显示  │
                               └─────────────┘
```

### AsrRouter 路由决策

```
                    ┌─────────────────┐
                    │ useNivoTranscription │
                    │     == true?     │
                    └────┬───────┬────┘
                    yes  │       │ no
                         v       v
                  ┌──────────┐  ┌──────────────┐
                  │ CloudAsr │  │ Platform.isIOS?│
                  │  (SSE)   │  └───┬──────┬───┘
                  └──────────┘  yes │      │ no
                                    v      v
                             ┌────────┐ ┌──────────┐
                             │ IosAsr │ │ SherpaAsr│
                             └────────┘ └──────────┘
```

| AsrMode | useNivoTranscription | 平台 | 选择的后端 | 场景 |
|---------|---------------------|------|-----------|------|
| auto | true | any | CloudAsr | 全局收音开启 |
| auto | false | iOS | IosAsr | 默认 iOS 本地 |
| auto | false | Android | SherpaAsr | 默认 Android 本地 |
| local | any | iOS | IosAsr | 强制本地 |
| local | any | Android | SherpaAsr | 强制本地 |

> `globalCapture ON` 临时设置 `useNivoTranscription = true`，会议结束后恢复原值。

### 各后端能力对比

| 配置 | 后端 | 说话人分离 | 时间戳 | 平台 |
|------|------|-----------|--------|------|
| 全局收音 ON | CloudAsr SSE | 无 | 无 | iOS/Android |
| 全局收音 OFF | IosAsr | 无 | 无 | iOS only |
| 全局收音 OFF | SherpaAsr | 无 | 无 | Android only |

> 实时转写均不含说话人分离，仅提供流式文本。

### CloudAsr 详细流程

```
Flutter                          Server
  │                                │
  │  GET /speech/start?sid=xxx     │
  │ ─────────────────────────────> │
  │  <── SSE stream ──────────────│
  │                                │
  │  POST /speech/audio?sid=xxx    │
  │  [PCM binary]                  │
  │ ─────────────────────────────> │
  │                                │
  │  <── event: partial ──────────│
  │       {text, isFinal:false}    │
  │                                │
  │  POST /speech/audio            │
  │ ─────────────────────────────> │
  │                                │
  │  <── event: final ────────────│
  │       {text, isFinal:true}     │
  │                                │
  │  POST /speech/stop             │
  │ ─────────────────────────────> │
  │  <── stream closed ──────────│
```

### IosAsr 详细流程（Platform Channel）

```
Flutter (Dart)              iOS Native (Swift)
  │                              │
  │  MethodChannel 'start'       │
  │ ───────────────────────────> │ SFSpeechAudioBufferRecognitionRequest
  │                              │ recognitionTask(with: request)
  │                              │
  │  MethodChannel 'feedAudio'   │
  │  [PCM Uint8List]             │
  │ ───────────────────────────> │ Data → AVAudioPCMBuffer
  │                              │ request.append(buffer)
  │                              │
  │  <── EventChannel ──────────│ {text, isFinal}
  │                              │
  │  MethodChannel 'stop'        │
  │ ───────────────────────────> │ endAudio() + finish()
```

### SherpaAsr 流程

```
sendAudio()  sendAudio()  sendAudio()   stopStream()
    │            │            │              │
    v            v            v              v
┌────────────────────────────────┐    ┌──────────────┐
│     PCM Buffer (accumulate)    │───>│   Isolate    │
└────────────────────────────────┘    │  sherpa_onnx │
                                      │  transcribe  │
                                      └──────┬───────┘
                                             │
                                             v
                                      onTranscription(text, true)
```

### 转录文本更新逻辑

```
partial "你"     → [你]          (新增行)
partial "你好"   → [你好]        (原地更新)
partial "你好世" → [你好世]      (原地更新)
final   "你好世界" → [你好世界]  (标记 isFinal)
partial "下一"   → [你好世界, 下一]  (新增行)
```

---

## 三、离线转写（AfterMeet + EndMeeting）

### 云端转写流程

```
┌──────────┐     GET /oss/getStsToken     ┌──────────┐
│ 音频文件  │ ──────────────────────────> │  Server   │
│ (WAV)    │ <── {region,bucket,keys} ── │           │
└────┬─────┘                              └──────────┘
     │
     │  PUT (signed URL)
     v
┌──────────┐                              ┌──────────┐
│ 阿里 OSS  │                              │  Server   │
│ audio/   │                              │           │
│ ts_file  │                              │           │
└────┬─────┘                              └──────────┘
     │ ossKey                                  ^
     │                                         │
     │  GET /a2t/processV2?filePath=ossKey     │
     └────────────────────────────────────────>│
                                               │
     <── [{beginTime, endTime, text,      ────│
           speakerId, speakerName}, ...]
     │
     v
┌──────────────────────────────────┐
│ TranscriptionService             │
│ .formatAsMarkdown()              │
│                                  │
│ **发言人1 - 2分30秒**            │
│                                  │
│ 这是第一段发言内容                │
│                                  │
│ **发言人2 - 3分15秒**            │
│                                  │
│ 这是第二段发言内容                │
└──────────────────────────────────┘
     │
     v
  chatRun → 纪要
```

### 本地转写流程（iOS only — FluidAudio）

```
┌──────────┐   MethodChannel         ┌───────────────────────┐
│ 音频文件  │  'transcribeWithDiar'   │ FluidAudioPlugin.swift │
│ (m4a/wav)│ ────────────────────> │       [TODO]           │
└──────────┘                         │                       │
                                     │ FluidAudio SDK        │
                                     │ (CoreML + ANE)        │
                                     │                       │
                                     │ ASR + 说话人分离       │
                                     │ → [{beginTime,endTime, │
                                     │    text, speakerId,    │
                                     │    speakerName}, ...]  │
                                     └───────────┬───────────┘
                                                 │
                                                 v
                                     formatAsMarkdown()
                                                 │
                                                 v
                                           chatRun → 纪要
```

> FluidAudio 要求 iOS 17+，使用 CoreML + Apple Neural Engine 端侧推理。
> 说话人分离 DER ~13%（离线），模型 ~100MB。

### 链路选择

| 模式 | 后端 | 说话人分离 | 时间戳 | 平台 |
|------|------|-----------|--------|------|
| cloud | OSS + `/a2t/processV2` | 有 | 有 (ms) | iOS/Android |
| local | FluidAudio (CoreML) | 有 | 有 | iOS 17+ only |

### EndMeeting 决策流程

```
endMeeting()
  │
  ├── 有录音文件 && TranscriptionService != null?
  │     │
  │     ├── yes ──> 云端转写
  │     │             │
  │     │             ├── 成功 → speaker-labeled Markdown
  │     │             │
  │     │             └── 失败 → fallback 实时转录文本
  │     │
  │     └── no ───> 实时转录文本
  │
  v
chatRun(content) → 纪要
```

### AfterMeet 决策流程

```
submit(transcribeMode)
  │
  ├── transcribeMode == cloud && TranscriptionService != null?
  │     │
  │     ├── yes ──> TranscriptionService.transcribeAudio()
  │     │           → speaker-labeled Markdown
  │     │
  │     └── no ──> Platform.isIOS?
  │                  │
  │                  ├── yes → FluidAudio 本地转写 [TODO]
  │                  │         → speaker-labeled Markdown
  │                  │
  │                  └── no → (Android 无本地转写，固定走云端)
  │
  v
chatRun(content) → 纪要
```

---

## 四、InMeet 生命周期

### startMeeting

```
startMeeting()
  │
  ├── globalCapture ON?
  │     │
  │     ├── yes
  │     │     │
  │     │     ├── fetchConfig(userId)
  │     │     │     │
  │     │     │     └── isLimitReached? ──yes──> 阻止，提示升级
  │     │     │
  │     │     └── startSegment()  ← 开始计时 + 60s 上报
  │     │
  │     └── no → (跳过计费)
  │
  ├── asrRouter.startStream()  ← 启动 ASR
  │
  └── audioService.startRecording()
        └── onAudioData → asrRouter.sendAudio()
```

### endMeeting

```
endMeeting()
  │
  ├── timer.cancel()
  ├── durationService.endMeeting()  (if globalCapture)
  ├── audioService.stopRecording()  → WAV path
  ├── asrRouter.stopStream()
  │
  ├── [云端转写] → see "EndMeeting 决策流程"
  │
  ├── chatRun(content) → 纪要
  │
  └── phase → result
```

### reset（放弃会议）

```
reset()
  │
  ├── timer.cancel()
  ├── durationService.endMeeting()  (if globalCapture)
  ├── audioService.stopRecording()  ← 必须停止
  ├── asrRouter.stopStream()        ← 必须停止
  ├── 清除所有状态
  └── phase → idle
```

> reset 必须停止录音和 ASR，否则下次 startMeeting 会出现残留状态。

---

## 五、iOS 平台特有细节

### 为什么不用 speech_to_text 包？

```
speech_to_text                    record
      │                              │
      v                              v
┌──────────────┐            ┌──────────────┐
│ AVAudioEngine │            │ AVAudioEngine │
│  inputNode    │            │  inputNode    │
│  bus 0 tap    │            │  bus 0 tap    │
└──────────────┘            └──────────────┘
      │                              │
      └──────── CONFLICT! ──────────┘
         iOS 同一 bus 只允许一个 tap
```

### Platform Channel 方案

```
┌─────────────────────────────────────────────────┐
│                   Flutter                        │
│                                                  │
│  ┌────────────┐         ┌──────────────────┐    │
│  │ record pkg  │         │     IosAsr        │    │
│  │ (PCM采集)   │         │ (MethodChannel)   │    │
│  └──────┬─────┘         └────────┬─────────┘    │
│         │ PCM stream             │ feedAudio     │
│         │                        │               │
└─────────┼────────────────────────┼───────────────┘
          │                        │
          │    ┌───────────────────┘
          │    │
          v    v
┌─────────────────────────────────────────────────┐
│              iOS Native                          │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │         NativeAsrPlugin.swift             │   │
│  │                                           │   │
│  │  PCM → AVAudioPCMBuffer                   │   │
│  │       → SFSpeechAudioBufferRecognition    │   │
│  │       → {text, isFinal}                   │   │
│  │       → EventChannel → Flutter            │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  AVAudioSession: .playAndRecord + .default       │
│  (record 包独占，NativeAsrPlugin 不碰 session)    │
└─────────────────────────────────────────────────┘
```

### SFSpeechRecognizer 特性（仅用于实时流式转写）
- 有网时自动用 Apple 服务器（准确率更高）
- 无网时自动降级到设备端模型（iOS 17+ 中文模型质量好）
- 本地模式通过 `requiresOnDeviceRecognition = true` 强制离线
- 对扬声器回声识别能力有限 → 全局收音强制走云端
- 不用于离线文件转写（有 1 分钟时长限制，无说话人分离）

### FluidAudio（用于离线文件转写 + 说话人分离）[TODO]
- GitHub: https://github.com/FluidInference/FluidAudio
- 完全端侧推理，CoreML + Apple Neural Engine
- ASR: Parakeet TDT 模型，支持中文
- 说话人分离: ~13% DER（离线），pyannote segmentation + WeSpeaker embeddings
- 模型 ~100MB（说话人分离），ASR 模型 110M-600M
- iOS 17+ / macOS 14+ only
- 无 Android 支持
- 通过 Platform Channel 集成，返回与云端 processV2 一致的结构化数据

### AVAudioSession 配置

固定配置，运行时不切换：
```
Category: .playAndRecord
Mode: .default
Options: [.defaultToSpeaker, .allowBluetooth]
```

去噪通过 `AVAudioEngine.inputNode.setVoiceProcessingEnabled()` 控制。

| 状态 | echoCancel | autoGain | 效果 |
|------|------------|----------|------|
| 全局收音 ON | false | false | 保留扬声器声音供云端识别 |
| 全局收音 OFF | false | false | 本地 ASR，不做去噪 |

### 权限

`Info.plist` 需要：
- `NSMicrophoneUsageDescription` — 麦克风录音
- `NSSpeechRecognitionUsageDescription` — 语音识别

---

## 六、iOS vs Android 差异总表

| 能力 | iOS | Android |
|------|-----|---------|
| 实时转写（本地） | SFSpeechRecognizer | sherpa_onnx |
| 实时转写（云端） | CloudAsr SSE | CloudAsr SSE |
| 离线文件转写（本地） | FluidAudio (CoreML) [TODO] | 暂不支持 |
| 离线文件转写（云端） | OSS + processV2 | OSS + processV2 |
| 说话人分离（离线本地） | FluidAudio [TODO] | 暂不支持 |
| 说话人分离（离线云端） | processV2 | processV2 |
| 时间戳 | 云端 processV2 / FluidAudio [TODO] | 仅云端 processV2 |
| 设置页转写模式 | cloud / local（默认 local） | 固定 cloud |
| 实时转写本地模型 | 系统自带 (SFSpeech) | sherpa_onnx 需下载 |
| 离线转写本地模型 | FluidAudio ~100-600MB [TODO] | 无 |
| 原生插件 | NativeAsrPlugin + FluidAudioPlugin [TODO] | 无 |
| 音频会话 | AVAudioSession 固定配置 | record 包管理 |
| 麦克风权限 | NSMicrophoneUsageDescription | RECORD_AUDIO |
| 语音识别授权 | NSSpeechRecognitionUsageDescription | 无额外权限 |
| 最低系统版本（离线转写） | iOS 17+ (FluidAudio) | — |

```
                    ┌─────────────────────────────────┐
                    │          共享层 (Dart)            │
                    │                                  │
                    │  AudioService  AsrRouter          │
                    │  CloudAsr  OssService             │
                    │  TranscriptionService             │
                    │  DurationService                  │
                    └──────────┬──────────┬────────────┘
                               │          │
                 ┌─────────────┘          └──────────────┐
                 │                                       │
          ┌──────v──────┐                        ┌───────v──────┐
          │    iOS       │                        │   Android     │
          │              │                        │               │
          │ [实时]       │                        │ [实时]        │
          │ IosAsr       │                        │ SherpaAsr     │
          │ NativeAsr    │                        │ (sherpa_onnx) │
          │ Plugin.swift │                        │               │
          │ SFSpeech     │                        │ [离线]        │
          │ Recognizer   │                        │ 无本地方案     │
          │              │                        │ 固定走云端     │
          │ [离线]       │                        └───────────────┘
          │ FluidAudio   │
          │ Plugin [TODO]│
          │ ASR+说话人分离│
          └──────────────┘
```

---

## 七、本地 ASR 模型

| 模型 ID | 名称 | 大小 | 引擎 | 语言 | 来源 |
|---------|------|------|------|------|------|
| paraformer-zh | Paraformer 中文 | ~220MB | sherpa_onnx OfflineParaformer | 中文普通话 | hf-mirror.com |
| qwen3-asr | Qwen3-ASR | ~900MB | sherpa_onnx OfflineQwen3Asr | 28语言+中文方言 | modelscope.cn |

模型存储路径：`Documents/models/{modelId}/`，由 SherpaAsr 管理下载/删除。

---

## 八、数据流总览

```
╔══════════════════════════════════════════════════════════════╗
║                    InMeet (实时会议)                          ║
║                                                              ║
║  [实时]                                                      ║
║  Mic → AudioService → AsrRouter ─┬─> CloudAsr (SSE)         ║
║           │                      ├─> IosAsr (SFSpeech)      ║
║           │                      └─> SherpaAsr (sherpa_onnx) ║
║           │                              │                    ║
║           v                              v                    ║
║       WAV 文件                     流式文本 → UI              ║
║                                                              ║
║  [结束]                                                      ║
║  WAV ──> OssService ──> processV2 ──> Markdown ──> chatRun   ║
║                │                                     │       ║
║                └── 失败? ──> fallback 实时文本 ──────┘       ║
║                                                      │       ║
║                                                      v       ║
║                                              chatRunStream   ║
║                                              (SSE 流式输出)   ║
║                                                      │       ║
║                                                      v       ║
║                                                    纪要      ║
║                                                      │       ║
║                                                      v       ║
║                                              addHistory      ║
║                                              (自动保存历史)   ║
╚══════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════╗
║                   AfterMeet (会后整理)                        ║
║                                                              ║
║  录音文件 ─┬─[cloud]─> OssService ──> processV2              ║
║            │                            │                    ║
║            │                   Markdown (说话人+时间戳)       ║
║            │                            │                    ║
║            ├─[local]─> FluidAudio (iOS) [TODO]               ║
║            │                            │                    ║
║            │                   Markdown (说话人+时间戳)       ║
║            │                            │                    ║
║            └────────────────────────────v                    ║
║                                    chatRunStream → 纪要      ║
║                                         │                    ║
║                                         v                    ║
║                                    addHistory (自动保存)      ║
╚══════════════════════════════════════════════════════════════╝
```
