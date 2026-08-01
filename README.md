# Codex Design Workspace


## 项目简介


Codex Design Workspace 是一个：

AI + Adobe Creative Cloud 自动化设计工作平台。


项目目标：

通过 OpenAI Codex 辅助设计师建立：

- Photoshop 自动化流程
- Illustrator 自动化流程
- Adobe 软件协同工作流
- AI辅助设计生产体系


---

# 核心方向


## 1. Photoshop 自动化


方向：

- 图像处理自动化
- 批量生产
- 图层管理
- AI素材后处理
- 自动输出


目录：
scripts/photoshop/


---

## 2. Illustrator 自动化


方向：

- 矢量图形生成
- 参数化设计
- 自动排版
- SVG/PDF输出
- MCP实验


目录：
scripts/illustrator/


---

## 3. Adobe 工作流整合


支持：

- Photoshop
- Illustrator
- InDesign
- Bridge
- Acrobat


目标：

建立跨 Adobe 软件的自动化设计流程。


---

# 项目结构


```text
Codex_Design/

├── adobe/
│   Adobe相关资源
│
├── scripts/
│   自动化脚本
│
├── workflows/
│   工作流程记录
│
├── prompts/
│   AI提示词
│
├── assets/
│   设计资源
│
├── docs/
│   项目文档
│
├── presentation/
│   汇报演示文件
│
├── mindmaps/
│   思维导图
│
└── experiments/
    实验项目

自动化架构
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

文档体系
项目规则：
AGENTS.md

↓

scripts/common/docs/CODING_RULES.md

↓

Adobe专项文档
Adobe专项：
scripts/photoshop/docs/

scripts/illustrator/docs/

当前阶段
已完成：
Git项目初始化
Codex规则体系建立
Adobe脚本目录规划
Photoshop自动化框架
Illustrator自动化框架
Git LFS配置

后续规划
阶段1
建立 Adobe JSX 模板。
阶段2
开发 Photoshop 自动化脚本。
阶段3
开发 Illustrator 自动化脚本。
阶段4
建立 Codex + Adobe 自动化生产流程。

技术环境
主要工具：
OpenAI Codex
Git / GitHub
Git LFS
Adobe Creative Cloud
ExtendScript / JSX

项目目标
最终实现：
自然语言需求
↓
Codex
↓
Adobe自动化
↓
设计生产
↓
版本管理