# Adobe Automation Guide


版本：V2.2



# 一、文档定位


本文档用于说明：

Adobe Creative Cloud 自动化生产体系。


适用软件：


- Photoshop
- Illustrator
- InDesign
- Bridge
- Acrobat



本文档说明：

各 Adobe 软件在自动化设计生产流程中的定位、职责和协作关系。本文档是体系指南，不替代仓库或软件目录中的 `AGENTS.md`。


项目通用开发规范：

参考：

CODING_RULES.md


Codex工作规范：

参考：

AGENTS.md



---


# 二、Adobe自动化体系定位


Adobe自动化目标：

建立从设计需求到生产文件的自动化流程。


整体流程：


设计需求

↓

AI辅助分析

↓

Adobe软件处理

↓

自动化流程执行

↓

设计生产文件



自动化主要解决：


- 重复性操作
- 批量处理
- 文件整理
- 流程连接
- 生产效率提升



自动化原则：

以实际设计生产流程为基础。


---


# 三、Adobe软件职责划分



## Photoshop


定位：

位图图像处理与后期制作中心。


主要应用：


- 照片修饰
- 图像创作
- 图像调整
- 特效制作
- AI生成图像后处理
- 批量图像生产
- 印刷图像处理



---


## Illustrator


定位：

矢量设计与图形创作中心。


主要应用：


- 矢量图形创作
- 矢量插画绘制
- 图形系统创建
- 自动排版
- 品牌视觉设计
- 大画面矢量制作
- SVG/PDF生产



---


## InDesign


定位：

多页面出版与版式管理中心。


主要应用：


- 画册排版
- 多页面文件管理
- 出版流程
- PDF输出
- 文档自动化处理



---


## Bridge


定位：

Adobe资源管理中心。


主要应用：


- 素材浏览
- 文件管理
- 元数据管理
- 批量资源整理
- 文件筛选与整理流程



---


## Acrobat


定位：

PDF检查与交付中心。


主要应用：


- PDF检查
- 文件整理
- 交付验证
- PDF处理流程
- 交付文件管理



---


# 四、Adobe自动化技术体系


## ExtendScript / JSX


主要用于：

Adobe软件内部自动化。


应用：


- Photoshop脚本
- Illustrator脚本
- InDesign脚本



特点：

适合稳定、可重复的生产流程。



---


## Photoshop Action


主要用于：

固定重复操作流程。


适合：


- 标准化处理
- 高频重复操作



---


## MCP辅助连接


MCP用于：

AI与Adobe软件之间的辅助连接。


定位：

辅助自动化方式。


适用于：


- 自动化探索
- AI交互实验
- 新型工作流研究



稳定生产流程：

优先采用：

- JSX脚本
- 文件自动化流程
- 可验证生产方式



---


# 五、Adobe软件协同流程



## 图像生产流程


AI生成素材

↓

Photoshop处理

↓

设计合成

↓

输出生产文件



---


## 矢量设计流程


Illustrator：

矢量图形、文字、版式制作


↓

输出设计文件


↓

Photoshop：

图像处理、效果调整


↓

完成生产文件



---


## 出版流程


Bridge：

素材整理


↓

Photoshop / Illustrator：

素材制作


↓

InDesign：

页面编排


↓

Acrobat：

PDF检查与交付



---


# 六、自动化建设方向



## Photoshop方向


重点：


- 图像处理自动化
- 批量生产流程
- 图层管理
- AI辅助图像处理



---


## Illustrator方向


重点：


- 参数化图形生成
- 矢量插画辅助
- 自动排版
- 品牌视觉自动化
- 大画面制作流程



---


## Adobe协同方向


重点：


- 软件之间流程连接
- 文件自动传递
- 生产环节自动化
- 设计流程标准化



---


# 七、专项导航

- Photoshop 强制规则：`scripts/photoshop/AGENTS.md`
- Photoshop 能力与流程指南：`scripts/photoshop/docs/README.md`
- Illustrator 强制规则：`scripts/illustrator/AGENTS.md`
- Illustrator 能力与流程指南：`scripts/illustrator/docs/README.md`

其他 Adobe 软件在出现稳定专项需求后，再建立对应局部规则和指南。
