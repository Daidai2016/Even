# Graphic Design Skill 管理规则

本文件适用于 `AI_Skills/Graphic_Design/` 及其全部子目录，并继承仓库根目录 `AGENTS.md`、`CODING_RULES.md` 与 `docs/AIGC_CREATIVE_RULES.md`。

## 1. 任务入口

处理本目录覆盖的平面视觉或动态视觉任务时：

1. 先读取任务调用规范 `references/Prompt_Framework.md`，把用户需求整理为可执行的 RCE 任务契约。
2. 再读取共享规范 `references/平面设计生图与动态视觉规范.md`。
3. 读取与任务匹配的 `skills/<skill-name>/SKILL.md`。
4. 按该入口的路由读取必要 `references/`；不要无差别加载其他 Skill。
5. 用户当前明确要求、真实品牌规范和已授权资产的优先级高于默认规则。

## 2. 目录职责

```text
Graphic_Design/
├── AGENTS.md                  本分类的继承与管理规则
├── references/               所有视觉 Skill 共用的任务协议与视觉规则来源
└── skills/
    └── <skill-name>/
        ├── SKILL.md           标准 Skill 入口、边界与工作流
        ├── agents/openai.yaml UI 名称和默认调用提示
        └── references/        仅该 Skill 需要的详细规则与模板
```

新增 Skill 使用小写英文连字符目录名，入口固定为 `SKILL.md`。完整模板和示例可放在 `references/` 中。没有实际用途的空目录、README、脚本或资产不得创建。

### 2.1 中文命名与界面元数据

- Skill 目录名、frontmatter `name`、继承字段和 `$skill-name` 使用一致的英文内部 ID，不得改成中文。
- 每个视觉 Skill 必须提供 `agents/openai.yaml`，并使用中文 `display_name`、中文 `short_description` 和中文 `default_prompt`。
- `display_name` 应直接说明视觉任务，例如“花卉图片转肌理质感素材”；不得使用“工具一”“海报助手”等无法判断边界的名称。
- `short_description` 应说明输入、主要处理或输出，让设计师在 Skill 列表中快速判断用途。
- `default_prompt` 必须包含准确的英文 `$skill-name`，其余内容使用自然中文。
- 源 Skill 与插件副本的 `agents/openai.yaml` 必须一致；更新插件副本后递增插件版本并重新安装验证。
- 界面中文化不得改变 Skill 的验证状态，也不得把 `initial-example` 自动视为已验证正式能力。

## 3. 继承规则

- `references/Prompt_Framework.md` 只定义 RCE 任务契约、输入澄清、约束优先级与输出结构；不重复具体 Skill 的领域方法、生成参数或验证状态。
- 通用 Design Goal、Input、Design Analysis、Visual Language、Visual Composition、Visual Hierarchy、Typography、Color System、Static Image、Motion Design、MG Animation、Logo Meaning Animation、Output、Forbidden 和 Quality Check 只在共享规范维护。
- 具体 Skill 只定义该任务特有的触发范围、输入、步骤、变量、Prompt、失败条件与人工审核点。
- 动态延展 Skill 必须声明并读取其静态父 Skill；冲突时按“用户要求 > 动态专用规则 > 静态父 Skill > 共享规范”处理。
- 不得把视觉层级固定为“主体永远高于标题”；第一视觉由传播目标决定。
- 涉及准确文字、Logo、品牌色、人物、产品和数据时，不得让生成模型擅自改写。

## 4. 验证与晋级

- 新方向先在仓库 `experiments/` 留下目标、输入、参数、正反样本、人工评价、授权状态和失败边界。
- 没有代表性样本与人工视觉评审时，Skill 必须标记为初始示例或实验，不得宣称已验证或可直接作为品牌生产标准。
- 通过多样例复测后，更新版本与实验记录；需要进入可安装插件时，再按仓库的插件市场与晋级流程封装。
- 交付前运行 Skill 结构校验和仓库验证，并报告未完成的视觉、字体、版权、印刷或视频检查。
