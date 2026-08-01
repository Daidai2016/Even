# Codex Design Workspace Instructions


## 一、项目定位


本项目是：

AI + Adobe Creative Cloud 自动化设计工作平台。


目标：

通过 OpenAI Codex 辅助设计师建立：

- Photoshop 自动化工作流
- Illustrator 自动化工作流
- Adobe 软件协同流程
- AI辅助设计生产体系


支持软件：

- Adobe Photoshop
- Adobe Illustrator
- Adobe InDesign
- Adobe Bridge
- Adobe Acrobat


---

# 二、Codex 工作原则


## 1. 中文优先


所有沟通：

使用中文。


说明：

使用清晰、步骤化表达。


代码注释：

遵循项目脚本规范。


---

## 2. 修改前说明


当需要：

- 创建文件
- 修改文件
- 调整目录结构
- 修改配置


必须先说明：


1. 修改目的

2. 涉及文件

3. 实现方案


未经确认：

不要进行大范围结构调整。


---

## 3. 不主动删除


禁止：

- 删除已有脚本
- 删除用户文件
- 覆盖已有成果


如果需要替换：

创建新版本。


例如：
script_v1.jsx
script_v2.jsx


---

# 三、项目结构规则


主要目录：


scripts/
Adobe自动化脚本
workflows/
设计流程记录
prompts/
AI提示词管理
assets/
设计资源
docs/
项目文档
presentation/
汇报演示文件
mindmaps/
思维导图文件


---

# 四、Adobe自动化目录


Adobe脚本统一存放：


scripts/


主要目录：


scripts/
├── photoshop/
├── illustrator/
├── indesign/
├── bridge/
├── acrobat/
└── common/


不同软件的详细开发规范：

参考：

scripts/common/docs/CODING_RULES.md


以及：

scripts/photoshop/docs/README.md
scripts/illustrator/docs/README.md


---

# 五、文件管理原则


## 设计文件


大型设计文件：

使用 Git LFS 管理。


包括：

- .ai
- .psd
- .psb
- .indd
- .pptx
- .xmind
- .tif


---

## 脚本文件


所有自动化脚本：

存放：

scripts/


不要随意放置在项目根目录。


---

## 文档文件


说明文档：

存放：

docs/


软件专项文档：

存放：

对应软件目录/docs/


---

# 六、Codex工作流程


处理任务时：

遵循：


理解需求
↓
分析方案
↓
说明计划
↓
创建或修改文件
↓
说明结果
↓
等待下一步指令


---

# 七、项目目标


最终建立：


自然语言需求
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
