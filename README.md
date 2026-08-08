# Codex Design Workspace


## 项目定位


Codex Design Workspace 是 AI 辅助创意工作流开发与生产平台。目标是将自然语言需求转化为可复用的创意能力、便捷工具和可验证交付物。


## 两个项目重点

### 1. AIGC 图像生成能力

建立审美、版式、字体和形式创意能力，并沉淀为提示词、参考资产、评价标准、工作流和 skills。

### 2. 设计便捷工具

开发脚本、动作、模板、生成器和多工具组合技巧，降低重复操作和出错率。



---


# 核心理念


创意标准回答“什么是好结果”，工具回答“如何稳定实现”。两者可协同，不相互代替。


优化方向：

- 创意目标、内容、数据和制作结果正确
- 工作流程稳定
- 减少重复操作
- 支持无人值守运行
- 保证文件交付可靠


形式、代码和工具结构都必须服务于实际需求。



---


# 支持平台与交付物


平台包括 Adobe Creative Cloud、PowerPoint、Excel、Word、PDF 及其他创意和数据工具。交付物包括图像、图标、设计文件、演示文稿、数据表格、文档、报告和可复用工作流。


---


# Codex 本地架构


项目使用“个人安全基线 → 项目配置 → Hooks 门禁 → 插件与 skills → 生产脚本 → 验证与报告”的分层结构。Illustrator MCP 只在项目内配置，敏感令牌只从环境变量读取；GitHub 同步、发布和远程检查统一经过代理守卫，未检测到当前有效代理时停止，不回退直连。


详细结构、运行链路和安全边界见 `docs/CODEX_ARCHITECTURE.md`。



---


# 桌面工作台


运行 `tools/create_desktop_shortcuts.ps1` 后，会在 Windows 桌面创建：

- `Even Codex Design` 工作台根文件夹
- `01_开发工具`、`02_Adobe脚本`、`03_项目管理` 三个分类文件夹
- 14 个工作快捷方式，其中 13 个沿用原有生产逻辑
- `Codex Design 本地项目` 快捷方式，用资源管理器打开当前仓库根目录


`Codex Design 同步GitHub` 会从脚本所在位置自动确定仓库。它只在 `main` 工作区干净、代理可用、本地仅落后 `origin/main` 时执行 `pull --ff-only`。检测到未提交修改、本地领先或分支分叉时只报告并停止，不会自动 reset、clean、stash、commit 或 force。


`Codex Design 环境检查` 会检查 Windows、PowerShell、Git、Node.js、npm、Python、Codex、VS Code、Photoshop Beta、Illustrator Beta、MCP、Hooks 和插件配置概况，并在 `logs/` 中生成带时间的环境报告。报告不记录密钥、令牌或代理凭据。


VS Code 任务还提供仓库验证、个人 Codex 配置加固和本地工作流插件安装入口。配置加固会先保存时间戳备份；插件安装使用仓库内 `.agents/plugins/marketplace.json`，不依赖远程市场。


`Codex Design 终端` 会优先使用 Windows Terminal，并明确以 Windows PowerShell 作为命令行环境，默认进入当前仓库根目录。如果电脑没有安装或无法找到 Windows Terminal，快捷方式会自动回退为直接打开 Windows PowerShell。


图标文件、视觉规则和 Windows 尺寸要求统一见 `assets/icons/README.md`。


仓库路径由脚本所在位置动态推导，不写死盘符或绝对路径。因此同一份仓库可在不同电脑、盘符或目录中运行。仓库移动后重新运行脚本，即可刷新快捷方式、文件夹图标路径和资源管理器图标缓存。



---


# 项目结构


```text
Codex_Design/

├── .codex/
│   项目级 Codex 配置和 Hooks
│
├── .agents/plugins/
│   团队本地插件市场清单
│
├── plugins/
│   Codex Design 可安装插件与 skills
│
├── scripts/
│   Adobe 及其他生产自动化脚本
│
├── tools/
│   仓库、环境和工作流辅助工具
│
├── workflows/
│   已验证的创意与生产流程
│
├── prompts/
│   可复用 AIGC 提示词
│
├── assets/
│   设计资源、参考图、色板和字体样例
│
├── experiments/
│   未验证的 AIGC 和工作流实验
│
├── docs/
│   项目文档、Word 和报告类成果
│
├── presentation/
│   PowerPoint 汇报与展示文件
│
└── work/
    可清理的分析、生成和测试中间文件
```


---


# 工作方式

```text
需求
↓
AIGC 主线：创意标准、训练、提示词、skills
或
工具主线：脚本、动作、模板、多工具组合
↓
测试与验收
↓
可复用能力或可交付成果
```



---


# 文档体系

| 文档 | 职责 |
| --- | --- |
| `README.md` | 项目概览、入口和工作台说明 |
| `AGENTS.md` | 仓库级操作、安全与交付规则 |
| `CODING_RULES.md` | 代码、自动化工具和创意交付物的通用开发规范 |
| `docs/AIGC_CREATIVE_RULES.md` | AIGC 审美、版式、字体、形式创意与 skill 建设规范 |
| `docs/CODEX_ARCHITECTURE.md` | Codex 本地配置、Hooks、插件、代理与验证架构 |
| `scripts/photoshop/AGENTS.md` | Photoshop 目录局部强制规则 |
| `scripts/illustrator/AGENTS.md` | Illustrator 目录局部强制规则 |
| `scripts/common/docs/ADOBE_AUTOMATION_GUIDE.md` | Adobe 软件职责与协作指南 |
| `scripts/*/docs/README.md` | 对应软件的能力和工作流说明 |
| `tools/docs/ENVIRONMENT.md` | 本地测试环境事实 |



---


# 项目目标

建立可持续进化的 AIGC 创意能力和设计便捷工具体系，让创意标准可训练、操作流程可复用、交付结果可验证。
