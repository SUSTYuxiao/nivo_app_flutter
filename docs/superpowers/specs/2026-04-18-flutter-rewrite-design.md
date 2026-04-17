# Nivo App Flutter 重写设计文档

## 概述

将 nivo_app_tauri（Tauri + React + Rust）完全重写为 Flutter 应用。废弃现有代码，仅保留业务逻辑作为参考。UI 风格和架构深度参考 personal-wiki-app。

目标平台：Android + iOS。

## 技术栈

- Flutter >=3.29.0, Dart SDK ^3.7.0
- 状态管理：Provider
- HTTP：dio（支持 SSE 流式 + 拦截器）
- 认证：supabase_flutter
- 录音：record
- 端侧 ASR：sherpa_onnx
- Markdown 渲染：flutter_markdown
- 持久化：shared_preferences
- 文件路径：path_provider
- 日期：intl
- 路由：Navigator.push + MaterialPageRoute（无路由库）

## 项目结构

```
lib/
├── main.dart                       # Provider 注册 + 启动
├── app.dart                        # MaterialApp + BottomNav shell（3 tab）
├── core/
│   ├── constants.dart              # AppColors, API URLs, 行业/模板枚举
│   ├── theme.dart                  # Material 3 主题配置
│   ├── models/
│   │   ├── meeting.dart            # Meeting 数据模型
│   │   ├── transcription.dart      # 转录条目
│   │   └── history_item.dart       # 历史记录条目
│   └── services/
│       ├── api_service.dart        # meetAgHK 后端 HTTP 接口封装
│       ├── auth_service.dart       # Supabase Auth 封装
│       ├── audio_service.dart      # record 包录音管理
│       └── asr/
│           ├── asr_router.dart     # 云端/端侧统一接口 + 路由
│           ├── cloud_asr.dart      # SSE 实时转录（dio）
│           └── sherpa_asr.dart     # sherpa_onnx 端侧转录
├── features/
│   ├── login/
│   │   ├── login_page.dart
│   │   └── login_provider.dart
│   ├── meeting/
│   │   ├── meeting_page.dart       # 三阶段容器
│   │   ├── meeting_provider.dart   # 会议状态管理
│   │   └── widgets/
│   │       ├── prepare_panel.dart  # 行业/模板选择 + 发起会议
│   │       ├── recording_panel.dart # 录音 + 实时转录
│   │       └── result_panel.dart   # 纪要展示
│   ├── history/
│   │   ├── history_page.dart       # 列表 + 筛选
│   │   ├── history_detail_page.dart # 详情 + 纪要渲染
│   │   └── history_provider.dart
│   └── settings/
│       ├── settings_page.dart      # 分组卡片设置
│       └── settings_provider.dart
└── shared/
    └── widgets/                    # 跨页面复用组件
        ├── status_card.dart
        └── loading_overlay.dart
```

核心原则：feature 目录组织页面和状态，共享的 services/models 放 core。只有真正只属于某个 feature 的 service 才放进 feature 目录。

## UI 设计系统

深度参考 personal-wiki-app 风格：

| Token | 值 |
|---|---|
| 主色 / Accent | #3A7BF7（蓝） |
| 背景色 | #F5F5F7（浅灰，iOS 风格） |
| 卡片背景 | #FFFFFF |
| 录音指示 | #FF3B30（红） |
| 成功 | #34C759（绿） |
| 警告 | #FF9500（橙） |
| 中性 | #8E8E93 |

- Material 3，colorSchemeSeed: #3A7BF7
- 卡片：白色，borderRadius: 16，elevation 0
- AppBar：透明，无阴影
- 底部导航：白色，高度 64，选中项蓝色
- 大标题：fontSize 32, fontWeight w700, letterSpacing -0.5
- 分组标签：fontSize 13-14, grey.shade400-500
- 间距：水平 20px，垂直 16-24px
- 按钮：GestureDetector + Container 圆角样式（非 ElevatedButton）
- 反馈：SnackBar floating + borderRadius 12

## ASR 路由架构

