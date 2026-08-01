# Illustrator Automation Guide


## 一、文档定位


本文档用于说明：

Adobe Illustrator 自动化开发特点。


通用脚本规范：

参考：
scripts/common/docs/CODING_RULES.md


---

# 二、Illustrator 自动化方向


本目录主要用于：


- 矢量图形生成
- 自动排版
- 图形系统创建
- SVG/PDF输出
- MCP实验


主要技术：

- ExtendScript
- JSX
- Illustrator MCP


---

# 三、目录说明


## jsx/


基础 Illustrator 脚本。


用于：

- 创建文档
- 操作对象
- 修改属性


示例：
create_document.jsx
create_object.jsx


---

## artwork/


图形生成。


应用：

- 基础图形
- 图案生成
- 自动绘制


示例：
create_circle.jsx
generate_pattern.jsx


---

## typography/


文字自动化。


包括：

- 创建文字
- 文字排版
- 字体处理


---

## layout/


版式自动化。


应用：

- 海报布局
- 网格系统
- 页面结构


---

## export/


输出流程。


支持：

- SVG
- PDF
- PNG


---

## assets/


矢量资源管理。


---

## mcp/


Illustrator MCP实验目录。


用途：

测试：
Codex
↓
MCP
↓
Illustrator


说明：

MCP作为辅助方式。

不是唯一自动化方案。


---

## templates/


AI模板文件相关自动化。


---

## examples/


测试案例。


---

## docs/


Illustrator相关说明文档。


---

# 四、开发方向


优先建设：


1. 参数化图形生成

2. 自动排版系统

3. SVG生产流程

4. 品牌视觉自动化

5. MCP辅助实验


---

# 五、与Codex协作


流程：
设计需求
↓
Codex生成JSX
↓
Illustrator执行
↓
验证结果
↓
保存脚本版本