---
name: floral-texture-motion-poster
description: 将已确认的肌理花卉静态母版延展为分层、可审计的短时动态海报方案，规划元素运动、节奏、转场、循环和 After Effects 生产。适用于几何纸纹与丝网印刷花卉海报的创建、优化和诊断；不用于无静态母版的自由视频生成、写实植物动画或默认镜头运镜。
metadata:
  status: initial-example
  source-experiment: experiments/floral-texture-visual-skills/实验记录.md
  supersedes-validity: none
---

# 肌理质感花卉动态海报

`Task = motion_poster`，`Style = texture_graphic`，`Production = after_effects`。本 Skill 重新建立为工程化初始示例；旧扁平 PNG 动态测试的质量结论不得当作当前能力已通过。

## 边界 / Boundary

- 支持：基于已确认静态母版创建动态方案；优化已有运动；诊断动态层级、节奏、连续性、循环与输出问题。
- 继承：静态构图、H1/H2/H3、色彩、肌理、主体、背景、文字和品牌硬锁。
- 不支持：无静态视觉依据的自由生成、写实植物生长模拟、口播视频、品牌全案、未授权镜头运动。
- 仅有扁平 PNG 时可做受限测试，但必须报告遮挡、形变和逐层控制限制；不得宣称为正式动态母版。

## 触发 / Trigger

当主要任务是“把几何纸纹/丝印花卉静态视觉做成动态海报，或优化、诊断此类动效”时触发。仅要求静态花卉转绘时应使用父 Skill `floral-texture-poster`，不触发本 Skill。

三类触发回归见 [测试矩阵](tests/test-matrix.json)：T01 直接点名、T02 自然语言、T03 模糊表达。

## 输入 / Input

- 已确认的静态母版或分层资产；至少说明背景、花头、花茎、文字和品牌信息能否分离。
- 静态父 Skill 的参数锁与审计结论；若静态母版未通过，先修复静态问题。
- 画幅、时长、帧率、节奏、循环、转场、首尾帧、镜头是否允许、输出格式与平台。
- H1/H2/H3 与希望被首先感知的运动目标。
- 准确文字、Logo、品牌色、音频策略、素材授权与字体授权。

缺少母版或关键生产参数时，可先输出方案与缺口清单，但不得声称已进入最终制作。

## 参数与 LOCKED / Parameters

按 [参数硬锁](../../references/shared/parameter-lock.md) 建立参数单。用户明确的静态参数全部继承为 `LOCKED`；动态参数中的 `duration`、`fps`、`rhythm`、`loop`、`transition`、`first_frame`、`last_frame`、`camera_allowed`、`audio`、`format` 均在用户指定后设为 `LOCKED`。

仅在用户未指定时使用 `FLEXIBLE` 默认值：

- `camera_allowed = false`
- `loop = false`
- `audio = none`
- `first_frame = approved-static-state`
- `last_frame = readable-stable-state`

不默认时长、帧率和平台格式；这些值会改变生产规格，缺失时应询问或明确标记方案假设。

## 冲突优先级 / Conflict Priority

用户显式参数 > 品牌/项目硬约束 > Skill 专属规则 > 当前命中的动态路由 > 静态父 Skill > 共享规则 > 默认值。按 [冲突处理](../../references/shared/conflict-resolution.md) 说明取舍，不得让动效覆盖静态 `LOCKED`。

## 路由 / Routes

只读取当前需要的文件：

1. 先读取静态父 Skill [floral-texture-poster](../floral-texture-poster/SKILL.md)，继承已确认的静态边界和参数，不自动执行父 Skill 的全部生产路线。
2. 读取 [主体](../../references/shared/subject.md)、[层级](../../references/shared/hierarchy.md)、[构图](../../references/shared/composition.md)、[色彩](../../references/shared/color.md)、[肌理](../../references/shared/texture.md)、[字体](../../references/shared/typography.md) 与 [共享审计](../../references/shared/audit.md)。
3. 读取 [motion_poster](../../references/routes/task/motion-poster.md)、[texture_graphic](../../references/routes/style/texture-graphic.md) 与 [After Effects](../../references/routes/production/after-effects.md)。
4. 只在动态任务中读取 [motion-hierarchy](../../references/routes/motion/motion-hierarchy.md)、[timing](../../references/routes/motion/timing.md)、[transition](../../references/routes/motion/transition.md)、[loop](../../references/routes/motion/loop.md)、[motion-audit](../../references/routes/motion/audit.md) 及 [花卉动态领域规则](references/floral-motion.md)。
5. 优化时追加 [optimization](../../references/routes/task/optimization.md)；诊断时追加 [diagnosis](../../references/routes/task/diagnosis.md)。

## 工作流 / Workflow

1. 判断边界与创建/优化/诊断模式，检查静态母版和资产分层。
2. 继承并复核所有静态 `LOCKED`，再锁定动态参数与冲突。
3. 明确 H1/H2/H3：谁先被看见；再定义 M1/M2/M3：哪种运动先被感知。两套层级分别记录。
4. 选择最小动态路由，建立首帧、发展、尾帧和循环接点。
5. 分别设计元素运动与镜头运动。默认固定镜头；只有 `camera_allowed = true` 才设计运镜。
6. 把运动事件落实到秒数/帧、对象、方向、幅度、缓动、遮挡和停留。
7. 在 After Effects 路线中规划图层、锚点、预合成、关键帧和输出；扁平素材明确近似方法与限制。
8. 抽查关键帧、逐帧边缘、背景、文字阅读、首尾帧与循环；任何 `FAIL` 先修复。

## H 与 M 层级

- `H1/H2/H3` 是静态注意力与阅读顺序。
- `M1/M2/M3` 是运动注意力与节奏优先级。
- H1 不必等于 M1，但 M1 不得长期遮挡、变形或削弱 H1。
- 元素运动 ≠ 镜头运动。位置、缩放、旋转、形状、透明度属于元素运动；推拉、摇移、轨道、景深变化属于镜头运动。

## 输出 / Output

精简模式：继承锁摘要、H/M 层级、时序表、首尾帧、镜头/循环策略、AE 制作要点与审计结论。

完整专业模式：静态母版门禁、资产分层表、全部参数来源与状态、H/M 映射、逐段时间轴、转场/循环/镜头说明、AE 图层与关键帧方案、输出编码、关键帧复核、风险与未验证项。

未实际完成制作和视频检查时，只能写“动态方案完成，制作/渲染未执行”。

## 审计 / Audit

先执行共享 Audit，再执行 Motion Audit。

- **PASS**：静态 `LOCKED`、动态参数、H/M 层级、首尾帧、连续性、阅读与输出全部通过。
- **WARNING**：扁平资产限制、字体/素材授权、平台编码或实机播放尚待确认。
- **FAIL**：时长/帧率/循环漂移；元素运动被误作运镜；无授权镜头；突然换花、背景漂移、边缘闪烁、循环跳点、文字不可读。

任何历史测试只作为证据，不自动赋予当前 Skill 可用性结论。通过 T01–T20 结构用例也不等于通过人工动态质量门禁。
