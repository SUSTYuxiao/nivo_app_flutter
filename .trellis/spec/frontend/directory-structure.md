# 目录结构

> Flutter 前端代码组织方式。

---

## 核心分层

```
lib/
├── core/           # 基础设施层：常量、主题、模型、服务
│   ├── constants.dart
│   ├── theme.dart
│   ├── models/
│   └── services/
├── features/       # 功能模块（每个模块独立目录）
│   ├── meeting/    # 实时会议
│   ├── after_meet/ # 会后整理
│   ├── history/    # 历史记录
│   ├── settings/   # 设置
│   └── login/      # 登录
├── shared/         # 跨 feature 复用
│   └── widgets/    # 通用 UI 组件
├── app.dart        # MaterialApp + 路由
└── main.dart       # 入口：初始化 + Provider 注入
```

---

## 功能模块结构

每个 feature 目录遵循统一结构：

```
features/<name>/
├── <name>_page.dart        # 页面（StatelessWidget 或 StatefulWidget）
├── <name>_provider.dart    # ChangeNotifier 状态管理
└── widgets/                # 页面级私有组件（可选）
    └── *.dart
```

---

## 新功能添加步骤

1. 在 `features/` 下创建目录
2. 创建 `<name>_provider.dart`（extends ChangeNotifier）
3. 创建 `<name>_page.dart`
4. 在 `main.dart` 中实例化 Provider 并加入 MultiProvider
5. 如需新 Service，在 `core/services/` 创建并在 main.dart 注入

---

## 命名规范

| 类型 | 规则 | 示例 |
|------|------|------|
| 页面 | `<feature>_page.dart` | `meeting_page.dart` |
| Provider | `<feature>_provider.dart` | `meeting_provider.dart` |
| 共享组件 | `snake_case.dart` | `loading_overlay.dart` |
| 类名 | PascalCase | `MeetingProvider` |
| 私有字段 | `_camelCase` | `_audioService` |
| 枚举 | PascalCase | `MeetingPhase.idle` |
| 路由无关页面 | `<name>_detail_page.dart` | `history_detail_page.dart` |
