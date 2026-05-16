# 数据交互规范

> 本项目为 Flutter 客户端，不直接操作数据库。此文档描述客户端如何与后端 API 交互以及数据持久化模式。

---

## API 交互

### 基础配置

- Base URL: `https://www.nivowork.cn`（`lib/core/constants.dart` 中 `apiBaseUrl`）
- HTTP 客户端: Dio，封装在 `ApiService`（`lib/core/services/api_service.dart`）
- 认证: Bearer Token，通过 `ApiService.updateToken()` 更新
- 超时: 默认 30s，文件上传 60s，SSE 流式 5 分钟

### 响应解析模式

后端返回统一格式 `{code, message, data}`，**必须同时检查** `code == 200` 和 `success == true`：

```dart
final body = response.data;
if (body is Map && (body['code'] == 200 && body['success'] == true) && body['data'] is Map) {
  final data = body['data'] as Map;
  // ...
}
```

- `data` 字段可能是嵌套 JSON 字符串，需要二次 `jsonDecode`（见 `processAudioV2`、`chatRun`）
- 历史列表在 `data.list` 中，分页参数为 `current`/`pageSize`
- 时间字段为毫秒 Unix 时间戳

### 表单提交 vs JSON

- `POST /db/*` 系列用 `FormData.fromMap()`（表单提交）
- `POST /api/chat/*` 系列用 JSON body
- `GET` 请求用 `queryParameters`

---

## 本地持久化

- 使用 `SharedPreferences`（通过 `SettingsProvider` 统一管理）
- key 命名: snake_case，如 `asr_mode`、`use_nivo_transcription`、`dev_mode`
- 音频文件保存: `Documents/recordings/`，PCM 16kHz mono → WAV
- 本地 ASR 模型: sherpa_onnx 模型文件缓存

---

## 数据模型

### 模式

- 纯数据类，无业务逻辑
- 提供 `fromJson` 工厂构造函数
- 字段用 `required` 或 nullable
- 示例: `lib/core/models/history_item.dart`、`lib/core/models/transcription.dart`

```dart
class HistoryItem {
  final String id;
  final String title;
  // ...
  factory HistoryItem.fromJson(Map<String, dynamic> json) { ... }
}
```

### 禁止

- 不要在 Model 中放入网络请求或 UI 逻辑
- 不要用 `dynamic` 类型，明确使用 `Map<String, dynamic>` 或具体类型

---

## 常见问题

- `data` 字段嵌套 JSON 字符串需二次 parse，否则拿不到实际数据
- `chatRun` 的 `parameters.app_id` 必须是 `'1'`，顶层 `app_id/workflow_id` 为空字符串
- `addHistory` 的 `result` 需 `jsonEncode({'default': resultText})`，`input` 需 `jsonEncode({'Content':..., 'Industry':..., 'Output_type':...})`
- `file_picker` 用 `FileType.any` 而非 `FileType.audio`（后者缺权限会崩溃）
