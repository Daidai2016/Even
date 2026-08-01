# Illustrator Automation Guide


## 一、文档定位


本文档用于说明：

Adobe Illustrator 自动化方向、
创作应用场景、
脚本目录结构和工作流程。


Adobe通用自动化规范：

参考：

scripts/common/docs/ADOBE_AUTOMATION_GUIDE.md


通用脚本开发规范：

参考：

CODING_RULES.md



---

# 二、Illustrator自动化定位


Illustrator是主要的：

矢量创作与矢量自动化平台。


自动化主要服务于：


- 矢量图形创作
- 矢量插画绘制
- 品牌视觉设计
- 图形系统生成
- 文字设计
- 自动排版
- SVG/PDF生产



---

# 三、Illustrator主要应用方向


## 1. 矢量图形创作自动化


用于：


- 图形绘制
- 路径创建
- 图形组合
- 参数化设计
- 图案生成



---

## 2. 矢量插画自动化


用于：


- 插画元素生成
- 图形系统建立
- 系列化视觉创作
- 自动绘制流程



---

## 3. 品牌视觉自动化


用于：


- Logo元素
- 品牌组件
- 视觉规范元素
- 模板化设计



---

## 4. 文字与版式自动化


用于：


- 创建文字
- 字体处理
- 自动排版
- 网格系统



---

# 四、大画面矢量制作规则


针对超大尺寸制作：


Illustrator中的1:10比例：

仅适用于：


- 矢量图形
- 路径对象
- 文字对象
- 版式结构



不适用于：


- 照片
- 位图图片
- AIGC图片素材



位图内容进入Photoshop流程。



典型流程：


Illustrator

↓

矢量/文字/版式 1:10制作

↓

高倍率输出

↓

Photoshop处理



---

# 五、目录说明


## jsx/


基础Illustrator脚本。


用于：

- 创建文档
- 操作对象
- 修改属性
- 执行自动化流程



---

## artwork/


图形创作。


用于：


- 基础图形
- 矢量插画
- 图案生成
- 参数化绘制



---

## typography/


文字自动化。


用于：


- 文字创建
- 排版处理
- 字体管理



---

## layout/


版式自动化。


用于：


- 海报布局
- 网格系统
- 页面结构



---

## export/


输出流程。


支持：


- AI
- PDF
- SVG
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


MCP为辅助自动化方式。


复杂生产任务：

优先使用JSX。



---

## templates/


AI模板相关自动化。



---

## examples/


测试案例。


用于：

- 功能验证
- 脚本测试



---

## docs/


Illustrator专项说明。



---

# 六、Illustrator与Photoshop协作


Illustrator负责：


- 矢量创作
- 插画
- 图形
- 文字
- 版式


Photoshop负责：


- 照片
- 图像处理
- AIGC
- 位图输出



协作流程：


Illustrator矢量创作

↓

Photoshop图像处理

↓

自动输出

↓

生产交付



---

# 七、与Codex协作流程


设计需求

↓

Codex分析

↓

生成或优化JSX

↓

Illustrator执行

↓

视觉验证

↓

保存脚本版本