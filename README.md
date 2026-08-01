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