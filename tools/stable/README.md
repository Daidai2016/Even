# 稳定版本归档

本目录保存本轮架构改造前的生产工具版本，用于人工比对和故障回退，不作为默认运行入口。

- 文件名保留原工具名和版本号。
- 默认入口仍位于 `tools/`。
- 不自动覆盖、删除或执行这里的脚本。
- 回退前先核对当前文件、目标版本和影响范围。

本轮部署优化前新增归档：

- `bootstrap_workspace_v1.1.ps1`
- `environment_check_v2.4.0.ps1`
- `validate_repository_v1.1.0.ps1`

- `validate_repository_v1.2.1.ps1`：加入视觉源文件与插件一致性检查前的验证器，仅供回退比对。

本轮 Skills 同步补齐前归档：

- `localize_codex_skills_v1.1.1.ps1`：递归发现用户嵌套 Skill 前的中文化工具。
- `sync_codex_capabilities_v1.0.1.ps1`：增加外部插件市场恢复前的同步工具。

本轮代理环境强化前归档：

- `create_codex_env_v1.0.0.ps1`：原代理环境生成器，仅供比对；旧版直接覆盖且不备份，不建议恢复为日常入口。
- `create_desktop_shortcuts_v2.3.3.ps1`：加入代理环境恢复入口前的快捷方式生成器。
