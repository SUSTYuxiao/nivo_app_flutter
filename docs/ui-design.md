# UI 设计文档

## 底部导航（4 Tab）

| Tab | 图标 | 说明 |
|-----|------|------|
| 实时会议 | mic | InMeet 实时录音转录 |
| 会后整理 | edit_note | AfterMeet 音频文件转写 |
| 历史 | history | 会议历史记录 |
| 设置 | tune | ASR 模式、账户 |

---

## InMeet 实时会议

三个状态：idle → recording → result

### Idle 状态
- 居中大标题"实时会议"
- 小字"点击下方按钮开始录音和实时转录"
- 全局收音开关（VIP 功能，非会员弹窗引导开通）
  - 关闭：本地 ASR（iOS: SFSpeech, Android: sherpa_onnx）
  - 开启：云端 SSE 转写，临时切换 useNivoTranscription
- "发起会议"按钮

### Recording 状态
- 录音脉冲动画 + 计时器（HH:MM:SS，tabular figures）
- "实时转录中"标签
- 转录文本滚动列表（partial 灰色原地更新，final 黑色新增行）
- 空状态："等待语音输入..."
- 底部控制：
  - 暂停/恢复按钮（暂停 = 停计时 + 停录音 + 停计费 + 灵动岛更新）
  - "结束会议"按钮 → 暂停 → 弹出底部选项：
    - "生成会议纪要" → 行业/模板选择 → endMeeting
    - "放弃总结" → reset 回 idle
    - "继续录音" → 恢复
- 生成中：ProcessingView（上传录音 → 转写中 → 生成纪要中）
- 错误消息红色显示

### Result 状态
- 标题"会议纪要"
- ResultToolbar（复制 / 分享 / 导出图片）
- Markdown 渲染纪要（MarkdownBody + SingleChildScrollView）
- "返回"按钮回到 idle
- 纪要自动保存到历史

### 灵动岛 / 锁屏实况窗（iOS 16.2+）
- 录音开始 → 启动 Live Activity
- 紧凑态：红点 + 计时器（系统 .timer 自动计时）
- 展开态：录音状态 + 计时器 + 状态文字
- 锁屏横幅：红点 + "会议录音中" + 计时器
- 暂停时：橙色 + "已暂停"
- 结束/重置 → 灵动岛消失

### 后台行为
- `UIBackgroundModes: audio` 保证锁屏录音不中断
- 后台超 2 小时未回前台 → 自动暂停（DateTime 对比，非 Timer）
- 回到前台后用户可手动恢复

---

## AfterMeet 会后整理

三个状态：idle → generating → result

### Idle 状态
- 居中大标题"会后整理"
- 小字"选择录音开始会后整理"
- "开始整理"按钮 → RecordingsListPage
- 右上角"历史录音"快捷入口
- 错误消息红色显示（submit 失败后可见）

### RecordingsListPage（录音选择页）
- 标题"选择录音" + 右上角"导入文件"按钮
- 两个分区：
  - "导入的文件"（外部导入，默认选中）
  - "本地录音"（InMeet 录音，可播放/删除/多选）
- 删除有确认弹窗
- 空状态："暂无录音" + "从文件导入"
- 底部"确认选择 (N)"按钮

### InputSheet（确认弹窗，85% 高度）
- 拖拽手柄
- 已选录音列表（带移除按钮）
- 补充文本输入（可选，4 行 TextField）
- 错误消息红色显示
- "提交整理"按钮 → 行业/模板选择 → 关闭 sheet → submit

### 生成中状态
- ProcessingView（进度条 + 状态文字）
- 状态流转：上传中 (i/n) → 等待服务器确认 → 转写中 (i/n) → 生成纪要中

### Result 状态
- 标题"整理结果" + "新整理"按钮
- ResultToolbar（复制 / 分享 / 导出图片）
- Markdown 渲染结果
- 纪要自动保存到历史

---

## 历史记录页

- 大标题"会议历史"
- 时间筛选 chips（全部 / 今天 / 7天内 / 30天内，默认 7天内）
- 白色卡片列表（标题 + 时间 + 行业标签）
- 下拉刷新 + 上拉加载更多（200px 触发）
- 初始加载骨架屏
- 空状态："暂无会议记录"

### 历史详情页
- 返回按钮 + 更多菜单（修改标题 / AI 生成标题 / 删除）
- 标题区：图标 + 标题 + 日期 + 行业标签
- ResultToolbar（复制 / 分享 / 导出图片）
- Markdown 渲染（Notion 风格：自定义 h1/h2/h3、blockquote、code block）
- 截图导出包含 NivoWork logo 水印

---

## 共享组件

### ResultToolbar
- 复制：内容到剪贴板 + snackbar
- 分享：SharePlus 文本分享
- 导出图片：RepaintBoundary 3x 截图 → PNG → SharePlus 文件分享
- 复用于：InMeet Result / AfterMeet Result / History Detail

### IndustryTemplateDialog（底部弹窗）
- 行业 Wrap chips（8 个：企业服务 / 消费文娱电商 / 金融 / 半导体 / 信息科技 / 材料 / 能源 / 制造）
- 模板模式切换（经典 / 场景 / 自定义）
- 经典模板：自定义 / 深度纪要 / 对话式 / 关键点 / 任务分配
- 场景模板：纯路演 / 路演与问答 / 尽调客户访谈 / 投后管理
- "确认"按钮
- InMeet 结束会议和 AfterMeet 提交都复用

### ProcessingView
- 圆形进度指示器 + 状态文字
- 复用于 InMeet 生成中 / AfterMeet 生成中

---

## 设置页

分组卡片风格：

### 个人信息
- 头像（首字母圆形）+ 邮箱 + VIP 状态
- 点击进入个人详情页（VIP 信息、用量）

### 退出登录

### 语音识别
- 离线转写模式切换
  - iOS：本地 / 云端（默认本地）
  - Android：固定云端
- 本地模型下载状态（FluidAudio ~700MB）

### 关于
- 版本号

### 开发者（开发者模式开关后显示）
- 模拟非会员
- 流式生成开关（默认开启，关闭走非流式 chatRun）

---

## 流式纪要生成

- 默认使用 SSE 流式（`POST /api/chat/sse`）
- 纪要逐字流式显示（StringBuffer 累积，100ms 节流 notifyListeners）
- 开发者模式可关闭流式，回退到非流式 `POST /api/chat/run`
- 生成完成后自动保存到历史（input 包含完整 Content/Industry/Output_type JSON）
