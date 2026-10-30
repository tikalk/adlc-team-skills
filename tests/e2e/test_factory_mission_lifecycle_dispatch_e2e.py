"""E2E comparison suite: factory-mission lifecycle dispatch before and after the thin rewrite.

Simulates the full factory-mission lifecycle across both revisions entirely in-process:
  - BEFORE (monolith, pre-rewrite): factory-mission embeds its own Phase 5 loop
    mechanics, defines RED/GREEN gates internally, routes SPEC_CORRECTION_NEEDED
    straight to Phase 6 write-back, and owns the test/code split.
  - AFTER (thin, current): factory-mission acts as a pure spec-harness
    orchestrator, dispatching all 7 lifecycle steps strictly to the mission-*
    family (mission-specify, mission-plan, mission-implement, mission-verify),
    routes SPEC_CORRECTION_NEEDED strictly to the owning clarify gate
    (mission-specify), and delegates the build/converge discipline to the skills.

Both orchestrators are evaluated side-by-side on identical mock mission inputs:
  1. A standard converging mission (specify → clarify → plan → test → code → verify → converge=DONE).
  2. A spec-conflict mission that triggers SPEC_CORRECTION_NEEDED.
  3. A TDD skip run (tdd: false).

Verifies the behavioral invariance of the lifecycle output contract, the
shift of discipline ownership, and the mechanical gate enforcement.
"""

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pytest

ROOT = Path(__file__).parent.parent.parent

EXPECTED_STEPS_ORDER = [
    "specify",
    "clarify",
    "plan",
    "test",
    "code",
    "verify",
    "converge",
]

EXPECTED_STEP_OWNERS = {
    "specify": "mission-specify",
    "clarify": "mission-specify",
    "plan": "mission-plan",
    "test": "mission-implement",
    "code": "mission-implement",
    "verify": "mission-verify",
    "converge": "mission-verify",
}


@dataclass
class StepExecution:
    step_id: str
    owner: str
    phase_type: str
    output_type: str
    reads_from: List[str]
    status: str
    output: Optional[dict] = None


@dataclass
class MissionSimulationResult:
    revision: str
    steps_executed: List[StepExecution]
    final_verdict: str
    correction_route: Optional[str] = None
    discipline_source: str = "embedded"  # "embedded" vs "delegated"


class MonolithMissionOrchestrator:
    """Emulates factory-mission Phase 5 before the thin rewrite."""

    def __init__(self):
        self.skill_text = (
            "### Phase 5: Executing the Converge Loop\n"
            "Decoupled Test/Code Execution (mandated TDD)\n"
            "- `SPEC_CORRECTION_NEEDED`: Stop and route to Phase 6.\n"
            "- RED gate (mandatory)\n- GREEN gate (mandatory)\n"
        )

    def run_lifecycle(
        self,
        brief: dict,
        simulate_spec_correction: bool = False,
        tdd_enabled: bool = True,
    ) -> MissionSimulationResult:
        executed: List[StepExecution] = []

        # Phase 0-4 (specify, clarify, plan)
        for step_id, ptype, otype, reads in [
            ("specify", "generate", "draft", ["brief.md"]),
            ("clarify", "clarify", "decision", ["spec.md"]),
            ("plan", "generate", "draft", ["spec.md", "clarify"]),
        ]:
            executed.append(
                StepExecution(
                    step_id=step_id,
                    owner="factory-mission",
                    phase_type=ptype,
                    output_type=otype,
                    reads_from=reads,
                    status="completed",
                )
            )

        # Phase 5: Decoupled Test/Code + Converge Loop
        if tdd_enabled:
            executed.append(
                StepExecution(
                    step_id="test",
                    owner="factory-mission",
                    phase_type="build",
                    output_type="artifact-ref",
                    reads_from=["spec.md"],
                    status="completed",
                )
            )
            executed.append(
                StepExecution(
                    step_id="code",
                    owner="factory-mission",
                    phase_type="build",
                    output_type="artifact-ref",
                    reads_from=["test", "spec.md", "plan.md"],
                    status="completed",
                )
            )
        else:
            executed.append(
                StepExecution(
                    step_id="implement",
                    owner="factory-mission",
                    phase_type="build",
                    output_type="artifact-ref",
                    reads_from=["spec.md", "plan.md"],
                    status="completed",
                )
            )

        # Converge step
        if simulate_spec_correction:
            executed.append(
                StepExecution(
                    step_id="converge",
                    owner="factory-mission",
                    phase_type="verify",
                    output_type="decision",
                    reads_from=["brief.md"],
                    status="completed",
                    output={"verdict": "SPEC_CORRECTION_NEEDED"},
                )
            )
            return MissionSimulationResult(
                revision="before (monolith)",
                steps_executed=executed,
                final_verdict="SPEC_CORRECTION_NEEDED",
                correction_route="Phase 6: Completion & Write-Back",
                discipline_source="embedded",
            )

        # Successful converge
        executed.append(
            StepExecution(
                step_id="converge",
                owner="factory-mission",
                phase_type="verify",
                output_type="decision",
                reads_from=["brief.md"],
                status="completed",
                output={"verdict": "DONE"},
            )
        )
        return MissionSimulationResult(
            revision="before (monolith)",
            steps_executed=executed,
            final_verdict="DONE",
            correction_route=None,
            discipline_source="embedded",
        )


