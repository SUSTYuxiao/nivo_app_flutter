# Nivo 后端 API 参考

> 从 Tauri/React 旧版客户端提取，供 Flutter 新版客户端对接使用。

## 基础配置

- **Base URL**: `https://www.nivowork.cn`（可通过环境变量 `VITE_API_BASE_URL` 覆盖）
- **默认超时**: 30 秒（文件上传 60 秒）
- **Content-Type**: `application/json`（除非另有说明）
- **认证**: Bearer Token（通过 `Authorization` header）

---

## 类型定义

### ApiResponse\<T\>

所有接口统一返回格式：

```
{
  "code": number,
  "message": string,
  "data": T
}
```

### HistoryItem

```
{
  "id": string,
  "title": string,
  "userId": string,
  "email": string?,
  "industry": string,
  "outputType": string,
  "result": string,
  "input": string,
  "createTime": number,       // Unix 时间戳
  "updateTime": number?
}
```

### TimeRangeType

可选值: `"today"` | `"7days"` | `"30days"`

### ChatRunParams（会议纪要生成）

```
{
  "app_id": string,
  "workflow_id": string,
  "parameters": {
    "Content": string,        // 转录文本内容
    "Industry": string,       // 行业
    "Output_type": string,    // 输出类型/模板
    "app_id": string,
    "audioNum": number,       // 音频人数
    "textNum": number,        // 文本人数
    "files": string           // 附件
  }
}
```

---

## 接口列表

### 历史记录

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/db/getHistorySplit?userId={userId}` | 获取历史记录分组信息 |
| GET | `/db/getHistoryList?userId={userId}&page={page}&pageSize={pageSize}&timeRange={timeRange}` | 获取历史记录列表 |
| POST (form) | `/db/delHistory` | 删除历史记录，body: `{userId, id}` |
| POST (form) | `/db/updateHistoryTitle` | 更新历史标题，body: `{userId, id, title}` |
| POST (form) | `/db/addHistory` | 添加历史记录，body: `{userId, email?, result, input}` |

> `result` 字段格式为 JSON 字符串: `{"default": "纪要文本内容"}`

> 注意: `delHistory`、`updateHistoryTitle`、`addHistory` 使用 `application/x-www-form-urlencoded` 格式（postForm）。

### 权限

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/checkSuperAdmin` | 检查是否超级管理员，body: `{email}`, 返回 `ApiResponse<boolean>` |

### 会议纪要生成

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/chat/run` | 调用会议纪要生成工作流（非流式），body: `ChatRunParams` |
| POST (SSE) | `/api/chat/sse` | 流式纪要生成，body: `ChatRunParams`，返回 SSE 文本流 |

#### `/api/chat/sse` SSE 格式

请求 Header: `Accept: text/event-stream`

响应为标准 SSE 流，每行 `data: {...}` 包含一个 JSON 对象：

| 字段 | 说明 |
|------|------|
| `content` / `data` / `text` | 纪要文本片段（增量） |

流结束标志: `data: [DONE]`

### 文件上传

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/upload` | 上传文件，Content-Type: `multipart/form-data`，超时 60 秒，返回 `{url: string}` |

### 离线转录

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/transcribe` | 离线转录，body: `{audioUrl?, audioFile?, sessionId?, ...}` |

### 实时语音转录

| 方法 | 路径 | 说明 |
|------|------|------|
| GET (SSE) | `/api/speech/start?sessionId={sessionId}` | 建立 SSE 长连接，接收实时转录结果 |
| POST | `/api/speech/audio?sessionId={sessionId}` | 发送 PCM 音频数据，Content-Type: `application/octet-stream`，body 为原始 PCM 二进制 |
| POST | `/api/speech/stop?sessionId={sessionId}` | 发送停止信号，body 为空 |

### OSS 上传

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/oss/getStsToken` | 获取阿里云 OSS STS 临时凭证，返回 `{region, bucket, accessKeyId, accessKeySecret, securityToken}` |

### 云端离线转写（说话人分离）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/a2t/processV2?filePath={ossKey}` | 离线转写 + 说话人分离，返回 `[{beginTime, endTime, text, speakerId, speakerName}]` |

### 云端转写计费

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/recording-duration/config?userId={userId}` | 查询云端转写用量/限额，返回 `{usage, limit}` |
| POST | `/api/recording-duration/report?userId={userId}&duration={seconds}` | 上报转写时长（秒） |

### 会员信息

| 方法 | 路径 | 说明 |
|------|------|------|
| POST (form) | `/api/pay/getVipExpire` | 查询 VIP 状态，body: `{userId}`，返回 `{productName, expireTime, ...}` |

---

## SSE 事件格式

SSE 连接 (`/api/speech/start`) 返回的事件：

| event 字段 | data 格式 | 说明 |
|------------|-----------|------|
| `partial` | `{"text": "...", "speaker": "..."}` | 中间转录结果（会被后续 partial 覆盖） |
| `final` | `{"text": "...", "speaker": "..."}` | 最终转录结果（应追加到完整文本） |
| `error` | `{"text": "错误信息"}` | 服务端转录错误 |

---

## 业务常量

### 行业选项

`['企业服务', '金融', '消费', '科技', '制造']`

### 模板类型（经典模式）

| 枚举值 | 中文名 |
|--------|--------|
| CUSTOM | 自定义模板 |
| DEEP | 深度纪要 |
| DIALOGUE | 对话式纪要 |
| KEY_POINTS | 关键点式纪要 |
| TASK_ASSIGNMENT | 任务分配 |

### 场景类型（场景模式）

| 枚举值 | 中文名 |
|--------|--------|
| PURE_ROADSHOW | 纯路演 |
| ROADSHOW_QA | 路演与问答 |
| DD_INTERVIEW | 尽调客户访谈 |
| POST_INVESTMENT | 投后管理 |

### 模板模式

`'classic'` | `'scenario'` | `'custom'`

### 会议状态

`'pending'` | `'active'` | `'ending'` | `'ended'`
