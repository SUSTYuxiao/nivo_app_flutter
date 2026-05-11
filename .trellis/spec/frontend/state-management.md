# 状态管理

> Provider + ChangeNotifier 状态管理模式。

---

## 架构

- 状态管理: `provider` 包 + `ChangeNotifier`
- 依赖注入: `main.dart` 中通过 `MultiProvider` 一次性注入所有 Provider
- Provider 分两类:
  - `Provider<T>.value` — 无状态 Service（如 ApiService、AudioService）
  - `ChangeNotifierProvider<T>.value` — 有状态 Provider（如 MeetingProvider、SettingsProvider）

---

## Provider 设计模式

### 标准结构

```dart
class MeetingProvider extends ChangeNotifier {
  // 1. 私有依赖（通过 init() 注入）
  AudioService? _audioService;
  ApiService? _apiService;

  // 2. 私有状态字段
  MeetingPhase _phase = MeetingPhase.idle;
  String? _errorMessage;

  // 3. 公开 getter（只读）
  MeetingPhase get phase => _phase;
  String? get errorMessage => _errorMessage;

  // 4. init() 方法（构造后注入依赖）
  void init({required AudioService audioService, ...}) {
    _audioService = audioService;
  }

  // 5. 状态变更方法（末尾调 notifyListeners()）
  Future<void> startMeeting() async {
    _phase = MeetingPhase.recording;
    notifyListeners();
  }
}
```

### 注入方式

```dart
// main.dart 中创建和注入
final meetingProvider = MeetingProvider()
  ..init(
    audioService: audioService,
    asrRouter: asrRouter,
    apiService: apiService,
  );

// MultiProvider
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: meetingProvider),
    Provider<ApiService>.value(value: apiService),
  ],
  child: NivoApp(...),
)
```

---

## 状态分类

| 类型 | 存放位置 | 示例 |
|------|----------|------|
| 全局状态 | ChangeNotifierProvider | MeetingProvider.phase、SettingsProvider.asrMode |
| 持久化配置 | SharedPreferences + SettingsProvider | asr_mode、dev_mode、use_streaming |
| 页面局部状态 | StatefulWidget State | _currentIndex（tab 选中）、表单输入 |
| 服务端数据 | Provider 内缓存 + refresh() | HistoryProvider.list、VipProvider.vipStatus |

---

## UI 层访问模式

```dart
// 读取状态（重建时获取最新值）
context.watch<MeetingProvider>().phase

// 调用方法（不监听重建）
context.read<MeetingProvider>().startMeeting()

// 仅读一次（不重建）
Provider.of<MeetingProvider>(context, listen: false)
```

---

## SSE 流式更新模式

```dart
final sb = StringBuffer();
var lastNotify = DateTime.now();

await for (final chunk in _apiService!.chatRunStream(...)) {
  sb.write(chunk);
  final now = DateTime.now();
  if (now.difference(lastNotify).inMilliseconds >= 100) {
    _meetingResult = sb.toString();
    lastNotify = now;
    notifyListeners();
  }
}
_meetingResult = sb.toString();
notifyListeners(); // 最终完整结果
```

---

## 禁止

- 不要在 Provider 中直接导入 `dart:ui` 或使用 `BuildContext`
- 不要在 `dispose()` 后调 `notifyListeners()`
- 不要在 `build()` 中创建 Provider 实例
- 不要用 `setState` 管理跨组件状态（应提升到 Provider）
