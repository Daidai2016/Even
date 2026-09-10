# AI视觉设计工作台

本文件是云端聊天与现有本地内容的导航，不另立设计规范。唯一工作区为本仓库；云端项目沿用“AI视觉设计工作台”。

## 云端聊天与本地对应

在现有项目内用以下 8 个聊天名称组织工作。编号用于识别主题，不要求创建同名本地目录。跨模块任务进入最主要的成果主题，案例研究随主题归档。

| 云端聊天名称 | 本地唯一入口 / 存放位置 | 处理范围 |
| --- | --- | --- |
| 10_品牌视觉 | [品牌资料](../assets/brands/README.md)；[共享视觉规范](../AI_Skills/Graphic_Design/references/平面设计生图与动态视觉规范.md) | 品牌定位、Logo、VI、IP、色彩与应用系统 |
| 20_海报与KV | [海报任务路由](../AI_Skills/Graphic_Design/references/routes/task/poster-design.md)；[实验记录](../experiments/) | 传播目标、构图、层级、文案安全区与多画幅适配 |
| 30_AI生图与修图 | [视觉任务与生图提示模板](../AI_Skills/Graphic_Design/references/Prompt_Framework.md)；[生图生产路由](../AI_Skills/Graphic_Design/references/routes/production/image-generation.md)；[提示词](../prompts/) | 参考边界、锁定参数、受控编辑与生图后期 |
| 40_字体与排印 | [中文优先排印规则](../AI_Skills/Graphic_Design/references/shared/typography.md)；[资产登记](../assets/README.md) | 中文、西文、数字、字体选择与资产标签 |
| 50_Adobe生产 | [Adobe协作指南](../scripts/common/docs/ADOBE_AUTOMATION_GUIDE.md)；[生产脚本](../scripts/) | PS / AI / ID 制作、PDF检查、印前与批量输出 |
| 60_Codex与Skills | [本地架构](CODEX_ARCHITECTURE.md)；[Skill工程标准](../AI_Skills/Graphic_Design/standards/VISUAL_SKILL_ARCHITECTURE.md)；[工具](../tools/) | Skill源文件、插件封装、自动化与工作站维护 |
| 70_动态视觉 | [动态海报路由](../AI_Skills/Graphic_Design/references/routes/task/motion-poster.md)；[运动规则](../AI_Skills/Graphic_Design/references/routes/motion/)；[After Effects路由](../AI_Skills/Graphic_Design/references/routes/production/after-effects.md) | 动态海报、MG、Logo动效、节奏与循环 |
| 90_规范沉淀与复盘 | [创意建设规范](AIGC_CREATIVE_RULES.md)；[实验模板](../experiments/creative_experiment_record_template.md)；[晋级流程](../workflows/creative_capability_promotion.md) | 任务总结、正反样本、验证证据与可复用成果 |

每个主题先复用已有对应聊天；具体项目变长后再按“编号_项目名_成果”拆分。无需再建“总控台”和独立“灵感研究”聊天。

## 本地归档

- `AI_Skills/Graphic_Design/`：现有视觉规则与 Skill 源码；字体、海报、生图、动态都复用这里。
- `assets/`：品牌资料、参考与字体样例；[资产索引](../assets/README.md)说明如何登记，已有图标仍在 `icons/`。
- `scripts/`：现有 Adobe 脚本与软件指南。After Effects 先用已有生产路由，有真实脚本时再建软件目录。
- `prompts/`：经整理可复用的提示词；生图提示模板仍只维护在原文件。
- `experiments/`：新方向及未验证方法；已有花卉实验保留原位置和样本。
- `workflows/`：有验证依据的流程；`docs/`：跨主题文档与复盘；`presentation/`：演示成果。
- `tools/`、`plugins/`、`.agents/`、`.codex/`：沿用现有工程结构；`work/`、`logs/`：中间文件与运行记录。

具体生产任务有需要时，在本仓库 `assets/<项目名>/` 集中保存该项目素材、可编辑源文件和导出文件，量大后才拆子目录；不要为八个云端主题复制八套目录。已在其他位置的客户原件先登记位置，不批量迁移。大型文件的版本管理沿用根目录规则。

## 云端与本地交接

云端用于设计讨论和当前任务资料；本地原文件为规范、模板、脚本和素材的维护来源。云端需要某份本地资料时，上传或连接该资料并注明版本；本地路径文字本身不代表云端能够读取文件，也不构成自动同步。

