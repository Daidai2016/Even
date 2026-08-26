#!/usr/bin/env python3
"""验证 Graphic Design 视觉 Skill 的结构、路由引用与测试矩阵。"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path


REQUIRED_SECTIONS = {
    "边界": ("边界", "boundary"),
    "触发": ("触发", "trigger"),
    "输入": ("输入", "input"),
    "参数": ("参数", "parameters"),
    "路由": ("路由", "routes"),
    "工作流": ("工作流", "workflow"),
    "输出": ("输出", "output"),
    "审计": ("审计", "audit"),
}

REQUIRED_ARCHITECTURE_FILES = [
    "standards/VISUAL_SKILL_ARCHITECTURE.md",
    "references/shared/hierarchy.md",
    "references/shared/composition.md",
    "references/shared/typography.md",
    "references/shared/color.md",
    "references/shared/texture.md",
    "references/shared/subject.md",
    "references/shared/parameter-lock.md",
    "references/shared/conflict-resolution.md",
    "references/shared/audit.md",
    "references/routes/task/material-redraw.md",
    "references/routes/task/poster-design.md",
    "references/routes/task/motion-poster.md",
    "references/routes/task/optimization.md",
    "references/routes/task/diagnosis.md",
    "references/routes/style/texture-graphic.md",
    "references/routes/production/image-generation.md",
    "references/routes/production/photoshop.md",
    "references/routes/production/illustrator.md",
    "references/routes/production/after-effects.md",
    "references/routes/motion/motion-hierarchy.md",
    "references/routes/motion/timing.md",
    "references/routes/motion/transition.md",
    "references/routes/motion/loop.md",
    "references/routes/motion/audit.md",
]


@dataclass
class Result:
    level: str
    scope: str
    message: str


class Reporter:
    def __init__(self) -> None:
        self.results: list[Result] = []

    def add(self, level: str, scope: str, message: str) -> None:
        self.results.append(Result(level, scope, message))
        print(f"[{level}] {scope}: {message}")

    def pass_(self, scope: str, message: str) -> None:
        self.add("PASS", scope, message)

    def warn(self, scope: str, message: str) -> None:
        self.add("WARN", scope, message)

    def fail(self, scope: str, message: str) -> None:
        self.add("FAIL", scope, message)

    def summary(self) -> dict[str, int]:
        counts = {level: 0 for level in ("PASS", "WARN", "FAIL")}
        for result in self.results:
            counts[result.level] += 1
        return counts


def read_utf8(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_frontmatter(content: str) -> tuple[dict[str, object], str]:
    """解析本仓库使用的简单 YAML 映射；无需第三方 YAML 依赖。"""
    match = re.match(r"\A---\r?\n(.*?)\r?\n---\r?\n", content, re.DOTALL)
    if not match:
        raise ValueError("缺少或无法识别 YAML frontmatter 边界")

    data: dict[str, object] = {}
    current_mapping: dict[str, str] | None = None
    for number, raw_line in enumerate(match.group(1).splitlines(), start=2):
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        if "\t" in raw_line:
            raise ValueError(f"第 {number} 行包含 Tab 缩进")

        indent = len(raw_line) - len(raw_line.lstrip(" "))
        line = raw_line.strip()
        if ":" not in line:
            raise ValueError(f"第 {number} 行不是 key: value 映射")
        key, value = line.split(":", 1)
        key, value = key.strip(), value.strip()
        if not key:
            raise ValueError(f"第 {number} 行键名为空")

        if indent == 0:
            if not value:
                current_mapping = {}
                data[key] = current_mapping
            else:
                current_mapping = None
                data[key] = value.strip("\"'")
        else:
            if indent % 2:
                raise ValueError(f"第 {number} 行缩进不是 2 的倍数")
            if current_mapping is None:
                raise ValueError(f"第 {number} 行存在无父级的嵌套字段")
            current_mapping[key] = value.strip("\"'")
    return data, content[match.end():]


def has_heading(body: str, aliases: tuple[str, ...]) -> bool:
    for line in body.splitlines():
        if not re.match(r"^#{2,6}\s+", line):
            continue
        normalized = line.lower()
        if any(alias.lower() in normalized for alias in aliases):
            return True
    return False


def local_markdown_links(body: str) -> list[str]:
    links: list[str] = []
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", body):
        target = target.strip().strip("<>").split("#", 1)[0]
        if not target or target.startswith("#"):
            continue
        if re.match(r"^[a-z][a-z0-9+.-]*://", target, re.IGNORECASE):
            continue
        links.append(target.replace("/", str(Path("/")).replace("/", "\\") if sys.platform == "win32" else "/"))
    return links


def ordered_priority_present(body: str) -> bool:
    pattern = re.compile(
        r"用户显式参数\s*>\s*品牌/项目硬约束\s*>\s*Skill 专属规则\s*>\s*"
        r"(?:(?:当前命中的(?:动态)?路由(?:规则)?|当前命中的路由规则)\s*>\s*)?"
        r"(?:静态父 Skill\s*>\s*)?共享规则\s*>\s*默认值"
    )
    return bool(pattern.search(body))


def validate_test_matrix(skill_dir: Path, skill_name: str, reporter: Reporter) -> None:
    scope = f"{skill_name}/tests"
    tests_dir = skill_dir / "tests"
    if not tests_dir.is_dir():
        reporter.fail(scope, "缺少 tests 目录")
        return
    matrix_path = tests_dir / "test-matrix.json"
    if not matrix_path.is_file():
        reporter.fail(scope, "缺少 test-matrix.json")
        return
    try:
        matrix = json.loads(read_utf8(matrix_path))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        reporter.fail(scope, f"测试矩阵无法按 UTF-8 JSON 解析：{exc}")
        return

    if matrix.get("skill") != skill_name:
        reporter.fail(scope, "测试矩阵 skill 与 frontmatter name 不一致")
    else:
        reporter.pass_(scope, "测试矩阵归属正确")

    cases = matrix.get("cases")
    if not isinstance(cases, list):
        reporter.fail(scope, "cases 必须是数组")
        return
    ids = {case.get("id") for case in cases if isinstance(case, dict)}
    expected_ids = {f"T{number:02d}" for number in range(1, 21)}
    missing = sorted(expected_ids - ids)
    extra = sorted(ids - expected_ids)
    if missing or extra or len(cases) != 20:
        reporter.fail(scope, f"T01-T20 不完整；缺少={missing}，额外={extra}，数量={len(cases)}")
    else:
        reporter.pass_(scope, "T01-T20 共 20 条结构化用例完整")

    trigger_cases = {case.get("id"): case for case in cases if isinstance(case, dict)}
    if all(isinstance(trigger_cases.get(test_id, {}).get("expected_trigger"), bool) for test_id in ("T01", "T02", "T03")):
        reporter.pass_(scope, "直接点名、自然语言、模糊表达均记录触发预期")
    else:
        reporter.fail(scope, "T01-T03 必须记录布尔 expected_trigger")


def validate_skill(skill_dir: Path, reporter: Reporter) -> None:
    scope = skill_dir.name
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        reporter.fail(scope, "SKILL.md 不存在")
        return
    reporter.pass_(scope, "SKILL.md 存在")

    try:
        content = read_utf8(skill_md)
        frontmatter, body = parse_frontmatter(content)
    except (UnicodeDecodeError, ValueError) as exc:
        reporter.fail(scope, f"frontmatter 无法解析：{exc}")
        return
    reporter.pass_(scope, "YAML frontmatter 可解析")

    name = frontmatter.get("name")
    description = frontmatter.get("description")
    if isinstance(name, str) and name and re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        reporter.pass_(scope, "name 存在且为小写连字符格式")
    else:
        reporter.fail(scope, "name 缺失或格式无效")
        name = scope
    if name != skill_dir.name:
        reporter.fail(scope, f"目录名与 name 不一致：{name}")

    if isinstance(description, str) and description.strip():
        if any(word in description for word in ("专业强大", "万能", "顶级", "一键高级")):
            reporter.warn(scope, "description 可能包含宣传语，请改为能力与场景")
        else:
            reporter.pass_(scope, "description 存在且未命中常见宣传语")
    else:
        reporter.fail(scope, "description 缺失")

    missing_sections = [label for label, aliases in REQUIRED_SECTIONS.items() if not has_heading(body, aliases)]
    if missing_sections:
        reporter.fail(scope, f"缺少必需章节：{', '.join(missing_sections)}")
    else:
        reporter.pass_(scope, "边界/触发/输入/参数/路由/工作流/输出/审计章节完整")

    if "LOCKED" in body and any(phrase in body for phrase in ("不得擅自", "不得让", "不能覆盖")):
        reporter.pass_(scope, "定义 LOCKED 且禁止擅自修改")
    else:
        reporter.fail(scope, "未完整定义 LOCKED 保护规则")

    if ordered_priority_present(body):
        reporter.pass_(scope, "冲突优先级顺序正确")
    else:
        reporter.fail(scope, "未按用户 > 品牌/项目 > Skill > 共享 > 默认定义优先级")

    broken_links: list[str] = []
    links = local_markdown_links(body)
    for target in links:
        if not (skill_dir / target).resolve().exists():
            broken_links.append(target)
    if broken_links:
        reporter.fail(scope, f"引用路径失效：{broken_links}")
    elif links:
        reporter.pass_(scope, f"本地引用路径全部有效（{len(links)} 个）")
    else:
        reporter.warn(scope, "SKILL.md 未发现本地 Markdown 引用")

    if (skill_dir / "references").is_dir():
        reporter.pass_(scope, "Skill 专属 references 目录存在")
    else:
        reporter.warn(scope, "Skill 无专属 references；确认是否完全由共享规则覆盖")

    if (skill_dir / "agents" / "openai.yaml").is_file():
        reporter.pass_(scope, "agents/openai.yaml 存在")
    else:
        reporter.fail(scope, "缺少 agents/openai.yaml")

    validate_test_matrix(skill_dir, str(name), reporter)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="验证视觉 Skill 架构")
    parser.add_argument("--root", type=Path, help="Graphic_Design 根目录；默认取脚本上一级的上一级")
    args = parser.parse_args()
    root = (args.root or Path(__file__).resolve().parents[1]).resolve()
    reporter = Reporter()

    print(f"视觉 Skill 验证根目录：{root}")
    for relative in REQUIRED_ARCHITECTURE_FILES:
        path = root / relative
        if path.is_file():
            reporter.pass_("architecture", f"存在 {relative}")
        else:
            reporter.fail("architecture", f"缺少 {relative}")

    skills_dir = root / "skills"
    skill_dirs = sorted(path.parent for path in skills_dir.glob("*/SKILL.md")) if skills_dir.is_dir() else []
    if not skill_dirs:
        reporter.fail("skills", "未发现任何 skills/*/SKILL.md")
    else:
        reporter.pass_("skills", f"发现 {len(skill_dirs)} 个 Skill")
        for skill_dir in skill_dirs:
            validate_skill(skill_dir, reporter)

    counts = reporter.summary()
    print("\n=== 汇总 ===")
    print(f"PASS={counts['PASS']} WARN={counts['WARN']} FAIL={counts['FAIL']}")
    return 1 if counts["FAIL"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
