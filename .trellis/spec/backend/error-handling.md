# 错误处理

> 客户端错误处理模式。

---

## API 错误处理

### ApiService 层

- 检查 `code == 200 || success == true`，不匹配则抛异常
- 异常消息优先取 `body['message'] ?? body['msg'] ?? body['error'] ?? 'unknown error'`
- Dio 异常由调用方 try-catch 处理

```dart
// 典型模式
try {
  final result = await _apiService!.chatRun(...);
} catch (e) {
  _errorMessage = '纪要生成失败: $e';
  _phase = MeetingPhase.result; // 仍然跳转，显示错误
}
```

### Provider 层

- 错误存入 `String? _errorMessage` 字段，通过 `notifyListeners()` 驱动 UI
- `null` 表示无错误，非 null 时 UI 展示错误提示
- 关键操作有 fallback 链：云转写失败 → 降级到实时文本 → 显示错误

```dart
// MeetingProvider 中的 fallback 模式
try {
  sentences = await _transcriptionService!.transcribeAudio(...);
  content = TranscriptionService.formatAsMarkdown(sentences);
} catch (e) {
  debugPrint('[MeetingProvider] cloud transcription failed, falling back: $e');
  content = _transcriptions.map((t) => t.text).join('\n');
}
```

---

## 日志

- 使用 `debugPrint('[ClassName] 描述: $detail')` 格式
- tag 用方括号包裹类名：`[MeetingProvider]`、`[ApiService]`
- 仅在 debug 模式输出（`debugPrint` 自动在 release 静默）

---

## iOS 原生层错误

- Platform Channel 调用必须 try-catch `PlatformException`
- `FlutterResult` 必须在主线程 `DispatchQueue.main.async` 中调用
- 原生错误通过 MethodChannel 回传到 Dart 层统一处理

---

## 禁止

- 不要吞掉异常后静默不处理（至少 `debugPrint`）
- 不要在 Model 或 Service 的 catch 中弹 UI（Toast/Dialog），那是 Provider/Page 的职责
- 不要用 `onError` 回调替代 try-catch——二者配合使用
