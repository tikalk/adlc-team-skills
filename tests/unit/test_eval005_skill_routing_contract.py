"""EVAL-005 contract: harness-native skill routing (the scan-to-Skill-tool rewrite).

The goldset criterion, goldset cases, promptfoo config, grader, and README
must all grade the new contract — delegation prompts name skills by exact
name and subagents resolve them via their own Skill tool — and must treat
the removed scan mechanism ("Available Skills in This Workspace" inventory)
as a failure, not a pass.
"""

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GOLDSET_MD = ROOT / "evals" / "promptfoo" / "goldset.md"
GOLDSET_JSON = ROOT / "evals" / "promptfoo" / "goldset.json"
CONFIG_JS = ROOT / "evals" / "promptfoo" / "config.js"
README_MD = ROOT / "README.md"
GRADER_PY = (
    ROOT / "evals" / "promptfoo" / "graders" / "check_universal_skill_routing.py"
)

NEW_PASS_OUTPUT = (
    "Step: Implement the retry logic. Use the `tdd` skill for this step — "
    "resolve it via your own Skill tool. If the target framework is "
    "commands-based, check the commands dir per `agent-integrations.md`; "
    "an absent commands dir means the step executes directly."
)

REMOVED_SCAN_OUTPUT = (
    "## Available Skills in This Workspace\n"
    "- **tdd** (`.claude/skills/tdd`) — Test-driven development...\n"
    "Review each skill's name and description. If one matches the goal of "
    "your current task, invoke it. If none apply, proceed with direct "
    "execution."
)

HARDCODED_MAPPING_OUTPUT = (
    "Phase implement → skill tdd. Phase converge → skill code-review. "
    "Execute the mapped skill for this phase."
)


def _load_grader():
    spec = importlib.util.spec_from_file_location(
        "check_universal_skill_routing", GRADER_PY
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _goldset_md_section():
    text = GOLDSET_MD.read_text(encoding="utf-8")
    start = text.index("## Criterion EVAL-005:")
    end = text.index("## Criterion EVAL-006:")
    return text[start:end]


def _config_js_block():
    text = CONFIG_JS.read_text(encoding="utf-8")
    anchor = text.index("check_universal_skill_routing.py")
    return text[max(0, anchor - 900) : anchor + 120]


def _readme_section():
    text = README_MD.read_text(encoding="utf-8")
    start = text.index("## Universal orchestration")
    end = text.index("## ", start + 10)
    return text[start:end]


class TestGrader:
    def test_new_contract_output_passes(self):
        verdict = _load_grader().get_assert(NEW_PASS_OUTPUT)
        assert verdict["pass"] is True, verdict["reason"]

    def test_removed_scan_mechanism_fails(self):
        """The old pass output (scanned inventory) is now a regression."""
        verdict = _load_grader().get_assert(REMOVED_SCAN_OUTPUT)
        assert verdict["pass"] is False
        reason = verdict["reason"].lower()
        assert "scanned" in reason or "inventory" in reason, verdict["reason"]

    def test_hardcoded_mapping_fails(self):
        verdict = _load_grader().get_assert(HARDCODED_MAPPING_OUTPUT)
        assert verdict["pass"] is False
        assert "hard-coded" in verdict["reason"].lower(), verdict["reason"]

    def test_backticked_non_skill_token_does_not_count_as_skill_name(self):
        """A backticked word that is not a skill name (e.g. `retry` helper)
        must not satisfy the exact-name requirement."""
        no_skill_named = (
            "Step: implement the logic. Use the `retry` helper. Resolve "
            "via the Skill tool; an absent commands dir means the step "
            "executes directly."
        )
        verdict = _load_grader().get_assert(no_skill_named)
        assert verdict["pass"] is False
        assert "exact name" in verdict["reason"], verdict["reason"]


class TestGoldsetMarkdown:
    def test_criterion_grades_harness_native_contract(self):
        section = _goldset_md_section()
        assert "exact name" in section
        assert "Skill tool" in section
        assert "commands-based" in section

    def test_scan_mechanism_appears_only_as_failure(self):
        section = _goldset_md_section()
        pass_condition = section.split("### Fail Condition")[0]
        # The phrase may appear in the Pass Condition only in negated form.
        assert "no scanned" in pass_condition
        for occurrence in pass_condition.split("Available Skills in This Workspace")[:-1]:
            assert occurrence.rstrip(' "\'').endswith("no scanned"), (
                "pass condition mentions the scanned-inventory section without "
                "negating it"
            )
        fail_part = section.split("### Fail Condition")[1]
        assert "Available Skills in This Workspace" in fail_part


class TestGoldsetJson:
    def _cases(self):
        data = json.loads(GOLDSET_JSON.read_text(encoding="utf-8"))
        return [c for c in data["cases"] if c["criterion_id"] == "EVAL-005"]

    def test_pass_case_uses_new_contract(self):
        pass_cases = [c for c in self._cases() if c["type"] == "pass"]
        assert pass_cases, "EVAL-005 must keep at least one pass case"
        for case in pass_cases:
            assert "Skill tool" in case["expected_output"], case["id"]
            assert "Available Skills in This Workspace" not in case[
                "expected_output"
            ], case["id"]

    def test_removed_scan_output_is_a_fail_case(self):
        fail_cases = [c for c in self._cases() if c["type"] == "fail"]
        assert any(
            "Available Skills in This Workspace" in c["expected_output"]
            for c in fail_cases
        ), "the removed scan mechanism must be pinned as a fail case"


class TestConfigAndReadme:
    def test_config_instructs_new_contract_not_scan_emission(self):
        block = _config_js_block()
        assert "Available Skills in This Workspace" not in block
        assert "exact name" in block
        assert "Skill tool" in block

    def test_readme_states_harness_native_routing(self):
        section = _readme_section()
        assert "scans installed skills" not in section
        assert "Skill tool" in section