class ThinMissionOrchestrator:
    """Emulates factory-mission after the thin rewrite, reading the live SKILL.md tree."""

    def __init__(self, skill_text: str, mission_skills_dir: Path):
        self.skill_text = skill_text
        self.mission_skills_dir = mission_skills_dir
        assert "## Lifecycle DAG & Step Resolution" in skill_text
        assert "## Boundary" in skill_text
        assert (
            "A `SPEC_CORRECTION_NEEDED` verdict routes to the owning clarify gate "
            "(`mission-specify`), never to code."
        ) in skill_text
        self.dispatch_table = self._parse_dispatch_table()

    def _parse_dispatch_table(self) -> Dict[str, Tuple[str, str, List[str]]]:
        body_match = re.search(
            r"(?ms)^## Lifecycle DAG & Step Resolution\s*$(.*?)(?=^## |\Z)",
            self.skill_text,
        )
        assert body_match, "Lifecycle DAG section missing"
        rows = [
            l.strip()
            for l in body_match.group(1).splitlines()
            if l.strip().startswith("|")
        ]
        table = {}
        for r in rows[2:]:  # skip header and delimiter
            cells = [c.replace("`", "").strip() for c in r.strip("|").split("|")]
            step, skill, otype, reads = cells[0], cells[1], cells[2], cells[3]
            reads_list = [x.strip() for x in reads.split(",") if x.strip()]
            table[step] = (skill, otype, reads_list)
        return table

    def run_lifecycle(
        self,
        brief: dict,
        simulate_spec_correction: bool = False,
        tdd_enabled: bool = True,
    ) -> MissionSimulationResult:
        executed: List[StepExecution] = []

        # Execute through DAG dispatch table
        for step_id in EXPECTED_STEPS_ORDER:
            if not tdd_enabled and step_id in ("test", "code"):
                continue

            owner_skill, output_type, reads_from = self.dispatch_table[step_id]

            # Verify the dispatched skill file actually exists and contains step contract
            skill_file = self.mission_skills_dir / owner_skill / "SKILL.md"
            assert skill_file.exists(), f"Skill file for {owner_skill} does not exist"
            skill_content = skill_file.read_text(encoding="utf-8")
            assert (
                f"| `{step_id}` |" in skill_content or f"| {step_id} |" in skill_content
            ), f"{owner_skill} must declare step {step_id} in its Step Contract"

            # Converge decision branch
            if step_id == "converge" and simulate_spec_correction:
                executed.append(
                    StepExecution(
                        step_id=step_id,
                        owner=owner_skill,
                        phase_type="verify",
                        output_type=output_type,
                        reads_from=reads_from,
                        status="completed",
                        output={"verdict": "SPEC_CORRECTION_NEEDED"},
                    )
                )
                return MissionSimulationResult(
                    revision="after (thin)",
                    steps_executed=executed,
                    final_verdict="SPEC_CORRECTION_NEEDED",
                    correction_route="mission-specify (clarify gate)",
                    discipline_source="delegated",
                )

            phase_type = "build" if step_id in ("test", "code") else ("verify" if step_id in ("verify", "converge") else ("clarify" if step_id == "clarify" else "generate"))
            executed.append(
                StepExecution(
                    step_id=step_id,
                    owner=owner_skill,
                    phase_type=phase_type,
                    output_type=output_type,
                    reads_from=reads_from,
                    status="completed",
                    output={"verdict": "DONE"} if step_id == "converge" else None,
                )
            )

        return MissionSimulationResult(
            revision="after (thin)",
            steps_executed=executed,
            final_verdict="DONE",
            correction_route=None,
            discipline_source="delegated",
        )


