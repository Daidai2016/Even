# 本地环境基准

更新日期：2026-08-22

## 家里工作站

- 仓库：`E:\AI_Workspace\Codex_Design`
- Codex CLI：0.147.0
- Node.js：v24.18.0
- npm：11.16.0
- Python：3.13.9
- VS Code：1.134.0
- Illustrator MCP：`adobe_illustrator` / `localhost:18412`
- 仓库级 Git：`core.autocrlf=false`、`core.eol=lf`、`core.safecrlf=true`

`environment_check.ps1 V2.4.1` 最终结果：

- 通过：28
- 警告：1（本轮仓库修改尚未提交）
- 失败：0

Illustrator MCP 的配置、令牌变量和实时端口均已通过检查。报告不记录令牌或代理凭据。

## 双电脑同步要求

每个克隆都需要单独运行 VS Code 任务“配置本仓库 Git 规范”，再运行“Codex Design 仓库验证”和“Codex Design 环境检查”。仓库文件不得包含电脑专属绝对路径；运行脚本通过 `$PSScriptRoot` 和工作区变量定位项目。

公司电脑当前未在本次会话中实际运行验证，不能标记为已验证。同步本轮仓库修改后，应按上述顺序完成一次本机检查。
