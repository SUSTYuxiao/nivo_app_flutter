# 质量规范

> 代码质量、测试、提交流程标准。

---

## 禁止模式

| 模式 | 原因 |
|------|------|
| 在 `main()` 之前请求麦克风权限 | UI 未就绪会导致崩溃 |
| `speech_to_text` + `record` 同时使用 | iOS 上都创建 AVAudioEngine，同 bus 只允许一个 tap |
| `file_picker` 使用 `FileType.audio` | 缺权限会崩溃，必须用 `FileType.any` |
| Service 构造函数中做异步初始化 | 使用 `init()` 方法分离同步构造和异步初始化 |
| Provider 中直接弹 Toast/Dialog | 状态变更通过字段+notifyListeners，UI 层负责展示 |

---

## 必须遵守

- **提交前**: `flutter analyze` + `flutter test` 必须通过
- **Mock 数据**: 必须匹配实际 API 响应结构（`data.list` 嵌套、`code`+`success` 双检查）
- **Platform Channel**: iOS 原生回调必须在主线程 `DispatchQueue.main.async`
- **后台保活**: `UIBackgroundModes: audio` 保证锁屏录音不中断
- **Dart Timer 在 iOS 后台不可靠**: 用 `DateTime` 对比判断超时

---

## 测试要求

- 测试目录结构与 `lib/` 对齐: `test/core/services/`、`test/features/`
- Provider 测试用 `mockito` mock 依赖 Service
- Mock 必须覆盖实际 API 返回格式（嵌套 JSON、data.list 等）
- 现有测试文件：
  - `test/core/services/api_service_test.dart`
  - `test/core/services/asr/asr_router_test.dart`
  - `test/features/*/` 各 Provider 测试

---

## iOS 原生代码注意事项

- `Info.plist` 需要: `NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription`、`NSSupportsLiveActivities`、`UIBackgroundModes: [audio]`
- `MeetingActivityAttributes` 在 Runner 和 Widget Extension 中各定义一份（必须一致）
- 灵动岛 timer 用 `Text(startTime, style: .timer)` 系统自动计时

---

## 代码审查要点

1. API 响应解析是否同时检查 `code` 和 `success`
2. 异步操作是否有 try-catch + fallback
3. `dispose()` 中是否取消 Timer、StreamSubscription
4. 新增 Platform Channel 调用是否在主线程处理回调
5. Provider 是否正确调用了 `notifyListeners()`
