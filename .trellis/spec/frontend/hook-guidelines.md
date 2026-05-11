# 生命周期与副作用模式

> 本项目使用 Provider（非 React Hooks），此文档描述 Flutter 中对应的副作用处理模式。

---

## 生命周期管理

### App 生命周期

通过 `WidgetsBindingObserver` 监听前后台切换：

```dart
class _MainShellState extends State<_MainShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _meetingProvider.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _meetingProvider.onAppResumed();
    }
  }
}
```

### 异步初始化

Service 使用 `init()` 方法分离同步构造和异步初始化：

```dart
final settingsProvider = SettingsProvider();
await settingsProvider.init(); // SharedPreferences 异步加载
```

---

## 副作用模式

### 定时器

- 使用 `Timer.periodic` 驱动 UI 更新（如会议计时）
- **必须在 `dispose()` 中取消**: `_timer?.cancel()`
- iOS 后台 Timer 不可靠，用 `DateTime` 对比判断超时

### 流式数据

- SSE 流式用 `await for` 遍历 Dio ResponseStream
- 累积用 `StringBuffer` + 100ms 节流 `notifyListeners()`
- 首字到达后再切换页面 phase，避免白屏

### StreamSubscription

- 在 `initState` 中订阅，`dispose` 中取消
- 示例: `_authSub` 在 `_AuthGate` 中监听 auth 状态变化

---

## 禁止

- 不要在 `build()` 中启动 Timer 或 StreamSubscription
- 不要忘记在 `dispose()` 中取消 Timer/StreamSubscription
- 不要用 Dart Timer 做后台超时判断（iOS 后台不触发）
