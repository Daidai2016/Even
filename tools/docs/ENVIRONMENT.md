# 本地自动化测试环境

## 文档定位

本文档只记录 Codex Design 当前主要测试环境，不定义仓库操作、Git 发布流程或脚本开发规则。

通用工作规则见根目录：

- `AGENTS.md`
- `CODING_RULES.md`

实时环境状态以以下脚本生成的报告为准：

```text
tools/environment_check.ps1
```

## 当前架构基线

- 项目 Codex 配置：`.codex/config.toml`
- 项目安全 Hooks：`.codex/hooks.json` 与 `.codex/hooks/`
- 项目工作流插件：`plugins/codex-design-workflows/`
- 本地插件市场：`.agents/plugins/marketplace.json`
- GitHub 代理守卫：`tools/lib/github_proxy_guard.ps1`
- 仓库验证器：`tools/validate_repository.ps1`
- 个人配置迁移：`tools/harden_codex_global_config.ps1`

项目默认使用 `workspace-write`、按需审批和非提权 Windows 沙箱。Illustrator MCP 令牌通过环境变量读取，不保存在仓库。Python 当前只属于可选工具；仓库核心检查和插件安装均可在 Windows PowerShell 5.1 下完成。

## 日常入口

优先使用 VS Code 任务或桌面工作台运行环境检查、仓库验证、同步和发布。任何 GitHub 网络检查都必须先通过当前代理验证；失败时停止，不尝试直连。
