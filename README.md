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
flutter run
```

## 测试

```bash
flutter test
```

## 后端

对接 meetAgHK（Java + Spring Boot），API 基础地址：`https://www.nivowork.cn`
