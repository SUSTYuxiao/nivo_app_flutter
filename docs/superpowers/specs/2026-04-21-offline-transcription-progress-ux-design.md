# 离线转写进度体验优化设计

## 问题概述

离线转写从发起到返回结果，存在 6 个"进度条不动"的死区，导致用户以为 app 卡死。

## 死区清单

| # | 死区 | 位置 | 持续时间 | 当前表现 | 严重度 |
|---|------|------|---------|---------|--------|
| 2 | 服务端转写 processAudioV2 | api_service.dart:238 | 1-10min | 进度卡在 90% 不动 | 致命 |
| 5 | LLM 生成阶段 | after_meet_provider.dart:145 | 10-60s | progress=1.0 显示对勾但还没完成 | 严重 |
| 4 | 本地转写 transcribeWithDiarization | fluid_audio_service.dart:40 | 1-5min | 完全无进度 | 高 |
| 6 | 错误静默吞掉 | after_meet_provider.dart:134 | — | 用户不知道失败了 | 高 |
| 3 | 本地模型下载 downloadModels | fluid_audio_service.dart:25 | 10s-2min | 无百分比，只有旋转 | 中 |
| 1 | getStsToken | oss_service.dart:22 | 1-5s | 文案写"上传中"但没动 | 低 |

## 设计决策

### 决策1：假进度曲线

基于文件时长动态调整，渐近曲线永远不到 100%，真实完成时跳转。

公式：`progress = base + range × (1 - e^(-t/τ))`
- 云端转写：base=0.9, range=0.05, τ=120s, 上限 0.95
- 本地转写：base=0.0, range=0.90, τ 基于文件大小估算

### 决策2：单阶段聚焦展示（非 Stepper）

各阶段时间差异太大（上传 5s vs 转写 5min），Stepper 会产生错误预期。
改为只显示当前阶段名 + 阶段内进度，阶段切换时有过渡动画。

### 决策3：文案策略

描述等待状态（"服务器处理中"），不假装描述处理步骤（"正在分离说话人"）。
后者一旦被识破会损害信任。

### 决策4：取消 = "可以离开"

短期：提供"返回"按钮，Provider 脱离页面生命周期继续运行，完成后写入历史。
中期：真正的后台处理 + 历史列表状态中心。

## 状态机重设计

### ProcessingStage 枚举

```dart
enum ProcessingStage {
  idle,
  fetchingToken,      // getStsToken, ~1-5s
  uploading,          // OSS PUT, 有真实进度
  cloudTranscribing,  // processAudioV2, 假进度
  downloadingModel,   // FluidAudio 模型下载
  localTranscribing,  // FluidAudio 转写, 假进度
  generating,         // LLM SSE 流式生成
  done,
  error,
}
```

### ProcessingView 显示逻辑

| stage | 环形指示器 | 线性进度条 | 文案 |
|-------|-----------|-----------|------|
| fetchingToken | indeterminate 旋转 | 隐藏 | "准备上传..." |
| uploading | determinate 弧形 | 显示百分比 | "上传中 (1/N)" |
| cloudTranscribing | determinate 弧形（假进度） | 显示百分比 | "服务器处理中..." |
| downloadingModel | indeterminate 旋转 | 隐藏 | "下载语音模型..." |
| localTranscribing | determinate 弧形（假进度） | 显示百分比 | "本地转写中..." |
| generating | indeterminate 旋转 | 隐藏 | "生成纪要中..." |
| done | 对勾 | 隐藏 | "完成" |
| error | 错误图标 | 隐藏 | 具体错误信息 |

### Provider 状态字段

```dart
ProcessingStage _stage = ProcessingStage.idle;
double _stageProgress = 0.0;    // 当前阶段内进度 0-1
int _currentFile = 0;
int _totalFiles = 0;
final List<String> _fileErrors = [];  // 错误收集
String? _warningMessage;              // 部分失败警告
```

## 文案设计

