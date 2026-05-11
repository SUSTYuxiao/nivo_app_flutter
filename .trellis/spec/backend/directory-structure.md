# 目录结构

> 本项目为 Flutter 客户端，不包含后端服务代码。"Backend" 层指 Dart 端与远程 API 的交互层。

---

## 总览

```
lib/
├── main.dart                  # 入口：初始化所有 Service/Provider，挂 MultiProvider
├── app.dart                   # MaterialApp + _AuthGate + _MainShell（4 tab）
├── core/
│   ├── constants.dart         # 全局常量：颜色、API URL、枚举、行业/模板选项
│   ├── theme.dart             # ThemeData 构建函数
│   ├── models/                # 纯数据模型（fromJson 工厂，无逻辑）
│   └── services/              # 单例服务（非 Provider，通过构造函数注入）
│       ├── api_service.dart   # Dio 封装，所有 HTTP 调用
│       ├── auth_service.dart  # Supabase auth 封装
│       ├── audio_service.dart # record 包封装，PCM 采集 + WAV 写入
│       ├── oss_service.dart   # 阿里云 OSS STS 上传
│       ├── transcription_service.dart  # 转写编排（OSS → API → 格式化）
│       ├── duration_service.dart       # 云端转写计时计费
│       ├── vip_provider.dart           # VIP 状态 ChangeNotifier
│       ├── live_activity_service.dart  # iOS 灵动岛桥接
│       ├── fluid_audio_service.dart    # FluidAudio 说话人分离
│       └── asr/
│           ├── asr_backend.dart  # 抽象接口 AsrBackend
│           ├── asr_router.dart   # 路由层，按 mode+flag 选择后端
│           ├── cloud_asr.dart    # 云端 SSE 实时转写
│           ├── ios_asr.dart      # iOS SFSpeechRecognizer（MethodChannel）
│           ├── sherpa_asr.dart   # Android sherpa_onnx 离线转写
│           └── asr_models.dart   # 模型元数据定义
├── features/                  # 功能模块，每个模块独立目录
│   ├── meeting/               # 实时会议
│   │   ├── meeting_page.dart
│   │   ├── meeting_provider.dart
│   │   └── widgets/           # 页面级私有组件
│   │       ├── recording_panel.dart
│   │       └── result_panel.dart
│   ├── after_meet/            # 会后整理
│   ├── history/               # 历史记录
│   ├── settings/              # 设置
│   └── login/                 # 登录
├── shared/
│   └── widgets/               # 跨 feature 复用组件
│       ├── nivo_button.dart
│       ├── loading_overlay.dart
│       ├── skeleton.dart
│       ├── minutes_card.dart
│       └── ...
└── docs/                      # 项目文档（非代码）
```

---

## 新模块组织规则

- 每个 feature 目录包含：`<name>_page.dart`（页面）、`<name>_provider.dart`（状态）
- 页面级私有组件放 `features/<name>/widgets/`
- 跨 feature 复用的组件放 `shared/widgets/`
- 新 Service 放 `core/services/`，通过 `main.dart` 注入对应 Provider

---

## 命名规范

| 类型 | 规则 | 示例 |
|------|------|------|
| 文件名 | snake_case | `meeting_provider.dart` |
| 类名 | PascalCase | `MeetingProvider` |
| Provider 文件 | `<feature>_provider.dart` | `history_provider.dart` |
| 页面文件 | `<feature>_page.dart` | `meeting_page.dart` |
| Service 文件 | `<name>_service.dart` | `audio_service.dart` |
| 模型文件 | `<name>.dart` | `history_item.dart` |
| 枚举 | PascalCase | `MeetingPhase`, `AsrMode` |

---

## 参考示例

- 完整功能模块：`lib/features/meeting/`（含 Provider、Page、子 Widgets）
- Service 抽象+路由：`lib/core/services/asr/`（AsrBackend 接口 → AsrRouter 路由 → 3 个实现）
- 全局初始化注入：`lib/main.dart`（所有 Service/Provider 创建和注入链路）
