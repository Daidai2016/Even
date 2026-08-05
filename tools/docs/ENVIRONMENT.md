# 本地自动化测试环境

## 文档定位

本文档只记录当前主要测试环境，不定义仓库操作或脚本开发规则。

通用规则见根目录 `AGENTS.md` 和 `CODING_RULES.md`；实时环境状态以 `tools/environment_check.ps1` 生成的报告为准。

## 当前基准

- 操作系统：Windows
- PowerShell 兼容目标：Windows PowerShell 5.1
- Photoshop：Adobe Photoshop (Beta)
- Illustrator：Adobe Illustrator (Beta)
- Adobe 脚本目录：由工具运行时动态检测
- 仓库路径：由脚本自身位置动态推导，不在文档或配置中固定盘符

## 环境报告

运行“Codex Design 环境检查”快捷方式后，报告保存在 `logs/environment_check_YYYYMMDD_HHMMSS.txt`。

报告可用于比较不同电脑的工具版本和 Adobe 安装路径，不应包含密钥、令牌或代理凭据。
