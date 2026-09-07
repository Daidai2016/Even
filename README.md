# Codex Design Workspace

[AI视觉设计工作台：总指令、八模块与规范接入](docs/VISUAL_WORKBENCH.md)

本仓库是工作台唯一的本地根目录。八个设计主题复用现有规范、素材和脚本，不另建平行工作区。


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

`AI_Skills/` 保存 Skill 源文件和共享规范；`plugins/` 保存安装分发包。正式能力须通过证据门禁；现有静态视觉测试包的边界见 `docs/AIGC_CREATIVE_RULES.md` 第 8.1 节，安装成功不代表生产验证通过。



---


# 桌面工作台


运行 `tools/create_desktop_shortcuts.ps1` 后，会在 Windows 桌面创建：

- `Even Codex Design` 工作台根文件夹
- `01_开发工具`、`02_Adobe脚本`、`03_项目管理` 三个分类文件夹
- 分类整理的工作快捷方式，其中已有生产入口保持原有逻辑
- `Codex Design 本地项目` 快捷方式，用资源管理器打开当前仓库根目录
- `Codex Skills 与插件同步`，用于两台电脑之间补齐受管 Skills 与插件


`Codex Design 同步GitHub` 会从脚本所在位置自动确定仓库。它只在 `main` 工作区干净、代理可用、本地仅落后 `origin/main` 时执行 `pull --ff-only`。检测到未提交修改、本地领先或分支分叉时只报告并停止，不会自动 reset、clean、stash、commit 或 force。

`Codex Skills 与插件同步` 会先调用同一套安全 GitHub 同步流程，再按 `tools/config/codex_capabilities.json` 补装缺失的用户 Skills、Codex Design 本地插件和受管 OpenAI 插件，并刷新本机代理环境与中文界面。它不会覆盖已有 Skill、删除额外能力，也不会复制登录令牌、OAuth 状态或插件缓存。另一台电脑首次完成仓库克隆和本机部署后，日常只需双击该快捷方式。


`Codex Design 环境检查` 会检查 Windows、PowerShell、Git、Node.js、npm、Python、Codex、VS Code、Photoshop Beta、Illustrator Beta、MCP、Hooks 和插件配置概况，并在 `logs/` 中生成带时间的环境报告。报告不记录密钥、令牌或代理凭据。


VS Code 任务还提供仓库级 Git 换行配置、仓库验证、个人 Codex 配置加固和本地工作流插件安装入口。每台电脑首次克隆后运行一次“配置本仓库 Git 规范”，会设置当前仓库的 `core.autocrlf=false`、`core.eol=lf` 和 `core.safecrlf=true`，不修改系统或其他项目。配置加固会先保存时间戳备份；插件安装使用仓库内 `.agents/plugins/marketplace.json`，不依赖远程市场。

新电脑首次克隆后，优先在 VS Code 运行任务“首次部署本机 Codex Design”。该入口会验证仓库、配置当前克隆的 Git 换行规则、通过当前有效代理补齐用户 Skills、安装 `codex-design-workflows` 与 `codex-design-visuals`、应用系统及第三方 Skill 和插件中文界面、创建桌面工作台，并执行本地环境检查。部署过程不安装系统软件、不提交或推送；个人 Codex 全局配置加固仍保留为独立任务。完成后重新打开 Codex 或新建任务即可载入插件和中文名称。


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
├── AI_Skills/
│   按专业分类维护的 Skill 源文件、共享规则和初始版本
│
├── plugins/
│   正式能力与已登记本地测试包的安装分发副本
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
├── logs/
│   可清理的本地运行记录，不作为正式交付
│
└── work/
    可清理的分析、生成和测试中间文件
```

云端项目沿用“AI视觉设计工作台”；主题与本地文件的对应关系见 [工作台导航](docs/VISUAL_WORKBENCH.md)。本地内容统一保留在当前仓库，已有客户原件只登记来源位置，不另建外层工作区或平行资源库。


---


# 工作方式

## Visual Skill Architecture

平面与动态视觉 Skill 的工程规范位于 `AI_Skills/Graphic_Design/standards/VISUAL_SKILL_ARCHITECTURE.md`。共享可审计规则放在 `AI_Skills/Graphic_Design/references/shared/`，Task / Style / Production / Motion 条件路由放在 `AI_Skills/Graphic_Design/references/routes/`，具体 Skill 只按当前任务加载必要规则。

本地结构验证：

```text
python AI_Skills/Graphic_Design/scripts/validate_skills.py
```

验证会检查 frontmatter、必需章节、`LOCKED` 与冲突优先级、引用路径、界面元数据及 T01–T20 测试矩阵。结构验证通过后仍需真实素材与人工视觉评审，才能晋级为可安装插件。


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
