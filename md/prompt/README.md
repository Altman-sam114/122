# Prompt 工作流说明

本文记录阶段 prompt 的写法和 Agent A/B/C 召唤约定。具体项目入口规则仍以根目录 `AGENTS.md` 为准。

## 角色召唤

- `agenta`、`a:` 或 `A:`：召唤 Agent A，负责目标分析和实现提示词。
- `agentb`、`b:` 或 `B:`：召唤 Agent B，负责按提示词实现、轻量检查、commit 并 push `origin/main`。
- `agentc`、`c:` 或 `C:`：召唤 Agent C，负责验收最新 `origin/main` commit、下载云端结果包并更新核心文档。
- 没有前缀时，按普通 Codex 任务处理；若任务天然需要 A/B/C 边界，先提醒用户指定角色，或说明本轮按普通任务执行。

最终回复身份行：

- Agent A 第一行：`我是 Agent A。`
- Agent B 第一行：`我是 Agent B。`
- Agent C 第一行：`我是 Agent C。`

## Agent A 提示词必须包含

Agent A 写给 Agent B 的版本化提示词必须至少包含：

- 本轮目标、非目标、禁止项。
- 当前架构依据：`AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 和相关源码。
- 实现范围：具体模块、文件、公共 API、数据 schema、文档更新范围。
- `main` 直推要求：基于 `main`，本地轻量检查后 commit，并 push 到 `origin/main`。
- 云端验证要求：push 后由 `.github/workflows/ci-results.yml` 触发 GitHub Actions。
- artifact 要求：Agent C 必须下载未加密 `ci-results` 结果包，核对 `ci-artifact-manifest.json`、`junit.xml`、主构建日志、失败摘要和 run metadata。
- 本地检查要求：只运行 `md/test/test.md` 允许的轻量检查；不默认本机跑 Xcode / XCTest / 模拟器 / Probe / Full。
- 验收标准与风险：哪些云端结果算通过，哪些重测试仍为 `skipped` 或未验证。

## Agent B 交付要求

Agent B 完成实现后必须说明：

- 本轮 commit SHA。
- 是否已 push 到 `origin/main`。
- 本地轻量检查命令和结果。
- GitHub Actions run id / run attempt / artifact 名称，或说明为什么尚未拿到。
- 未跑的本机重测试及原因。
- 已知风险。

## Agent C 验收要求

Agent C 验收时必须：

- 先确认 `origin/main` 最新 commit 与待验收 commit 一致。
- 使用 `gh auth login` 后下载结果包到 `/private/tmp/wwiihexv0-c-review-<run_id>/`。
- 打开并核对 `ci-artifact-manifest.json`、`junit.xml`、`xcodebuild.log`、`ci-failure-summary.md`。
- 核对 manifest 的 `branch=main`、`commitSha`、`runId`、`runAttempt`、artifact 名称与 GitHub Actions 最新 run 一致。
- 云端失败时写退回清单，不用旧 artifact 或文字汇报替代真实结果。

## 不迁移的项目特例

本项目只迁移“云端验证 + main 直推 + Agent C 结果包验收”的制度，不复制其他项目的漫画探针、GGUF、模型 Release、`smalldata_test`、`develop`、`codeb/...` 或 PR 合并制度。
