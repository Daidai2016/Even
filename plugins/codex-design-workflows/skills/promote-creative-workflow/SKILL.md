---
name: promote-creative-workflow
description: Promote a Codex Design AIGC experiment into a reviewed prompt, validated workflow, or reusable skill. Use when evaluating content under experiments, deciding whether creative results are stable enough for prompts or workflows, documenting quality evidence, or packaging a repeatable creative-production method without overstating validation.
---

# Promote creative workflow

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
