# Codex Design Workspace


## 项目定位


Codex Design Workspace 是一个：

AI + Adobe Creative Cloud 自动化设计生产工作平台。


通过 OpenAI Codex 辅助设计师建立：

- Photoshop 自动化工作流
- Illustrator 自动化工作流
- Adobe 软件协同流程
- AI辅助设计生产体系


目标：

将自然语言设计需求转化为稳定、可维护的自动化生产流程。



---


# 核心理念


本项目服务于真实设计制作流程。


开发原则：

生产逻辑优先于程序结构。


优化方向：

- 制作结果正确
- 工作流程稳定
- 减少重复操作
- 支持无人值守运行
- 保证文件交付可靠


代码结构和模块化设计必须服务于生产需求。



---


# 支持软件


主要支持：

- Adobe Photoshop
- Adobe Illustrator
- Adobe InDesign
- Adobe Bridge
- Adobe Acrobat



---


# 桌面工作台


运行 `tools/create_desktop_shortcuts.ps1` 后，会在 Windows 桌面创建：

- `Even Codex Design` 工作台根文件夹
- `01_开发工具`、`02_Adobe脚本`、`03_项目管理` 三个分类文件夹
- 12 个工作快捷方式，其中 11 个沿用原有生产逻辑
- `Codex Design 本地项目` 快捷方式，用资源管理器打开当前仓库根目录


`Codex Design 终端` 会优先使用 Windows Terminal，并明确以 Windows PowerShell 作为命令行环境，默认进入当前仓库根目录。如果电脑没有安装或无法找到 Windows Terminal，快捷方式会自动回退为直接打开 Windows PowerShell。


工作台根目录和三个分类目录均使用自定义文件夹图标：

```text
folder_workspace.ico
folder_development_tools.ico
folder_adobe_scripts.ico
folder_project_management.ico
```


本地项目快捷方式使用：

```text
codex_local_project.ico
```

整套图标采用明亮的 Codex 流动新拟态语言：有机云团或文件夹轮廓结合多组径向色场、局部柔光、轻微厚度和半透明表面光泽，不使用闭合白色外描边。Photoshop Beta 与 Illustrator Beta 安装脚本目录分别保留 Adobe 蓝青和金橙品牌主色。


仓库路径由脚本所在位置动态推导，不写死盘符或绝对路径。因此同一份仓库可在例如 `D:\Codex_Design`、`E:\AI_Workspace\Codex_Design` 等不同位置运行。仓库移动后重新运行脚本，即可刷新快捷方式、文件夹图标路径和资源管理器图标缓存。



---


# 项目结构


```text
Codex_Design/

├── scripts/
│   Adobe自动化脚本
│
├── workflows/
│   设计生产流程记录
│
├── prompts/
│   AI提示词管理
│
├── assets/
│   设计资源
│
├── docs/
│   项目文档
│
└── presentation/
    汇报与展示文件


自动化方向
Photoshop
主要方向：
图像处理自动化
批量生产流程
图层管理
文件输出
AI辅助图像处理
Illustrator
主要方向：
矢量图形创作
自动排版
图形系统生成
SVG/PDF生产
MCP辅助实验


工作方式
设计需求
↓
OpenAI Codex
↓
Adobe自动化脚本
↓
Photoshop / Illustrator执行
↓
设计生产文件
↓
Git版本管理


文档规范
项目规则：
AGENTS.md
用于：
Codex工作行为规范。
脚本开发规范：
CODING_RULES.md
用于：
Adobe自动化脚本开发规则。
软件专项规则：
scripts/photoshop/docs/README.md

scripts/illustrator/docs/README.md
用于：
具体软件自动化规范。


项目目标
建立：
设计师能够使用自然语言描述需求，
由 Codex 辅助生成和维护 Adobe 自动化流程，
最终形成稳定可靠的设计生产工具体系。
