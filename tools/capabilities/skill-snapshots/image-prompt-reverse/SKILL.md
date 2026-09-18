---
name: image-prompt-reverse
description: 根据一张现有图片反推其 AI 绘图提示词（Prompt）。当用户提供/上传一张图片（或图片链接）并希望得到能复刻同款效果的完整绘图提示词时使用，例如“帮我反推这张图的提示词”“这张图是怎么生成的”“给我同款 prompt”“帮我拆解这张图”。覆盖通用、字体/Logo、风景场景、摄影写实、插画手绘、3D 渲染、IP 角色与潮玩设计七大场景；支持多图系列反推、按工具适配输出、负面提示词与验证闭环，输出可直接用于 GPT、豆包、Midjourney、可灵等工具的完整提示词。
---

# Image Prompt Reverse

## Overview

当用户看到一张图片想复刻同款效果时，不要凭空编造提示词，而是把图片当作参考图丢给 AI 先拆一遍：对图片做结构化拆解（主体、风格、色彩、光影、构图、质感、氛围），再按图片类型套用对应场景的维度框架，输出完整、可复用的 AI 绘图提示词。

## 工作流程

1. **获取图片**：读取用户提供的图片（本地文件用 Read 查看；链接先下载到本地再 Read）。图片不清晰时调大 thumbnail_size，或分区域查看关键细节。
2. **判断输入模式**：
   - 多张同系列图片（同一角色 / 潮玩系列 / 统一海报风格）→ 读 `references/series-consistency.md`，提取公共风格与变化元素
   - 单张图片 → 继续下一步
3. **判断图片类型**，选择对应参考文件：
   - 字体 / Logo / 海报等设计图 → 读 `references/logo-font.md`（必须逐字提取画面文字）
   - 风景 / 场景（自然、城市、奇幻） → 读 `references/landscape.md`
   - 摄影 / 写实（写真、产品、街拍、电影感） → 读 `references/photography.md`
   - 插画 / 手绘（扁平、厚涂、水彩等） → 读 `references/illustration.md`
   - 3D 渲染（写实渲染、卡通渲染、产品渲染） → 读 `references/3d-render.md`
   - IP 角色 / 潮玩（盲盒、手办、Q 版、艺术玩具） → 读 `references/ip-character.md`
   - 不确定或混合类型 → 读 `references/general.md`，按七要素全维度拆解
4. **逐维分析图片**：按所选参考中的维度逐一观察画面并记录证据，基于画面事实分析，不要凭空猜测。含文字的图必须精确提取文字内容。
5. **输出完整 Prompt**：按该场景的 Prompt 模板组织，包含画面主体、风格、色彩、光影、构图、质感、氛围等关键信息并附风格关键词；输出前读 `references/prompt-structure.md`，按"最终用途→主体→构图→风格→光线→材质→文字→不能出现什么"的 8 段逻辑统一组织，文字按引号+位置+字体+视觉效果描述；再读 `references/tool-adaptation.md` 按用户目标工具适配形态并附负面提示词；文字多时先读 `references/prompt-optimization.md` 控制文字组数与结构。
6. **验证闭环（可选）**：用户需要确认反推准确性时，用图像生成工具按反推出的 Prompt 重画一张与原图对比，差异明显则按 `references/prompt-optimization.md` 的纪律修正对应维度后重试；用户未要求时不执行。

## 输出要求

- 输出可直接粘贴到目标工具使用的完整 Prompt，形态按工具适配（默认自然语言版）；整体按 `references/prompt-structure.md` 的 8 段逻辑组织（最终用途→主体→构图→风格→光线→材质→文字→不能出现什么），**各段用自然语言连贯书写，不堆砌关键词标签**。
- 先简要说明每个维度的判断依据（每个维度一两句即可），再给出完整独立的 Prompt 文本，并附负面提示词。
- 含文字的图必须按文字规则输出：内容写在双引号内，并描述位置、字体风格、视觉效果；末尾明确"不要生成多余的文字、logo、水印或其它图形元素"。画面文案较多时，按 `references/prompt-optimization.md` 的文字纪律控制文字组数（保留核心 3–4 组）并加强约束，防止模型改写编造。
- 画面无法确定的维度（如具体焦距、参考画师），明确标注“推断”并给出合理默认值，不要假装看到画面中没有的信息。

## 参考文件

- `references/general.md` — 通用七要素拆解法（万能模板）
- `references/logo-font.md` — 字体 / Logo / 海报设计类（含文字提取）
- `references/landscape.md` — 风景 / 场景类
- `references/photography.md` — 摄影 / 写实类（含电影感镜头与布光）
- `references/illustration.md` — 插画 / 手绘类
- `references/3d-render.md` — 3D 渲染类（材质与渲染味道）
- `references/ip-character.md` — IP 角色与潮玩设计类
- `references/series-consistency.md` — 多图系列一致性反推
- `references/tool-adaptation.md` — 工具适配输出与负面提示词
- `references/prompt-optimization.md` — 反推 Prompt 优化与验证经验（文字纪律）
- `references/prompt-structure.md` — Prompt 组织逻辑（8 段固定结构模板）
