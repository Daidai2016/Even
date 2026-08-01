# Photoshop Automation Guide


## 一、文档定位


本文档用于说明：

Adobe Photoshop 自动化开发特点。


通用脚本规范：

请参考：
scripts/common/docs/CODING_RULES.md


---

# 二、Photoshop 自动化方向


本目录主要用于：

- 图像处理自动化
- 图层管理自动化
- 批量生产流程
- 文件输出流程
- AI辅助设计流程


主要技术：

- ExtendScript
- JSX
- Photoshop Action


---

# 三、目录说明


## jsx/


基础 Photoshop 脚本。


用于：

- 创建文档
- 创建图层
- 修改属性
- 执行动作


示例：
create_document.jsx
create_layer.jsx
save_document.jsx


---

## actions/


Photoshop Action 配合脚本。


适用于：

- 固定操作流程
- 重复性任务


---

## batch/


批量处理脚本。


应用场景：

- 批量调整图片
- 批量导出
- 批量转换格式


示例：
batch_resize.jsx
batch_export.jsx


---

## layers/


图层自动化。


包括：

- 创建图层
- 管理图层
- 调整图层属性
- 图层结构整理


---

## image/


图像处理。


包括：

- 尺寸调整
- 色彩处理
- 智能对象处理


---

## export/


输出流程。


支持：

- PNG
- JPG
- TIFF
- Web格式


---

## ai-workflow/


AI辅助设计流程。


典型流程：

AI生成素材
↓
Photoshop处理
↓
自动输出


---

## templates/


PSD模板相关自动化。


---

## examples/


测试案例。


用于：

- 功能验证
- 学习示例


---

## docs/


Photoshop相关说明文档。


---

# 四、开发方向


优先建设：


1. 自动文件处理

2. 批量图片生产

3. 图层自动管理

4. AI素材后处理

5. 自动输出流程


---

# 五、与Codex协作


工作流程：
设计需求
↓
Codex生成JSX
↓
Photoshop执行
↓
验证结果
↓
保存脚本版本