# 组件规范

> Flutter Widget 组件模式。

---

## 组件模式

### 页面组件

- 顶层页面用 `StatelessWidget` 或 `StatefulWidget`
- 通过 `context.read<Provider>()` 获取 Provider
- 通过 `context.watch<Provider>()` 监听状态变化
- 页面放在 `features/<name>/<name>_page.dart`

### 页面子组件

- 页面级私有组件放 `features/<name>/widgets/`
- 只在该页面内使用，不导出
- 通过构造函数接收回调和数据

### 共享组件

- 跨 feature 复用的组件放 `shared/widgets/`
- 命名体现用途：`NivoButton`、`LoadingOverlay`、`Skeleton`
- 提供合理的默认值，减少调用方必填参数

---

## Widget 设计原则

```dart
// 典型共享组件
class NivoButton extends StatelessWidget {
  final String label;       // 必填
  final VoidCallback? onTap; // 可选
  final double? width;       // 可选
  final Color? color;        // 可选覆盖

  const NivoButton({
    super.key,
    required this.label,
    this.onTap,
    this.width,
    this.color,
  });
}
```

- 必填参数用 `required`
- 可选参数用 nullable 或提供默认值
- 构造函数参数用 `super.key` 简写
- 回调用 `VoidCallback?` 或具体函数类型

---

## 样式模式

- 主题定义在 `lib/core/theme.dart`，通过 `ThemeData` 统一管理
- 颜色常量集中在 `AppColors`（`lib/core/constants.dart`）
- 纪要 Markdown 展示统一用 `nivoMarkdownStyle()` 函数（Notion 风格）
- 圆角: 主按钮 25，卡片 16
- 间距基准: 8/12/16/24

---

## 禁止

- 不要在 Widget `build()` 中创建 Provider 实例（应在 main.dart 或上层创建）
- 不要直接在 Widget 中做网络请求（通过 Provider/Service）
- 不要硬编码颜色值（用 `AppColors` 常量）
- 不要在 `dispose()` 后调用 `notifyListeners()`
