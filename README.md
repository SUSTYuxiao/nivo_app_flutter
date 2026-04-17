# Nivo App

会议纪要助手 — 实时语音转录 + AI 生成会议纪要。

## 技术栈

- Flutter 3.29+, Dart 3.7+
- Provider 状态管理
- Supabase Auth 认证
- dio HTTP 客户端
- sherpa_onnx 端侧语音识别
- record 跨平台录音

## 目标平台

- Android
- iOS

## 功能

- 登录（Supabase 邮箱认证）
- 会议录制（实时语音转录，支持云端/端侧 ASR 切换）
- AI 会议纪要生成（对接 meetAgHK 后端）
- 历史记录（分页、筛选、详情、删除）
- 设置（ASR 模式切换、模型下载管理、API 配置）

## 项目结构

```
lib/
├── main.dart                 # 入口 + Provider 注册
├── app.dart                  # MaterialApp + 底部导航 + 认证路由
├── core/
│   ├── constants.dart        # 颜色、URL、枚举
│   ├── theme.dart            # Material 3 主题
│   ├── models/               # 数据模型
│   └── services/             # 共享服务（API、Auth、Audio、ASR）
├── features/
│   ├── login/                # 登录
│   ├── meeting/              # 会议（准备→录制→结果）
│   ├── history/              # 历史记录
│   └── settings/             # 设置
└── shared/widgets/           # 通用组件
```

## 开发

```bash
flutter pub get
```

Supabase 配置通过编译时环境变量传入：

```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=your-key
```

## 模拟器运行

Android 模拟器：

```bash
# 列出可用设备
flutter devices

# 启动 Android 模拟器（需要先在 Android Studio 中创建 AVD）
flutter emulators --launch <emulator_id>

# 在模拟器上运行
flutter run -d <device_id>
```

iOS 模拟器（仅 macOS）：

```bash
# 打开 iOS 模拟器
open -a Simulator

# 在模拟器上运行
flutter run -d <device_id>
```

注意：麦克风录音功能在模拟器上不可用，需要真机测试。

## 构建

Android APK：

```bash
# Debug 包
flutter build apk --debug

# Release 包
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-key

# 产物路径: build/app/outputs/flutter-apk/app-release.apk
```

Android App Bundle（上架 Google Play）：

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-key

# 产物路径: build/app/outputs/bundle/release/app-release.aab
```

iOS（仅 macOS）：

```bash
# 需要先配置签名: ios/Runner.xcworkspace → Signing & Capabilities
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-key

# 产物路径: build/ios/ipa/nivo_app.ipa
# 通过 Transporter 或 xcrun altool 上传到 App Store Connect
```

## 测试

```bash
flutter test
```

## 后端

对接 meetAgHK（Java + Spring Boot），API 基础地址：`https://www.nivowork.cn`
