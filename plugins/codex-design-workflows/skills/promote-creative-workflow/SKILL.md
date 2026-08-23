---
name: promote-creative-workflow
description: 评审 Codex Design 的 AIGC 实验，并将证据充分的内容晋级为提示词、已验证工作流或可复用 Skill。适用于检查 experiments 下的实验、判断创意结果是否稳定、记录质量证据和封装可重复的创意生产方法；不得夸大验证状态。
---

# 创意实验评审与能力晋级

Keep experimental evidence separate from formal assets. Never describe a direction as validated without representative outputs and human visual review.

## Process

1. Read the repository `AGENTS.md`, `docs/AIGC_CREATIVE_RULES.md`, and `workflows/creative_capability_promotion.md`.
2. Confirm the experiment records its goal, inputs, model or tool, parameters, outputs, evaluation results, rights status, and known failure cases.
3. Review representative positive and negative samples using the quality gates in `references/quality-gates.md`.
4. Choose exactly one outcome:
   - keep under `experiments/` when evidence is incomplete;
   - promote only the reusable prompt to `prompts/`;
   - promote a stable sequence to `workflows/`;
   - package a narrow, repeatable, well-bounded method as a skill.
5. Preserve source attribution and link the promoted artifact back to its experiment evidence.
6. Run `scripts/validate-promotion.ps1` after creating or updating the formal prompt or workflow file selected for this promotion.
7. Report what was promoted, evidence reviewed, remaining limitations, and manual visual checks still required.

Do not combine aesthetic, layout, typography, formal creativity, and tool automation into one unbounded skill. Do not move or delete source experiments during promotion.
