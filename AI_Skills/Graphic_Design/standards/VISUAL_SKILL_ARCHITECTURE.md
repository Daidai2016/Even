# Visual Skill Architecture v1.0

本规范定义 `AI_Skills/Graphic_Design/` 下视觉类 Skill 的工程结构、参数语义、路由方式、审计与发布闭环。它约束 Skill 如何做判断，不把视觉创作退化为超长 Prompt。

## 1. 适用范围与优先级

适用于平面视觉、静态素材、海报、KV、动态海报及其创建、优化和诊断。单个 Skill 必须声明能做什么、不能做什么、输入与输出，不得无边界合并品牌、空间、文案、动效和工具自动化。

冲突优先级固定为：

```text
用户显式参数
> 品牌 / 项目硬约束
> Skill 专属规则
> 当前命中的路由规则
> 共享规则
> 默认值
```

前四级中已确认且不可改写的值标为 `LOCKED`。低级规则不能覆盖高级规则；如冲突无法同时满足，保留 `LOCKED` 并说明取舍，不得静默修改。

## 2. 最小骨架与渐进披露

```text
<skill-name>/
├── SKILL.md
├── agents/openai.yaml
├── references/       # 仅该 Skill 独有的领域规则
└── tests/            # 结构化触发与回归用例
```

`SKILL.md` 只承担边界、触发、输入、参数、路由、工作流、输出和审计。共享规则放在 `references/shared/`，条件规则放在 `references/routes/`。只有当前任务命中的 Task、Style、Production、Motion 路由才读取，禁止每次全量加载。

## 3. Frontmatter 与触发

`name` 使用稳定的小写英文连字符 ID，并与目录名一致。`description` 用“能做什么 + 适用场景 + 必要边界”描述真实能力，不使用“专业、强大、高级、万能”等宣传语。

每个 Skill 至少维护三类触发测试：直接点名、自然语言、模糊表达。测试应记录预期是否触发；模糊表达只有在主要任务仍落入 Skill 边界时才触发。

## 4. 设计语义层

用户需求先解析为九个维度，再选择规则和生产方式：

| 维度 | 必须回答的问题 |
| --- | --- |
| Task | 创建、优化、诊断，还是 material_redraw / poster / motion_poster 等具体任务？ |
| Content | 哪些标题、正文、Logo、产品、数据和 CTA 必须原样保留？ |
| Hierarchy | H1/H2/H3 分别是什么，阅读顺序是否与传播目标一致？ |
| Composition | 主体位置、结构、密度、方向、裁切和留白是什么？ |
| Typography | 中文标题、中文正文、西文标题、西文正文、数字、Display Typography 各承担什么职责？ |
| Color | 主色、辅色、强调色、中性色、背景色、文字色及品牌色约束是什么？ |
| Material | 肌理类型、粒度、密度、覆盖区域和对比度是什么？ |
| Motion | M1/M2/M3、元素运动、镜头运动、节奏、转场和循环是什么？ |
| Output | 最终进入生图、Photoshop、Illustrator、After Effects 或其他生产环节？ |

中文设计语境优先。不得用西文 Serif/Sans 分类替代完整字体系统；中文标题与正文必须分别评估字形气质、字面率、字重、字号、字距、行距和阅读密度。

## 5. 参数状态

每个关键参数记录 `value`、`source` 与 `state`：

```yaml
aspect_ratio:
  value: "9:16"
  source: user
  state: LOCKED
```

- 用户明确值：`source: user`，`state: LOCKED`。
- 品牌或项目硬约束：`source: brand|project`，通常为 `LOCKED`。
- 合理推断：`source: inferred`，`state: FLEXIBLE`，必须可追溯。
- Skill 默认：`source: default`，`state: FLEXIBLE`，用户未指定时才成立。

常见硬锁包括主体、颜色、画幅、背景、材质、准确文字、Logo、字体、构图方向、输出格式，以及动态项目的时长、帧率、节奏、循环、转场、首尾帧和镜头许可。

## 6. 可执行规则

规则必须能落到可观察条件，并给出 `PASS / WARNING / FAIL`：

```text
Rule → Observable Condition → PASS | WARNING | FAIL
```

例如“层级清晰”应能指出 H1/H2/H3；“有肌理”应声明类型、粒度、密度、覆盖和对比；“有张力”应能说明偏心、方向、尺度级差及疏密对比。不能只写“高级、丰富、有设计感”。

