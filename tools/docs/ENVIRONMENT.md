# 本地自动化测试环境

更新日期：2026-08-22

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
- 仓库级 Git 配置：`tools/configure_repository_git.ps1`
- 仓库验证器：`tools/validate_repository.ps1`
- 个人配置迁移：`tools/harden_codex_global_config.ps1`

项目默认使用 `workspace-write`、按需审批和非提权 Windows 沙箱。Illustrator MCP 令牌通过环境变量读取，不保存在仓库。Python 当前只属于可选工具；仓库核心检查和插件安装均可在 Windows PowerShell 5.1 下完成。

## 已验证工作站快照

当前家里工作站的验证克隆位于 `E:\AI_Workspace\Codex_Design`。该绝对路径只记录本机测试事实，不得写入需要跨电脑运行的脚本或配置。

- Codex CLI：0.147.0
- Node.js：v24.18.0
- npm：11.16.0
- Python：3.13.9
- VS Code：1.134.0
- Illustrator MCP：`adobe_illustrator` / `localhost:18412`
- 仓库级 Git：`core.autocrlf=false`、`core.eol=lf`、`core.safecrlf=true`

`environment_check.ps1 V2.4.1` 在该工作站最近一次记录的结果为：通过 28、警告 1、失败 0；警告来自当时尚未提交的仓库修改。Illustrator MCP 的配置、令牌变量存在状态和实时端口已通过检查，报告不记录令牌或代理凭据。

公司电脑未在本次记录中实际复验，不得标记为已验证。每个克隆都必须独立完成仓库 Git 配置、仓库验证和环境检查。

## 日常入口

每台电脑首次克隆后，先运行 VS Code 任务“配置本仓库 Git 规范”。随后优先使用 VS Code 任务或桌面工作台运行环境检查、仓库验证、同步和发布。任何 GitHub 网络检查都必须先通过当前代理验证；失败时停止，不尝试直连。