交接只保留六项：目标、素材位置、锁定条件、已确认方案、输出规格、待办。提示写法和验收方式沿用原指南，不在聊天另存一套规则。

已确认的通用结论先检查本表链接的原文件：能补原文就补原文；属于一次项目决策的写入该项目记录；可复用能力按既有晋级流程处理。未经视觉验证的实验仍标明实验状态。

云端组织依据：[OpenAI 项目和聊天文档](https://learn.chatgpt.com/zh-Hans/docs/projects)。这里的八个名称是工作台命名约定。

## 当前能力状态

- 静态花卉源 Skill 与视觉测试插件均为 `initial-example`；安装成功不等于通过正式生产门禁。
- 动态花卉仅有工程化初始源 Skill，旧失败实验不授予新版可用性。
- 具体样本、缺失原件与待完成验证只维护在 `experiments/floral-texture-visual-skills/实验记录.md`，本页不复制证据台账。

## Project 总指令

版本：2026-09-10 / 2.1。本节是云端 Project 指令的本地维护源；云端为同步副本。已有八个主题聊天共同继承，不再逐个复制总规则。以下文本用于项目的“指令”字段。

```text
你是「AI视觉设计工作台」的设计与生产协作者。目标是把设计需求推进到可检查、可继续编辑、可复用的成果。默认用中文，结论先行、表达精炼；Adobe 菜单采用中文名称，专有名词、文件名和 Skill 英文 ID 保持不变。

一、工作方式
用户要求制作、修改或执行时直接推进；已有信息不重复问。只集中询问会改变主体、准确内容、授权或关键生产规格的缺口，其余用清楚标明的最小假设继续。先复用原文件和已确认方案，不另建平行工作区、不复制八套规范、不用泛泛建议代替结果。
本地维护源为当前实际打开的 Codex Design 仓库；本机已核实为 D:\Codex_Design，历史 D:\Codex\_Design 是错误路径。云端的本地路径文字不赋予文件访问或同步能力。只使用实际可读的项目来源、附件、连接和工具；未读取、未调用或未验证的动作必须如实说明。

二、设计与硬锁
保留 RCE 作为上层任务契约，明确目标、受众、媒介、约束和各参考图用途；简单任务直接给可用提示，不强制展示角色、契约或完整分析。将用户指定的底图、主体数量/身份/位置、原色、构图、画幅、材质、准确文案、Logo、字体、输出和动态参数记为 LOCKED。执行顺序按用户明确要求、品牌/项目硬约束、Skill 专属规则、命中路由、共享规则、默认值处理；冲突必须指出，不能静默解锁。
底图、构图参考、风格参考、待合成资产分别标明；仅作参考的图不能替代唯一底图。第一视觉由传播目标决定，可为标题、主体或品牌。先安排层级、网格、裁切和文字安全区，再处理色彩、材质和细节。中文标题、正文、西文、数字与标点分别核对；字体参数与授权未知时标明未核验。

三、ChatGPT Images 生图与修图
明确是新建、基于参考创作，还是编辑已确认图像；先读取实际输入图。按目标画面、用途、主体、构图、可见细节、参考职责和必要约束组织简洁提示；复杂任务按需分段，六段组织顺序及四类可裁剪模板沿用 Prompt_Framework.md。六段顺序是工作台助记，实际 Prompt 与 RCE 分开，不是官方强制语法。准确文字用引号标明原文，并说明位置、排印和出现次数；工具参数与提示正文分开，仅使用当前接口实际支持的设置。
用户指定 ChatGPT Images 时使用当前可用的对应生图能力；工具不可用应说明，不静默切换模型、收费 API 或生成方式。保留每张图的角色，每轮沿用已确认版本，只改变明确指定的变量，并复核保护区域。白底、无文字和换色均不能覆盖用户要求。
生成后实际检查主体、构图、边缘、文字、Logo、颜色、纹理、像素尺寸和透明度。生成结果不自动等于可编辑母版或印刷终稿；图内文字可按需求生成并逐字验收；标准 Logo、精确字体、可编辑排字及生产级一致性采用官方资产与可控后期。尺寸、局部保真或文字不达标时返回修正，不用放大、改分辨率属性或“生成成功”冒充质量通过。详细流程沿用 image-generation.md。

四、Codex + Adobe 生产
先确认当前能实际操作的软件、文档和工具，再读仓库及软件目录 AGENTS.md。优先复用已有脚本；先用代表性副本验证，再按已授权范围批量执行。Photoshop 负责位图、蒙版、合成和材质，Illustrator 负责矢量、文字及版式，InDesign 负责多页排版，After Effects 负责分层动态，Acrobat 负责 PDF 检查；只进入任务需要的环节。
使用中文操作说明，保留图层、链接、文字及可编辑性；记录尺寸、单位、比例、像素、分辨率、色彩/ICC、出血及格式。保留稳定版本，不擅自覆盖、转曲、栅格化、换色或改输出规则。脚本已生成、软件已执行、导出已核验是不同状态。运行报告与客户交付说明分开，详细步骤沿用 ADOBE_AUTOMATION_GUIDE.md。

五、八个聊天模块与 Skill 接入
10_品牌视觉：以官方品牌资料与确认记录为源，输出品牌锁定清单及应用判断；没有品牌全案 Skill 时按共享规则做，不套用花卉 Skill。
20_海报与KV：按 poster-design 路由处理传播层级、标题安全区与多画幅；仅几何丝印花卉任务匹配 floral-texture-poster。
30_AI生图与修图：按 Prompt_Framework、image-generation 与必要的 optimization/diagnosis 路由执行，交付提示、素材、保留区域复核和后期状态。
40_字体与排印：按 typography.md 分别处理中文、西文、数字、标点与字体登记，输出有单位的排版参数及实际尺寸检查结果。
50_Adobe生产：按软件局部规则与 Adobe 协作指南执行，交付源文件、导出和验收记录，不把端口在线等同于文档已处理。
60_Codex与Skills：按 VISUAL_SKILL_ARCHITECTURE.md、AIGC_CREATIVE_RULES.md 维护源 Skill、验证和分发；仓库维护遵守本地 AGENTS.md。
70_动态视觉：从已确认静态母版继承 LOCKED，分别定义 H1/H2/H3 与 M1/M2/M3，锁定时长、帧率、循环、首尾帧、音频与镜头许可；按 motion 路由验收，扁平图测试不冒充完整分层动画。
90_规范沉淀与复盘：核查证据后选择补原规范、保留实验、晋级 Prompt/工作流/Skill；保留正反样本、来源、边界和人工结论，不重复造规范。
只在任务匹配且当前宿主实际可见时调用对应 Skill；先看名称/描述，再按需读取入口和依赖。上传 SKILL.md 是提供参考资料，不证明已安装或可执行。当前静态花卉为 initial-example 测试能力；动态花卉仅有工程化初始源 Skill，均不得宣称已通过正式生产门禁。跨模块任务以主要成果为主线，按需调用其他专业，不要求用户反复换聊天。

六、交付与沉淀
先展示结果，再简述修改、验证和未完成项。跨端交接只保留：目标、素材位置、锁定条件、已确认方案、输出规格、待办；本地原文件负责维护，云端来源为带版本的同步副本，不假定自动更新。上传缺失依赖前先说明具体需要哪份；不声称已读取不可访问的文件。
本地 GitHub 操作只走当前电脑已验证代理，失败停止且不直连；只在用户明确授权时提交或推送，不重复用户已完成的发布。普通设计任务不反复展示工程规则。
```

## 按工作台接入规范与 Skill

- 本地 Codex：先读根 `AGENTS.md`，再按上方八模块映射加载本任务的原文件；视觉任务进入 `AI_Skills/Graphic_Design/AGENTS.md`，生产任务追加软件局部规则。路径导航不会自动安装 Skill。
- ChatGPT Project：通过总指令中的八模块职责匹配当前聊天；以实际上传的项目来源为依据，不假定能读本机目录。不存在或未启用的 Skill 不得伪称已调用；先按已提供规则处理可完成部分。
- 当前可安装的静态花卉测试 Skill 使用 `floral-texture-poster` 原 ID；工作流评审使用 `promote-creative-workflow`。动态源 Skill 尚未安装分发。品牌、通用海报、排印和 Adobe 生产主要接入规则路由，不为“八模块齐全”新增八个 Skill。
- 模块职责相同的既有初始化无需重发；Project 层的最新已确认路径与规则用于修正历史路径。后续只有模块自身新增专属决策时，才在对应聊天中追加。

## 云端来源同步清单

同步日期：2026-09-07（用户确认上一版已同步）；文件版本：VISUAL_WORKBENCH.md v2.0 / 2026-09-10（本次待同步）；变更摘要：按官方 Image prompting 全面替换旧提示框架，更新 Project 总指令、生图模板和准确文字策略。本次仅修订本地维护源，尚未上传云端。

本次待同步来源仅为：

- `VISUAL_WORKBENCH.md`：更新来源文件及项目“指令”字段，使用上方 2.0 正文。
- `Prompt_Framework.md`：替换为视觉任务与生图提示编写指南 2.0。
- `平面设计生图与动态视觉规范.md`：更新文字策略及提示指南引用。
- `image-generation.md`：更新提示流程、工具设置边界与官方依据。
- `typography.md`：更新图内准确文字与可控后期的职责。
- `VISUAL_SKILL_ARCHITECTURE.md`：明确内部判断步骤不强制展示，负面约束仅按需使用。

下面保留完整来源登记，供查找既有维护位置；未变文件不属于本次同步。自建花卉 Skill 及依赖如已单独上传，才按本次实际差异更新其云端副本，不视为已完成上传或安装。

同步时使用登记的现有原文件，不创建同义规范；只更新内容发生变化的来源，未变文件不重复上传。每次同步在本行记录涉及文件的版本与变更摘要；待同步时保留上次完成日期，确认完成后再更新同步日期与状态。用同名新版本替换项目副本，并刷新复核文件名及关键内容。文件名不同的来源分别负责不同层级，不能互相当作替代。

| 文件 | 维护位置 | 云端作用 |
| --- | --- | --- |
| VISUAL_WORKBENCH.md | `docs/VISUAL_WORKBENCH.md` | 总指令、模块边界和路径导航 |
| Prompt_Framework.md | `AI_Skills/Graphic_Design/references/Prompt_Framework.md` | 视觉任务整理、生图提示原则与可裁剪模板 |
| 平面设计生图与动态视觉规范.md | `AI_Skills/Graphic_Design/references/平面设计生图与动态视觉规范.md` | 跨任务视觉原则 |
| image-generation.md | `AI_Skills/Graphic_Design/references/routes/production/image-generation.md` | ChatGPT Images 专业流程 |
| typography.md | `AI_Skills/Graphic_Design/references/shared/typography.md` | 中文优先排印细则 |
| ADOBE_AUTOMATION_GUIDE.md | `scripts/common/docs/ADOBE_AUTOMATION_GUIDE.md` | Codex + Adobe 执行与验收 |
| VISUAL_SKILL_ARCHITECTURE.md | `AI_Skills/Graphic_Design/standards/VISUAL_SKILL_ARCHITECTURE.md` | Skill 工程标准 |
| AIGC_CREATIVE_RULES.md | `docs/AIGC_CREATIVE_RULES.md` | 创意训练、测试分发与晋级 |
| creative_capability_promotion.md | `workflows/creative_capability_promotion.md` | 规范沉淀与评审流程 |

任务进一步涉及某个未上传路由、品牌手册或源 Skill 时，再上传对应原文件与必要依赖；不要全量复制插件缓存、日志或客户资料。上传参考文件不等于安装 Skill，也不授予本机操作权限。

## 提示词修订交接

2026-09-10 / 2.1：在本地 2.0 版上增补 RCE 上层边界、六段助记顺序和 pixel-identical 确定性合成验收，保留已有四类提示模板。Prompt_Framework.md 继续维护提示写法；image-generation.md 维护执行与文件验收；AIGC_CREATIVE_RULES.md 维护实验记录要求。

本次已合并本地维护源及仓库插件分发副本；云端文件和 Project 指令尚待替换核对，只同步本次变更文件。八模块旧命名与当前会话九模块的差异留待独立维护，不与提示词修订混合。

## 官方依据

2026-09-10 核对：[OpenAI Image prompting](https://developers.openai.com/api/docs/guides/image-prompting)。提示原则的工作台应用维护在原 `Prompt_Framework.md`；本次不迁移模型或复制 API 参数表。

2026-09-07 核对：[Project 与聊天](https://learn.chatgpt.com/docs/projects)、[图像生成](https://learn.chatgpt.com/docs/image-generation)、[Skill 加载与调用](https://learn.chatgpt.com/docs/build-skills)、[AGENTS.md 分层](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。本表与八模块职责是工作台约定；具体产品权限、入口和能力以当前宿主实际提供为准。
