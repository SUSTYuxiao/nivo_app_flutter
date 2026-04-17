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

## 依赖

```bash
# 安装依赖
flutter pub get

# 国内镜像（如果 pub get 慢）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get

# 查看过期依赖
flutter pub outdated
```

## 环境配置

Supabase 配置通过 `.env` 文件传入（已提交到 git，私有仓库）：

```bash
# .env 已包含真实配置，直接使用即可
# 如需覆盖，创建 .env.local（已 gitignore）
```

## 运行

```bash
# 查看已连接设备
flutter devices

# 在默认设备上运行
flutter run --dart-define-from-file=.env

# 指定安卓模拟器运行
flutter run --dart-define-from-file=.env -d emulator-5554

# 指定 iOS 设备运行
flutter run --dart-define-from-file=.env -d ios

# 热重载（运行中按 r），热重启（按 R）
```

## 模拟器

注意：麦克风录音和端侧 ASR 在模拟器上不可用，需要真机测试。

```bash
# 列出可用模拟器
flutter emulators

# 启动模拟器
flutter emulators --launch <emulator_id>

# 打开 iOS 模拟器（仅 macOS）
open -a Simulator

# 查看应用日志
adb logcat | grep flutter
```

## 构建

```bash
# 安卓 debug APK
flutter build apk --debug --dart-define-from-file=.env

# 安卓 release APK
flutter build apk --release --dart-define-from-file=.env

# 产物路径: build/app/outputs/flutter-apk/app-release.apk

# 安卓 App Bundle（上架 Google Play）
flutter build appbundle --release --dart-define-from-file=.env

# iOS（需要先配置签名: ios/Runner.xcworkspace → Signing & Capabilities）
flutter build ipa --release --dart-define-from-file=.env
```

## 安装到真机

```bash
# 通过 USB 安装
adb install build/app/outputs/flutter-apk/app-release.apk

# 无线安装（先 USB 连接一次）
adb tcpip 5555
adb connect <手机IP>:5555
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 测试

```bash
# 跑全部测试
flutter test

# 跑单个测试文件
flutter test test/features/meeting/meeting_provider_test.dart
```

## 平台生成

```bash
# 重新生成 iOS 和安卓平台目录（如果被删除）
flutter create . --org com.zhangpengxiao --platforms ios,android
```

## 后端

对接 meetAgHK（Java + Spring Boot），API 基础地址：`https://www.nivowork.cn`

详见 [docs/api-reference.md](docs/api-reference.md)
