# 类型安全

> Dart 类型系统使用规范。

---

## 类型组织

### 全局枚举和类型

定义在 `lib/core/constants.dart`：

```dart
enum MeetingPhase { idle, recording, result }
enum AsrMode { auto, local }
enum TranscribeMode { cloud, local }
enum TemplateMode { classic, scenario, custom }
enum ProcessingStage { idle, preparing, uploading, ... }
```

带 label 的枚举：

```dart
enum TemplateType {
  custom('自定义模板'),
  deep('深度纪要'),
  dialogue('对话式纪要');

  final String label;
  const TemplateType(this.label);
}
```

### 数据模型

放在 `lib/core/models/`，纯数据类 + `fromJson`：

```dart
class HistoryItem {
  final String id;
  final String title;
  final int createTime;
  final int? updateTime;  // nullable 表示可选字段

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',  // 安全转型 + 默认值
      createTime: json['createTime'] as int,
    );
  }
}
```

---

## API 响应类型安全

- 响应 `body` 先检查 `is Map`，再检查字段类型
- 列表字段: `body['data'] is List` 然后用 `.map((e) => Model.fromJson(e as Map<String, dynamic>))`
- 嵌套 JSON 字符串: 二次 `jsonDecode` 后再类型检查
- 所有 `as` 转型前必须有 `is` 检查或 `??` 默认值

---

## 空安全

- 优先使用 non-nullable (`String`、`int`)
- 可选字段用 nullable (`String?`、`int?`)
- Provider 依赖注入用 nullable + `init()` 延迟赋值
- 访问 nullable 前先检查: `if (_apiService != null) ...`

---

## 禁止

- 不要使用 `dynamic`，明确指定 `Map<String, dynamic>` 或具体类型
- 不要强制转型 `as String` 而不先 `is String` 检查
- 不要用 `!` 空断言（除非 100% 确定，如 `supabase.auth.currentUser!`）
- 不要在 Model 类中放入业务逻辑或网络请求
