---
name: floral-texture-poster
description: 创建、优化或诊断几何纸纹与丝印肌理花卉静态素材；按需提供 PS/AI 完稿方案，不用于写实修图或动态视频。
metadata:
  status: initial-example
  source-experiment: experiments/floral-texture-visual-skills/实验记录.md
---

# 花卉图片转肌理质感素材

`Task = material_redraw`，`Style = texture_graphic`，`Production = image_generation + photoshop/illustrator（按需）`。生成图是后期素材，不默认等于最终母版。

## 边界 / Boundary

- 支持：从参考图创建肌理化花卉素材；优化现有转绘；诊断主体、层级、色彩、肌理和生产问题。
- 必须保留：用户锁定的花卉身份、数量、姿态、结构、颜色、画幅、背景、材质、文字和输出。
- 不支持：写实修图、植物学精准复原、动态动画、品牌全案、未经授权的艺术家风格复制。
- 没有代表性多样例与人工评审时，保持 `initial-example`，不得宣称为品牌生产标准。

## 触发 / Trigger

当主要任务是“把完整花卉转成几何纸纹/丝印肌理静态素材，或优化、诊断此类结果”时触发。仅提到普通花卉摄影、写实修图、动态海报或无关海报时不触发。

三类触发回归见 [测试矩阵](tests/test-matrix.json)：T01 直接点名、T02 自然语言、T03 模糊表达。

## 输入 / Input

- 花卉参考图；没有图片时提供足以识别花型、数量、姿态、结构和构图的描述。
- 用途、画幅/尺寸、输出格式与目标生产软件。
- 是否保留原色或明确换色；品牌色、色值和其他品牌资产。
- 背景、材质、文字及准确文案；未提供时才使用默认值。
- 参考图来源、授权状态与允许用途。

缺少会改变主体身份、准确内容或生产规格的信息时集中询问。不得重复询问已提供内容；未要求换色时直接保留原图配色。

## 参数与 LOCKED / Parameters

先按 [参数硬锁](../../references/shared/parameter-lock.md) 建立 `value/source/state` 参数单。用户明确的主体、颜色、画幅、尺寸、背景、材质、是否有文字、准确文案、Logo、字体、构图、输出格式和生产软件均为 `LOCKED`。

仅在用户未指定时使用以下 `FLEXIBLE` 默认值：

- `color_mode = preserve-source`
- `background = clean-white`
- `text_policy = no-text`
- `texture = screen-print + paper-grain`

“干净白底、无文字”是缺省值，不是不可变风格规则；用户要求彩色/透明背景或准确文字时，必须覆盖默认值并转为 `LOCKED`。

## 冲突优先级 / Conflict Priority

用户显式参数 > 品牌/项目硬约束 > Skill 专属规则 > 当前命中的路由规则 > 共享规则 > 默认值。按 [冲突处理](../../references/shared/conflict-resolution.md) 记录冲突、保留项和替代方案，不得擅自解除 `LOCKED`。

## 路由 / Routes

需要整理需求或编写提示时查阅 [提示编写指南](../../references/Prompt_Framework.md)，涉及跨任务原则或冲突时查阅 [共享视觉规范](../../references/平面设计生图与动态视觉规范.md)。当前任务已读取时直接复用；以下只加载命中的详细规则：

1. 按问题读取：花型识别或结构变化用 [主体](../../references/shared/subject.md)，注意力分配用 [层级](../../references/shared/hierarchy.md)，布局或裁切用 [构图](../../references/shared/composition.md)，配色用 [色彩](../../references/shared/color.md)，材质用 [肌理](../../references/shared/texture.md)，结果验收用 [共享审计](../../references/shared/audit.md)。
2. 转绘时读取 [material_redraw](../../references/routes/task/material-redraw.md)；建立或排查几何肌理风格时读取 [texture_graphic](../../references/routes/style/texture-graphic.md)。
3. 生图时读取 [image_generation](../../references/routes/production/image-generation.md) 及 [花卉领域规则与 Prompt](references/花卉图片转肌理质感素材.md)。
4. 选择 Photoshop 时只读 [photoshop](../../references/routes/production/photoshop.md)；选择 Illustrator 时只读 [illustrator](../../references/routes/production/illustrator.md)；两者都需要时才同时读取。
5. 有准确文字时追加 [typography](../../references/shared/typography.md)；优化时追加 [optimization](../../references/routes/task/optimization.md)；诊断时追加 [diagnosis](../../references/routes/task/diagnosis.md)。
6. 不读取任何 Motion Router。

## 工作流 / Workflow

只执行当前模式所需步骤。诊断以现象、证据、根因和最小修复建议为完成标准，不自动生成或改文件；仅提示词任务以可用提示为完成标准。创建或已授权优化时才执行生成、修复及所需后期。

1. 判断边界与创建/优化/诊断模式。
2. 解析 Task / Content / Hierarchy / Composition / Typography / Color / Material / Output。
3. 提取并锁定参数，检查冲突。
4. 按上表加载最小路由集。
5. 分析完整花卉的外轮廓、花瓣、花蕊、花心或蒴果、花茎、花托、叶片与枝条识别点。
6. 建立 H1/H2/H3、构图、背景、文字区、色彩与肌理参数。
7. 生成候选素材；完整主体必须使用统一几何、叠印、纸张颗粒和丝印语言。
8. 筛选并修复主体漂移、无授权换色、局部写实残留、假文字、脏底和纹理失控。
9. 按目标选择 PS/AI 后期；无法实际控制软件时明确标记未执行，并交付可操作清单。
10. 审计后输出；本次制作范围内的 `FAIL` 先修复再交付；诊断任务可报告原图的 `FAIL` 并完成诊断。生成修复若连续两轮未改善同一问题，保留当前结果、说明限制与下一步，不继续无效重试，也不标记制作验收通过。

## 输出 / Output

精简模式：直接给主 Prompt，必要时补关键硬锁、当前任务的排除项及后期与审计结论。只要提示词时不强制展示角色、契约或完整分析。

完整专业模式：按交付需要提供目标与约束、参数来源与状态、路由记录、视觉策略、主 Prompt 与必要约束、候选筛选、PS/AI 图层与制作清单、尺寸/色彩/格式、审计证据、版权与未验证项；不机械展示空章节。

用户只要求生成素材时，通过对应检查即为“生成素材完成”；只有任务包含后期制作时才报告“后期未完成”。未实际执行 Photoshop/Illustrator 时不得声称可编辑母版已完成。

## 审计 / Audit

始终核对 Requirement 与 Lock；按本次输出和改动执行相关的 Hierarchy、Composition、Typography（有文字时）、Color、Texture、Style 与 Production Audit。完整生产交付仍覆盖全部适用检查。

- **PASS**：完整花卉身份、全部 `LOCKED`、几何统一性、可读性和生产规格通过。
- **WARNING**：字体/素材授权、目标尺寸印刷、生成模型一致性或人工视觉确认待完成。
- **FAIL**：主体身份或数量改变；无授权换色；用户文字/背景/画幅被覆盖；只几何化花瓣；颗粒变噪点；风格串味；输出规格不符。

失败按 `E01_BOUNDARY` 至 `E13_AUDIT` 分类，并记录修复与复核结果。
