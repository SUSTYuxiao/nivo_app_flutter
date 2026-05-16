# 修正 API 响应双检查规范

## Goal

统一 Trellis backend spec 中 API 响应成功判定的契约，避免文档同时写“code 和 success 双检查”但示例使用 `||` 的不一致，降低未来实现误判成功响应的风险。

## Requirements

* 将 backend spec 中 API 成功判定统一为 `code == 200 && success == true`。
* 修正 `database-guidelines.md` 的示例代码。
* 修正 `error-handling.md` 的 ApiService 层描述。
* 不改动应用代码行为，本任务只更新 Trellis spec。

## Acceptance Criteria

* [ ] `.trellis/spec/backend/database-guidelines.md` 的文字和示例代码一致使用双检查。
* [ ] `.trellis/spec/backend/error-handling.md` 与质量规范中的“双检查”一致。
* [ ] grep spec 文档不再发现旧的逻辑或成功判定。

## Definition of Done

* Spec 文档已更新。
* 完成 grep 验证。
* 如仅修改文档，不强制运行 Flutter lint/test。

## Technical Approach

执行最小文档修正：把不一致的 `||` 改为 `&&`，保留既有文档结构和中文描述。

## Decision (ADR-lite)

**Context**: 后端 API 规范要求同时检查 `code` 与 `success`，但部分示例写成逻辑或。
**Decision**: 以更严格的双检查 `code == 200 && success == true` 作为唯一规范表达。
**Consequences**: 未来实现和 mock 数据都会按双字段成功契约编写；若后端存在只返回其中一个字段的接口，需要另行在对应接口 spec 中显式声明例外。

## Out of Scope

* 不扫描或修改 Dart 实现代码。
* 不新增测试。
* 不调整其他 API 字段契约。

## Technical Notes

* Relevant specs: `.trellis/spec/backend/database-guidelines.md`, `.trellis/spec/backend/error-handling.md`, `.trellis/spec/backend/quality-guidelines.md`。
* `quality-guidelines.md` 已写明“code+success 双检查”和“同时检查 code 和 success”。
