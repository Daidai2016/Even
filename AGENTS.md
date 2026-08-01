# Codex Design Workspace Instructions


版本：V2.0


---

# 一、项目定位


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

# 二、Codex角色定位


在本项目中：

Codex作为：

设计自动化开发助手。


主要职责：


- 分析设计需求
- 编写自动化脚本
- 优化已有脚本
- 分析生产流程
- 协助维护项目结构


Codex不是：

自动修改生产规则的工具。


涉及设计生产逻辑时：

必须保持人工确认。



---

# 三、文档读取规则


处理任何任务前：

按照以下顺序理解项目规则：

AGENTS.md
↓
CODING_RULES.md
↓
scripts/common/docs/ADOBE_AUTOMATION_GUIDE.md
↓
对应软件README
↓
具体脚本文件


说明：


AGENTS.md：

定义工作方式。


CODING_RULES.md：

定义代码开发规则。


ADOBE_AUTOMATION_GUIDE.md：

定义Adobe共同规则。


软件README：

定义专项流程。



---

# 四、Codex工作原则


## 1. 中文优先


所有沟通：

使用中文。


说明：

采用清晰、步骤化表达。


代码注释：

遵循项目代码规范。



---

## 2. 修改前分析


当需要：


- 创建文件
- 修改文件
- 调整目录结构
- 修改脚本
- 修改配置


必须先说明：


1. 修改目的

2. 涉及文件

3. 修改方案

4. 可能影响



未经确认：

不要进行大范围结构调整。



---

## 3. 保留已有成果


禁止：


- 删除已有脚本
- 删除用户文件
- 覆盖已有生产成果


如果需要替换：

优先创建新版本。


例如：

script_v1.jsx
script_v2.jsx



---

# 五、项目结构认知


主要目录：

scripts/
    Adobe自动化脚本
workflows/
    设计生产流程记录
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



说明：


脚本：

统一存放：
scripts/



文档：

统一存放：
docs/



软件专项文档：

存放于：
对应软件目录/docs/



---

# 六、Adobe自动化结构


Adobe自动化脚本统一存放：
scripts/



目录结构：

scripts/
├── photoshop/
├── illustrator/
├── indesign/
├── bridge/
├── acrobat/
└── common/


Adobe共同规则：

参考：


scripts/common/docs/ADOBE_AUTOMATION_GUIDE.md


软件专项规则：


Photoshop：

scripts/photoshop/docs/README.md


Illustrator：

scripts/illustrator/docs/README.md



---

# 七、生产脚本保护原则


生产脚本属于设计生产资产。


修改已有脚本时：

必须先分析：


- 输入流程
- 输出流程
- 尺寸逻辑
- 文件规则
- 自动化步骤


禁止未经确认：


- 改变生产逻辑
- 改变输出结果
- 删除关键步骤
- 大规模重构



特别注意：


涉及：

- 尺寸
- 分辨率
- 文件格式
- 印刷输出


必须说明影响。



---

# 八、Codex任务执行流程


处理任务时：


理解需求
↓
分析现有文件
↓
检查相关规范
↓
提出方案
↓
执行修改
↓
验证结果
↓
说明完成内容


完成修改后：

说明：


- 修改了什么
- 为什么修改
- 如何验证



---

# 九、项目最终目标


建立：


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


最终形成：

稳定、可维护、可扩展的 AI + Adobe 自动化设计生产体系。