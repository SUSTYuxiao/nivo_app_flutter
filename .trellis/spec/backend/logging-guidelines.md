# 日志规范

> 客户端日志输出规范。

---

## 日志工具

- 使用 `debugPrint()` 而非 `print()`
- `debugPrint` 在 release 模式自动静默，`print` 不会
- 不引入额外日志框架

---

## 日志格式

```
[ClassName] 动作描述: $detail
```

示例：

```dart
debugPrint('[MeetingProvider] onAppPaused at $_backgroundEnteredAt');
debugPrint('[MeetingProvider] cloud transcription: ${sentences.length} sentences');
debugPrint('[ApiService] getStsToken response type: ${body.runtimeType}');
```

---

## 何时记录

| 场景 | 示例 |
|------|------|
| 异步操作开始/完成 | `[MeetingProvider] rebuilding ASR stream` |
| fallback 触发 | `[MeetingProvider] cloud transcription failed, falling back: $e` |
| 关键状态变更 | `[MeetingProvider] ASR stream rebuilt with session $_sessionId` |
| 外部数据解析异常 | `[ApiService] getStsToken response type: ${body.runtimeType}` |

---

## 禁止记录

- 用户 token / session 信息
- 完整请求/响应 body（可能含敏感数据）
- 高频回调中的日志（如每帧音频 PCM 回调），除非临时调试
