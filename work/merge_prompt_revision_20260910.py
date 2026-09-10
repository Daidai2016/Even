from pathlib import Path
import json, shutil

root = Path(__file__).resolve().parents[1]
delivery = Path('C:/Users/SUMAI/.codex/.chatgpt-projects/g-p-6a9e53f409188191a673bfffefb9ae38/outputs/prompt-revision-2026-09-10')
paths = ['AI_Skills/Graphic_Design/references/Prompt_Framework.md', 'AI_Skills/Graphic_Design/references/routes/production/image-generation.md', 'docs/VISUAL_WORKBENCH.md', 'docs/AIGC_CREATIVE_RULES.md']
texts = {p:(root/p).read_text(encoding='utf-8-sig') for p in paths}
def sub(p,a,b):
    assert texts[p].count(a)==1,(p,a)
    texts[p]=texts[p].replace(a,b)

p=paths[0]
sub(p,'版本：2.0 / 2026-09-10','版本：2.1 / 2026-09-10')
sub(p,'## 2. 编写原则','''### 1.1 RCE 上层任务契约与实际 Prompt

保留 RCE（Role–Constraints–Examples，角色—约束—示例）作为上层任务契约：R 只记录影响本次判断的职责，C 记录目标、硬锁、允许变化与交付验收，E 记录参考来源、用途和边界。简单任务可在内部完成这些判断，不要求展示角色、契约或完整分析；复杂任务需要交接时再明确列出。

实际提交给 GPT Image 的 Prompt 描述本轮画面，不照搬 RCE 全文、履历、仓库操作或审核流程。工具参数和后期制作清单分开记录。H1/H2/H3 应转成位置、比例和阅读关系；LOCKED 应转成具体保留项，不能因简化提示而遗漏。

OpenAI 官方 Image Prompting 指南是 GPT Image 实际提示词写法的最高专业依据；RCE 负责本次任务边界与验收，两者职责不同。第 4 节四类模板继续用于实际 Prompt，不作为 RCE 固定格式。

## 2. 编写原则''')
sub(p,'## 3. 约束、文字与设置','''### 2.1 六段组织顺序

**Result → Subject → Composition → Visible Details → Style/Medium → Constraints**

这是工作台根据官方原则整理的助记顺序，并非官方命名框架或强制语法；按任务删减，不必逐段输出。

| 部分 | 需要表达的画面要求 |
| --- | --- |
| Result｜结果 | 图像类型、用途、画幅与交付阶段 |
| Subject｜主体 | 对象、数量、身份、动作及入画范围 |
| Composition｜构图 | 位置、比例、视角、裁切、空间关系、留白与文字安全区 |
| Visible Details｜可见细节 | 形态、纹理、材质、颜色与光线 |
| Style/Medium｜风格与媒介 | 摄影、插画、纸张丝印、三维等表现方式 |
| Constraints｜约束 | 准确文案、保留项、修改边界、禁止项与目标输出 |

第 4 节已有新建、参考、编辑和合成模板按此思路裁剪，无需增加第二套模板。

## 3. 约束、文字与设置''')
sub(p,'每轮修改一个问题或一组相关问题，重申关键保留项并检查结果。','默认每轮只改一个明确变量；确需联动时记录整组范围与原因，重申关键保留项并检查结果。')
sub(p,'有此要求时，在原图上可控合成已批准修改，并对保护区作差异核验。','要求 pixel-identical 时，必须在原图上确定性合成已批准修改，再按[生图生产路由第 3.1 节](routes/production/image-generation.md)对保护区作逐像素核验。')