```dart
abstract class AsrBackend {
  Future<void> startStream({required Function(String text) onTranscription});
  Future<void> sendAudio(Uint8List pcmData);
  Future<void> stopStream();
}
```

`AsrRouter` 实现 `AsrBackend`，根据 `SettingsProvider.asrMode` 委托给 `CloudAsr` 或 `SherpaAsr`。

CloudAsr 流程：
1. GET /api/speech/start → 建立 SSE 连接
2. POST /api/speech/audio → 发送 PCM 音频块
3. SSE 事件回调转录文本
4. POST /api/speech/stop → 结束

SherpaAsr 流程：
1. 加载本地 sherpa_onnx 模型
2. 直接喂 PCM 数据到识别器
3. 回调返回转录结果

录音管道：record 采集 → PCM 16kHz 单声道 → AsrRouter.sendAudio() → 转录回调 → MeetingProvider 更新 UI

## 页面设计

### 登录页

- Logo + 应用名
- 邮箱 + 密码输入框（白色卡片，圆角）
- 蓝色主按钮登录 → Supabase signInWithPassword
- 登录成功 → checkSuperAdmin → 进入主页
- 内测阶段保留预填测试账号

### 会议页（三阶段）

MeetingProvider 管理状态流转：

```dart
enum MeetingPhase { prepare, recording, result }

class MeetingProvider extends ChangeNotifier {
  MeetingPhase phase = MeetingPhase.prepare;
  List<Transcription> transcriptions = [];
  String? meetingResult;
  String industry;
  String template;
  Duration elapsed;

  Future<void> startMeeting();   // → recording, 启动录音+ASR
  Future<void> endMeeting();     // → 停止录音, 上传, 生成纪要, result
  void reset();                  // → prepare
}
```

Phase 1 PreparePanel：行业选择 + 模板选择 + "发起会议"按钮
Phase 2 RecordingPanel：计时器 + 录音脉冲动画 + 实时转录滚动列表 + ASR 模式标签 + "结束会议"按钮
Phase 3 ResultPanel：flutter_markdown 渲染纪要 + 保存/返回操作

结束会议流程：停止录音 → 停止 ASR → 上传音频到 OSS → /a2t/process 离线转录 → /api/chat/run 生成纪要 → 显示结果

AssistantPanel（笔记/问题）暂不实现，等后端真正支持后再加。

### 历史记录页

- 大标题 "会议历史"
- 时间筛选 chips（今天 / 7天 / 30天）
- 白色卡片列表（标题 + 时间 + 行业标签）
- 下拉刷新 + 上拉加载更多
- 点击进入 HistoryDetailPage：元信息 + 纪要 markdown 渲染 + 改标题/删除

HistoryProvider 管理分页和筛选，调用 /db/getHistoryList。

### 设置页

分组卡片风格（参考 personal-wiki-app SettingsPage）：

- ASR 设置：模式切换 SegmentedButton（云端/本地）+ 本地模型下载卡片带进度条
- 云端 API 配置：Base URL 输入 + 连接测试按钮 + 状态指示
- 账户：当前用户信息 + 退出登录
- 关于：版本号

### 底部导航

3 个 tab：会议 / 历史 / 设置。现有项目的"我的"页面合并到设置页。

## 认证流程

```
app 启动 → Supabase.initialize → 检查 session
├── 有 session → checkSuperAdmin → 主页
└── 无 session → 登录页
```

AuthService 封装 Supabase Auth，LoginProvider 管理登录状态。token 通过 dio 拦截器自动注入到 meetAgHK 请求头。

## 数据流

```
用户操作 → Provider 方法调用 → Service 层（HTTP/本地）→ 更新 Provider 状态 → notifyListeners → UI 重建
```

Provider 之间不直接依赖。需要跨 Provider 数据时，通过 Service 层共享或在 Widget 层组合多个 Consumer。

## 不做的事情

- 不实现 AssistantPanel（后端未就绪）
- 不实现桌面端（仅 Android + iOS）
- 不引入路由库
- 不引入后台通知
- 不实现离线缓存（历史记录等依赖后端）
- 不实现 PostMeeting 流程（会后文本/文件上传，优先级低）