## 7. 三层路由与动态扩展

```text
Task Router → Style Router → Production Router
                                  ↓
                           Motion Router（按需）
```

- Task 决定要解决的问题。
- Style 只选择当前明确或合理推断的一种主风格，防止风格串味。
- Production 决定图层、路径、分辨率、色彩空间、时间轴和可编辑性要求。
- Motion 仅对动态任务加载；静态任务不得读取动态规则。

动态 Skill 继承静态视觉规则，但必须区分 H1/H2/H3 与 M1/M2/M3。元素运动不等于镜头运动；镜头运动只有在用户允许且具有明确叙事或空间目的时才启用。

## 8. 固定工作流

```text
RECEIVE → BOUNDARY → PARSE → LOCK → CONFLICT
→ TASK ROUTE → STYLE ROUTE → PRODUCTION ROUTE → LOAD
→ HIERARCHY → COMPOSITION → SUBJECT → TYPOGRAPHY
→ COLOR → MATERIAL → MOTION（按需）
→ GENERATE → NEGATIVE → AUDIT → REPAIR → OUTPUT
```

创建、优化和诊断共享前半段。优化必须先列出保留项与修改项；诊断先分类失败，不得在未定位原因时直接重做。

## 9. 审计系统

交付前至少执行：Requirement、Lock、Hierarchy、Composition、Typography、Color、Style、Production 八类审计；动态任务再执行 Motion Audit。

- `PASS`：满足全部硬约束且无阻断问题。
- `WARNING`：硬约束满足，但存在需人工确认或生产风险。
- `FAIL`：任一 `LOCKED` 被改写、关键内容错误、路由错误或输出不可用于目标生产环境。

发生 `FAIL` 时先修复失败项，再继续美化。审计结果应列出证据、影响和下一步。

## 10. Failure Taxonomy

| 代码 | 类型 | 典型表现 |
| --- | --- | --- |
| E01_BOUNDARY | 边界 | 错接不属于当前 Skill 的任务 |
| E02_TRIGGER | 触发 | 应触发未触发，或误触发 |
| E03_PARAMETER | 参数 | 参数缺失、来源不明或概念混淆 |
| E04_LOCK | 硬锁 | 改写画幅、品牌色、文案等 `LOCKED` |
| E05_ROUTER | 路由 | Task/Style/Production/Motion 选择错误 |
| E06_HIERARCHY | 层级 | H1/H2/H3 竞争或阅读顺序错误 |
| E07_COMPOSITION | 构图 | 安全区、裁切、留白或密度失控 |
| E08_TYPOGRAPHY | 字体 | 中文/西文/数字职责混乱或不可读 |
| E09_COLOR | 色彩 | 对比不足、角色混乱或品牌色漂移 |
| E10_TEXTURE | 肌理 | 颗粒变噪点、材质污染内容 |
| E11_STYLE | 风格 | 多路由串味或主体与背景语言不一致 |
| E12_OUTPUT | 输出 | 尺寸、格式、图层、帧率等不合要求 |
| E13_AUDIT | 审计 | 未发现或未修复明确失败 |

## 11. 测试矩阵

每个 Skill 至少覆盖 T01–T20：直接点名、自然语言、模糊需求、一句话创建、完整参数创建、优化、诊断、参数硬锁、参数冲突、9:16、16:9、超宽、中文标题、中西文混排、标题 H1、主体 H1、品牌色硬锁、风格串味、精简输出和完整专业输出。

结构测试验证入口、引用和不变量；真实视觉质量仍需代表性素材、目标尺寸输出和人工评审。不得把脚本通过等同于视觉质量通过。

## 12. 发布闭环

1. 运行仓库视觉 Skill 验证脚本与 `skill-creator` 的 `quick_validate.py`。
2. 修复失效引用、缺失章节和测试缺口。
3. 使用代表性输入做创建、优化、诊断和边界人工测试。
4. 记录字体授权、素材权利、品牌准确性、印刷或视频生产风险。
5. 在干净环境重新安装或加载，验证三类触发和引用可达。
6. 只有证据充分时才从 `initial-example` 晋级为正式能力；已登记本地测试分发沿用仓库 `docs/AIGC_CREATIVE_RULES.md` 第 8.1 节，不改变验证状态。源 Skill、插件入口、元数据和引用依赖须保持一致。
7. 发布前更新使用者入口和版本记录。GitHub 发布仍遵循仓库授权与代理规则。
