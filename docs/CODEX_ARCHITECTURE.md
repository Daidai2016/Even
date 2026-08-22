# Codex 本地架构

## 目标

本架构把个人默认配置、项目规则、运行门禁、可复用能力和生产脚本分层，避免把机器级权限、项目 MCP 与创意标准混在同一处。

## 分层

| 层级 | 位置 | 职责 |
| --- | --- | --- |
| 个人安全基线 | 用户 Codex 配置与全局 `AGENTS.md` | 默认审批、沙箱和跨项目安全底线 |
| 项目运行配置 | `.codex/config.toml` | 本仓库审批、沙箱、Hooks 和 Illustrator MCP |
| 项目治理 | `AGENTS.md`、`CODING_RULES.md` | 仓库、生产、安全和交付规则 |
| 自动门禁 | `.codex/hooks.json`、`.codex/hooks/` | 工具调用前阻止危险命令，变更后执行仓库验证 |
| Skill 源文件 | `AI_Skills/` | 按专业分类维护共享规范、具体 Skill 和初始版本 |
| 能力封装 | `plugins/`、`.agents/plugins/` | 只保存通过晋级门禁的可安装插件与窄范围 skills |
| 创意证据 | `experiments/`、`prompts/`、`workflows/`、`assets/` | 实验、评审、正式能力和合法资源 |
| 生产实现 | `scripts/`、`tools/` | Adobe 自动化和仓库运维工具 |
| 观测与恢复 | `logs/`、`tools/stable/` | 本地报告和修改前稳定版本 |

## 运行链路

```text
用户需求
  → AGENTS 与项目配置确定权限和边界
  → PreToolUse 检查危险命令与 GitHub 代理
  → skill / workflow / production script 执行
  → PostToolUse 运行变更验证
  → 人工创意或生产审核
  → Git 状态检查；只有明确授权后提交或发布
```

## 安全边界

- 默认采用 `workspace-write`，不把整个用户目录设为受信任项目。
- Illustrator MCP 只在本项目配置中声明，Bearer Token 只通过环境变量读取。
- 所有 GitHub 网络命令先运行 `tools/lib/github_proxy_guard.ps1`，未检测到当前有效代理时停止，不回退直连。
- Hook 是辅助门禁，不替代 `AGENTS.md`、人工审核或 Git 权限规则。
- `tools/harden_codex_global_config.ps1` 修改个人配置前创建时间戳备份；项目脚本修改前的稳定副本保存在 `tools/stable/`。
- `tools/backup_project.ps1` 排除 `.git`、凭据文件和临时目录，并生成 SHA-256 清单。

## 可复用能力晋级

创意内容从 `experiments/` 开始。Skill 的共享规则、具体入口和初始版本在 `AI_Skills/` 按专业分类维护，并显式记录实验来源与验证状态。只有具备代表性正反样本、来源和授权记录、人工视觉评审与复测证据时，才选择晋级到 `prompts/`、`workflows/`，或把窄范围 Skill 封装到 `plugins/` 并加入本地市场。仓库插件 `codex-design-workflows` 提供这一流程，不将未验证方向包装成正式能力。

`AI_Skills/` 是源文件管理层，不是 Codex 插件安装目录。需要在 Codex 中作为可安装能力分发时，必须经过晋级后封装到 `plugins/`。

## 操作入口

- 环境检查：`tools/environment_check.ps1`
- 仓库验证：`tools/validate_repository.ps1`
- 个人配置加固：`tools/harden_codex_global_config.ps1`
- 本地插件安装：`tools/install_codex_design_plugin.ps1`
- 工作区恢复：`tools/bootstrap_workspace.ps1`
- Git 同步与发布：`tools/git_sync.ps1`、`tools/git_publish.ps1`

这些入口同时注册在 `.vscode/tasks.json`，日常操作不要求手工拼接命令。