p=paths[1]
sub(p,'极严格的像素保留宜在原图上用可控蒙版/图层合成验收，不能承诺生成过程绝对不影响选区外。','要求 pixel-identical 时必须按第 3.1 节确定性合成并验收，不能承诺生成过程绝对不影响选区外。')
old=(delivery/'image-generation.md').read_text(encoding='utf-8')
pixel=old[old.index('### 3.5 pixel-identical'):old.index('## 4. 生成、选择与返修')].replace('### 3.5','### 3.1')
sub(p,'## 4. 生成、选择与返修',pixel+'## 4. 生成、选择与返修')
sub(p,'4. 沿用已确认版本，每次修改一个明确问题或同一组相关问题；重申保留项，禁止悄悄换底图。','4. 将上一轮已确认输出作为下一轮输入，默认每轮只改一个明确变量；确需联动时记录整组范围与原因。重申保留项，先比较结果再补充指令，禁止悄悄换底图。')
sub(p,'5. 修改保护区域附近内容后，对照原图检查边缘、位置、文字安全区和品牌资产；有像素保留要求时在相同尺寸、色彩条件下核对区域差异。','5. 记录输入/输出版本、实际 Prompt、参数、本轮变量和通过/失败原因；对照原图检查边缘、位置、文字安全区和品牌资产。pixel-identical 按第 3.1 节验收。')

p=paths[2]
sub(p,'版本：2026-09-10 / 2.0。','版本：2026-09-10 / 2.1。')
sub(p,'直接明确目标、受众、媒介、约束和各参考图用途；简单任务直接给可用提示，不强制角色设定、契约或完整分析。','保留 RCE 作为上层任务契约，明确目标、受众、媒介、约束和各参考图用途；简单任务直接给可用提示，不强制展示角色、契约或完整分析。')
sub(p,'四类可裁剪模板沿用 Prompt_Framework.md。','六段组织顺序及四类可裁剪模板沿用 Prompt_Framework.md。六段顺序是工作台助记，实际 Prompt 与 RCE 分开，不是官方强制语法。')
sub(p,'## 官方依据','''## 提示词修订交接

2026-09-10 / 2.1：在本地 2.0 版上增补 RCE 上层边界、六段助记顺序和 pixel-identical 确定性合成验收，保留已有四类提示模板。Prompt_Framework.md 继续维护提示写法；image-generation.md 维护执行与文件验收；AIGC_CREATIVE_RULES.md 维护实验记录要求。

本次已合并本地维护源及仓库插件分发副本；云端文件和 Project 指令尚待替换核对，只同步本次变更文件。八模块旧命名与当前会话九模块的差异留待独立维护，不与提示词修订混合。

## 官方依据''')

p=paths[3]
training=(delivery/'AIGC_CREATIVE_RULES.md').read_text(encoding='utf-8')
training=training[training.index('### 3.1 图像提示词'):training.index('## 4. Skill 结构')]
training=training.replace('RCE 任务契约继续维护在 `AI_Skills/Graphic_Design/references/Prompt_Framework.md`；GPT Image 实际提示词写法继续维护在 `AI_Skills/Graphic_Design/references/routes/production/image-generation.md`，以其中登记的 OpenAI 官方指南为专业依据。','RCE 上层任务契约边界与 GPT Image 实际提示词写法继续维护在 `AI_Skills/Graphic_Design/references/Prompt_Framework.md`；执行和文件验收维护在 `AI_Skills/Graphic_Design/references/routes/production/image-generation.md`，以原文件登记的 OpenAI 官方指南为专业依据。')
sub(p,'## 4. Skill 结构',training+'## 4. Skill 结构')

for p,t in texts.items():
    assert t.count('```')%2==0
    (root/p).write_text(t,encoding='utf-8',newline='\n')
for p in paths[:2]:
    target=p.replace('AI_Skills/Graphic_Design/','plugins/codex-design-visuals/')
    shutil.copyfile(root/p,root/target)
p=root/'plugins/codex-design-visuals/.codex-plugin/plugin.json'
t=p.read_text(encoding='utf-8')
assert t.count('"version": "0.6.1"')==1
p.write_text(t.replace('"version": "0.6.1"','"version": "0.6.2"'),encoding='utf-8',newline='\n')
print('Merged four sources, synchronized two distribution references; plugin 0.6.2')
