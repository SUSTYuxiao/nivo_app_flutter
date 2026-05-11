# 质量规范

> Flutter 前端代码质量标准。

---

## 禁止模式

| 模式 | 原因 |
|------|------|
| Widget build() 中创建 Provider | 应在 main.dart 或上层注入 |
| build() 中启动 Timer/Stream | 应在 initState 中启动，dispose 中取消 |
| 硬编码颜色字符串 | 用 AppColors 常量 |
| 直接在 Widget 中做 HTTP 请求 | 通过 Provider → Service 链路 |
| dispose() 后调 notifyListeners() | 检查 `mounted` 或 `_isDisposed` |
| setState 跨组件共享状态 | 应提升到 ChangeNotifier |
| print() 输出日志 | 用 debugPrint()（release 自动静默） |

---

## 必须遵守

### dispose 清理

```dart
@override
void dispose() {
  _timer?.cancel();
  _authSub.cancel();
  super.dispose();
}
```

### Stream 流式更新节流

```dart
var lastNotify = DateTime.now();
if (now.difference(lastNotify).inMilliseconds >= 100) {
  notifyListeners();
  lastNotify = now;
}
```

### 列表只读暴露

```dart
List<Transcription> get transcriptions => List.unmodifiable(_transcriptions);
```

---

## 测试要求

- 目录结构与 lib/ 对齐
- Provider 测试: mockito mock 依赖 Service，测试状态变更逻辑
- Widget 测试: 包裹 `MultiProvider` + `MaterialApp`
- Mock 数据必须匹配实际 API 返回结构

---

## UI 检查清单

1. 所有异步操作是否有 loading 状态和错误状态
2. 长列表是否用 ListView.builder（而非 Column）
3. 键盘弹出时内容是否可滚动（ResizeToAvoidBottomInset）
4. 空状态是否有占位提示
5. 暗色/亮色模式兼容性（当前仅 light）
6. 横屏/大屏适配（如需要）
