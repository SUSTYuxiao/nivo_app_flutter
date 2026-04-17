# 实时转录架构参考

> 从 Tauri/React 旧版客户端提取，记录实时语音转录的完整流程和关键实现细节。

## 整体架构

```
┌─────────────┐     PCM 音频      ┌──────────────┐     SSE 事件      ┌─────────────┐
│  麦克风录音   │ ──────────────→  │   后端服务     │ ──────────────→  │   UI 展示    │
│  (客户端)    │   POST binary    │  /api/speech  │   转录结果       │  转录文本     │
└─────────────┘                   └──────────────┘                   └─────────────┘
```

### 流程概览

1. 客户端生成 `sessionId`（格式: `session_{timestamp}_{random}`）
2. 建立 SSE 长连接: `GET /api/speech/start?sessionId={sessionId}`
3. 等待 SSE 连接确认（`connected` 事件）
4. 开始麦克风录音，采集 PCM 音频
5. 每隔 1 秒将缓冲区音频重采样为 16kHz 并发送: `POST /api/speech/audio?sessionId={sessionId}`
6. 通过 SSE 接收 `partial`（中间结果）和 `final`（最终结果）事件
7. 停止时发送停止信号: `POST /api/speech/stop?sessionId={sessionId}`
8. 关闭 SSE 连接，释放录音资源

---

## 音频格式要求

后端接收的 PCM 音频格式：

| 参数 | 值 |
|------|-----|
| 采样率 | **16000 Hz (16kHz)** |
| 声道数 | **1 (单声道)** |
| 位深度 | **16-bit (Int16, little-endian)** |
| 编码 | **线性 PCM (raw)** |
| 传输格式 | `application/octet-stream` |

---

## 缓冲与发送策略

### 桌面端（Web Audio API）

1. 使用 `ScriptProcessorNode`（bufferSize=4096）采集 Float32 音频数据
2. 每次 `onaudioprocess` 回调将 Float32 chunk 推入 `pcmBuffer`
3. 每 **1000ms** 定时器触发 `flushPCMBuffer()`：
   - 合并所有 Float32 chunks
   - 如果实际采样率 ≠ 16kHz，执行线性插值重采样
   - 将 Float32 转换为 Int16 PCM（`convertFloat32ToPCM16`）
   - 通过 Tauri invoke 命令发送到后端
4. 停止录音时执行最后一次 flush

### 重采样算法

使用线性插值将源采样率（通常 44100Hz 或 48000Hz）转换到 16000Hz：

```
ratio = fromSampleRate / toSampleRate
outputLength = round(inputLength / ratio)

对每个输出样本 i:
  srcIndex = i * ratio
  output[i] = input[floor(srcIndex)] * (1-t) + input[ceil(srcIndex)] * t
  其中 t = srcIndex - floor(srcIndex)
```

### Float32 → Int16 转换

```
对每个样本 s (范围 [-1.0, 1.0]):
  if s < 0: int16 = s * 0x8000
  if s >= 0: int16 = s * 0x7FFF
```

---

## Android 与桌面端差异

### 桌面端架构

```
浏览器 Web Audio API (录音)
        ↓ Float32 PCM
前端 JS (重采样 + 转 Int16)
        ↓ Tauri invoke
Rust 后端 (HTTP POST 发送音频)

Rust 后端 (reqwest-eventsource SSE 接收)
        ↓ Tauri emit 事件
前端 JS (更新 UI)
```

- 录音: 浏览器 `navigator.mediaDevices.getUserMedia` + `ScriptProcessorNode`
- 音频发送: 通过 Tauri Rust 命令 `send_audio_data`（绕过 WebView 网络限制）
- SSE 接收: Tauri Rust 层使用 `reqwest-eventsource`，通过 Tauri 事件系统转发到前端
- SSE 事件名: `sse-connected`, `sse-transcription`, `sse-error`

### Android 端架构

```
Kotlin NativeSpeechService (整合 SSE + 录音 + 音频发送)
        ↓ CustomEvent
前端 JS (更新 UI)
```

- 录音 + SSE + 音频发送全部由 Kotlin 原生层 `NativeSpeechService` 处理
- SSE: 使用 `okhttp-eventsource 4.x` (`BackgroundEventSource`)
- 音频发送: OkHttp 异步 POST
- 原生层通过 `CustomEvent` 将 SSE 事件转发到 WebView JS 层
- JS 事件名: `sse-connected`, `sse-transcription`, `sse-error`, `native-audio-data`
- 原生层还会转发音频数据（Base64 编码的 PCM）供前端生成录音文件

### 关键差异总结

| 方面 | 桌面端 | Android |
|------|--------|---------|
| 录音 | Web Audio API | Android AudioRecord (原生) |
| 音频发送 | Tauri Rust invoke | OkHttp (原生) |
| SSE 连接 | Rust reqwest-eventsource | OkHttp BackgroundEventSource |
| 事件传递 | Tauri emit → listen | CustomEvent on window |
| 重采样 | JS 前端处理 | 原生层处理 |

---

## SSE 连接管理

### 连接生命周期

1. **创建**: 生成 sessionId → 注册事件监听 → 调用 `start_sse_connection` / `startTranscription`
2. **连接确认**: 收到 `sse-connected` 事件后才开始录音（桌面端）或确认连接成功
3. **运行中**: 持续接收 `partial` / `final` 事件
4. **停止**: 发送 stop 信号 → 关闭 SSE → 清理事件监听 → 释放录音资源
5. **超时**: 连接建立有 10 秒超时限制

### Rust SSE 实现要点

- HTTP 客户端禁用连接池（`pool_max_idle_per_host(0)`），避免 SSE 长连接复用问题
- 连接超时 30 秒
- 使用 `AtomicBool` 控制连接生命周期
- 全局 `SseManager` 通过 `Mutex` 管理单一活跃连接
- 新连接建立前自动停止旧连接

### Android SSE 实现要点

- SSE 专用 OkHttpClient: `readTimeout = 0`（无限等待，SSE 长连接必须）
- 普通 HTTP 客户端: `readTimeout = 60s`
- 使用 `BackgroundEventSource` 在后台线程处理 SSE
- `ConnectionErrorHandler` 返回 `PROCEED` 以自动重连

---

## 会话 ID 生成

```
session_{Date.now()}_{Math.random().toString(36).substring(2, 11)}
```

示例: `session_1706345678901_k3m8x2p1q`

---

## 录音文件生成

停止录音后，可从 `allPcmDataRef`（Float32Array 数组）生成 WAV 文件：
- 格式: WAV, 16kHz, 单声道
- 用途: 上传到后端进行离线转录或存档