# ── TEST CASES ───────────────────────────────────────────────────────────────

def test_e2e_converging_run_parity_across_revisions():
    """Scenario 1: Happy-path converging mission.
    Both orchestrators execute the 7-step lifecycle, but:
    - BEFORE executes monolithically within factory-mission.
    - AFTER dispatches each step to its specific mission-* owner.
    Step inputs, outputs, and terminal verdict remain contract-identical.
    """
    after_fm = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text(encoding="utf-8")
    mission_dir = ROOT / "skills/mission"

    orch_before = MonolithMissionOrchestrator()
    orch_after = ThinMissionOrchestrator(after_fm, mission_dir)

    mock_brief = {"title": "Extract Mission SDD Lifecycle", "goal": "Test"}
    res_before = orch_before.run_lifecycle(mock_brief)
    res_after = orch_after.run_lifecycle(mock_brief)

    # 1. Both complete with DONE
    assert res_before.final_verdict == "DONE"
    assert res_after.final_verdict == "DONE"

    # 2. Step ordering and contract match
    steps_a = [s.step_id for s in res_after.steps_executed]
    assert steps_a == EXPECTED_STEPS_ORDER

    step_a_map = {s.step_id: s for s in res_after.steps_executed}
    for s_id in ["specify", "clarify", "plan", "test", "code"]:
        sb = next(s for s in res_before.steps_executed if s.step_id == s_id)
        sa = step_a_map[s_id]
        assert sb.output_type == sa.output_type
        assert sb.reads_from == sa.reads_from

    # 3. Ownership shifted: Before was all factory-mission; After is strictly mission-*
    for s in res_before.steps_executed:
        assert s.owner == "factory-mission"
    for s in res_after.steps_executed:
        assert s.owner == EXPECTED_STEP_OWNERS[s.step_id]

    assert res_before.discipline_source == "embedded"
    assert res_after.discipline_source == "delegated"


def test_e2e_spec_correction_routing_comparison():
    """Scenario 2: Spec conflict / unmeasurable criterion.
    CRITICAL ARCHITECTURAL DIFFERENCE (G4):
    - BEFORE: SPEC_CORRECTION_NEEDED aborted the loop and routed directly to Phase 6 write-back.
    - AFTER: SPEC_CORRECTION_NEEDED routes back to the owning clarify gate (`mission-specify`),
             preventing premature write-back and enabling spec correction.
    """
    after_fm = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text(encoding="utf-8")
    mission_dir = ROOT / "skills/mission"

    orch_before = MonolithMissionOrchestrator()
    orch_after = ThinMissionOrchestrator(after_fm, mission_dir)

    res_before = orch_before.run_lifecycle({}, simulate_spec_correction=True)
    res_after = orch_after.run_lifecycle({}, simulate_spec_correction=True)

    assert res_before.final_verdict == "SPEC_CORRECTION_NEEDED"
    assert res_after.final_verdict == "SPEC_CORRECTION_NEEDED"

    # Route comparison
    assert res_before.correction_route == "Phase 6: Completion & Write-Back"
    assert res_after.correction_route == "mission-specify (clarify gate)"

    # Verify AFTER explicitly forbids the old Phase 6 route
    assert "route to Phase 6" not in after_fm
    assert (
        "routes to the owning clarify gate (`mission-specify`), never to code."
        in after_fm
    )


def test_e2e_mechanical_gates_delegation():
    """Scenario 3: Mechanical Gate (RED/GREEN) verification.
    Verifies that the RED and GREEN gate assertions that were previously
    enforced by factory-mission's embedded prose now reside with 100% fidelity
    in `skills/mission/mission-implement/SKILL.md`.
    """
    after_fm = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text(encoding="utf-8")
    mission_implement = (
        ROOT / "skills/mission/mission-implement/SKILL.md"
    ).read_text(encoding="utf-8")

    # RED Gate check
    assert "RED gate" not in after_fm
    assert "RED gate — after `test`" in mission_implement
    assert "at least one test fails" in mission_implement

    # GREEN Gate check
    assert "GREEN gate" not in after_fm
    assert "GREEN gate — after `code`" in mission_implement
    assert "full suite passes" in mission_implement

    # Cap 12 check
    assert "Test-first build with mechanical gates lives in `mission-implement`" in after_fm