| 阶段 | 主文案 | 长等待文案（>30s） |
|------|--------|------------------|
| fetchingToken | "准备上传..." | — |
| uploading | "上传中 (1/N)" | — |
| cloudTranscribing | "服务器处理中..." | "处理时间较长，请耐心等待" |
| downloadingModel | "下载语音模型（仅首次）..." | "模型较大，请耐心等待" |
| localTranscribing | "本地转写中..." | "长录音处理较慢，请稍候" |
| generating | "生成纪要中..." | — |

## 错误处理

### 单文件失败
- 收集到 `_fileErrors` 列表，不中断流程
- 结果页顶部 Warning Banner："⚠️ 文件 X 转写失败，已跳过"
- 提供"重试"按钮

### 全部失败
- 设置 `_stage = error`
- 显示错误页面 + 重试按钮
- 不进入 LLM 生成阶段

### 部分成功
- 继续生成纪要（基于成功的文件）
- 结果页顶部显示警告

## 实施路线图

### Phase 1 — 立即修复（1-2h，纯前端）

1. `after_meet_provider.dart:145`：`_progress = 1.0` → `_progress = 0.0`，LLM 完成后才设 1.0
2. `after_meet_provider.dart:134`：收集文件错误到列表，UI 展示警告
3. `transcription_service.dart`：getStsToken 期间文案改为"准备上传..."

### Phase 2 — 核心改善（1 天，纯前端）

4. 引入 `ProcessingStage` 枚举，替代 isGenerating + progress 的模糊语义
5. processAudioV2 假进度：Timer 渐近曲线，0.9→0.95，τ=120s
6. 本地转写假进度：Timer + 文件大小估算处理时长
7. ProcessingView 改造：根据 stage 决定显示逻辑

### Phase 3 — 体验提升（3-5 天，纯前端）

8. 阶段聚焦 UI：当前阶段名 + 阶段内进度 + 切换动画
9. "返回"按钮：允许离开页面，Provider 继续运行
10. 提交前预估时间：基于文件时长显示"预计 X-Y 分钟"
11. LLM 流式预览：SSE 开始后直接切结果页

### Phase 4 — 深度优化（需后端/native，1-2 周+）

12. iOS EventChannel 真实下载/转写进度
13. 后端异步任务 + 轮询接口
14. 后台处理 + 历史列表状态中心 + 完成通知

## 附加改进

### 语音备忘录导入引导

iOS 语音备忘录不支持直接文件访问，需要用户手动分享到"文件"App。

在录音选择页（`recordings_list_page.dart`）的"导入文件"按钮旁新增"语音备忘录"按钮，点击弹出引导 modal：

1. 打开 iPhone 自带的「语音备忘录」App
2. 长按要导入的录音，点击「分享」
3. 选择「存储到"文件"」，保存到任意位置
4. 回到本页面，点击「导入文件」选择刚保存的文件

底部说明文字："语音备忘录不支持直接访问，需要先分享到「文件」App"

### 自动生成 AI 标题

对齐 Web 端行为：`addHistory` 成功后异步调用 `generateTitle(historyId)`。

- `api_service.dart` 的 `addHistory` 改为返回新记录 ID
- `after_meet_provider._saveToHistory` 和 `meeting_provider._saveToHistory` 保存后异步调 `generateTitle`
- 不阻塞主流程，失败静默（仅 debugPrint）
- 生成成功后刷新历史列表

### 实时转写分段时间戳

- `Transcription` 模型新增 `elapsed` 字段（相对会议开始时间）
- 每个 final 段落显示时间戳（mm:ss 格式）
- 智能显示：与上一条 final 间隔 >= 5 秒才显示，避免密集标注

### 设置页 UX 调整

- "离线转写" → "开启本地转写"，移除 Switch 旁的"云端"/"本地"文字
- 会员标识风格对齐个人页（chip 样式，VIP 金色 / 免费灰色底）
- 续费按钮改为弹窗提示"开发中，请到 web 端操作"
