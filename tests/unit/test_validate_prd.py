import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
VALIDATOR = ROOT / "skills/product/product-implement/scripts/bash/validate-prd.sh"

PASSING_PRD = """# Sample Product PRD

## 1. Document Information

**Product**: Sample Product
**Version**: 1.0.0

## 1.5 Executive Summary

Executive summary of the sample product.

## 2. Overview

Overview of the sample product.

```mermaid
flowchart LR
    A[Login] --> B[Dashboard]
```

## 3. Problem

The problem being solved.

## 3.5 Market Opportunity

The market opportunity.

## 4. Goals

Goals of the product.

## 5. Metrics

Success metrics.

## 6. Personas

Primary personas.

## 7. Functional Requirements

### Feature Requirements

- **REQ-001:** The system must authenticate users.
  **Traced to:** PDR-001 (Authentication)

- **REQ-002:** The system must allow profile editing.
  **Traced to:** PDR-002 (Profile)

```mermaid
flowchart LR
    R1[REQ-001] --> R2[REQ-002]
```

## 8. Non-Functional Requirements

Performance and security requirements.

## 9. Out of Scope

Out of scope items.

## 10. Risks

Risks and mitigations.

## 10.5 Investment

Investment required.

## 11. Roadmap

Roadmap and milestones.

## 11.5 Go-to-Market

Go-to-market plan.

## 12. PDR Summary

Summary of product decisions.

## Constitution Alignment

This product aligns with the team constitution.
"""

WARNING_PRD = """# Sample Product PRD

## 1. Document Information

**Product**: Sample Product
**Version**: 1.0.0

## 2. Overview

Overview of the sample product.

```mermaid
flowchart LR
    A[Login] --> B[Dashboard]
```

## 3. Problem

The problem being solved.

## 4. Goals

Goals of the product.

## 5. Metrics

Success metrics.

## 6. Personas

Primary personas.

## 7. Functional Requirements

### Feature Requirements

- **REQ-001:** The system must authenticate users.
  **Traced to:** PDR-001 (Authentication)

- **REQ-002:** The system must allow profile editing.
  **Traced to:** PDR-002 (Profile)

## 8. Non-Functional Requirements

Performance and security requirements.

## 9. Out of Scope

Out of scope items.

## 10. Risks

Risks and mitigations.

## 11. Roadmap

Roadmap and milestones.

## 12. PDR Summary

Summary of product decisions.
"""


def _run_validator(prd_dir, *args):
    return subprocess.run(
        ["bash", str(VALIDATOR), "PRD.md", *args],
        cwd=prd_dir,
        capture_output=True,
        text=True,
    )


@pytest.fixture
def prd_project(tmp_path):
    project = tmp_path / "prd"
    project.mkdir()
    return project


@pytest.mark.requires_bash
def test_warn_mode_reaches_summary_instead_of_aborting(prd_project):
    """Regression: set -e + ((WARNINGS++)) used to abort on the first warning.

    A PRD that only produces warnings must complete all checks and print the
    summary, exiting with 2 (warn mode) rather than dying at exit 1.
    """
    (prd_project / "PRD.md").write_text(WARNING_PRD)
    result = _run_validator(prd_project)
    assert result.returncode == 2, result.stdout + result.stderr
    assert "Validation Summary" in result.stdout


@pytest.mark.requires_bash
def test_strict_mode_exits_1_on_warnings(prd_project):
    (prd_project / "PRD.md").write_text(WARNING_PRD)
    result = _run_validator(prd_project, "--strict")
    assert result.returncode == 1, result.stdout + result.stderr
    assert "warning(s) found" in result.stdout


@pytest.mark.requires_bash
def test_canonical_req_format_is_counted(prd_project):
    """Regression: REQ regex missed the '- **REQ-NNN:**' format the skill's own
    requirements template emits, so REQ_COUNT was always 0."""
    (prd_project / "PRD.md").write_text(WARNING_PRD)
    result = _run_validator(prd_project)
    assert result.returncode == 2, result.stdout + result.stderr
    assert "Found 2 requirements" in result.stdout


@pytest.mark.requires_bash
def test_passing_prd_exits_0(prd_project):
    (prd_project / "PRD.md").write_text(PASSING_PRD)
    (prd_project / ".adlc" / "memory").mkdir(parents=True)
    (prd_project / ".adlc" / "memory" / "constitution.md").write_text(
        "# Team Constitution\n\n1. Human Oversight Is Mandatory\n"
    )
    result = _run_validator(prd_project)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "All checks passed" in result.stdout
    assert "All requirements trace to PDRs" in result.stdout
