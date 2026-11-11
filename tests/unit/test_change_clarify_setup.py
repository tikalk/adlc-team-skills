"""The change-clarify loader must see every pending ChDR.

A ChDR draft carries its status in YAML frontmatter (the canonical draft
template) or, in a full record, in a "### Status: **X**" heading. The
setup script matched only the heading form, so it reported "no pending
ChDRs" for drafts written from the template — including the ones
team-boot's continuous capture produces, and including every ChDR this
workspace holds. A review gate that cannot see the record it is meant to
review is silently inert.
"""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
BASH = ROOT / "skills/change/change-clarify/scripts/bash/setup-change-clarify.sh"
PS1 = ROOT / "skills/change/change-clarify/scripts/powershell/setup-change-clarify.ps1"

FRONTMATTER_DRAFT = """\
---
status: proposed
date: 2026-10-20
type: incident
---

# ChDR-900: a draft written from the canonical template

## Context
Something happened.
"""

HEADING_DRAFT = """\
# ChDR-901: a full record with a status heading

### Status: **Proposed**

## Context
Something happened.
"""

ACCEPTED_DRAFT = """\
---
status: accepted
date: 2026-10-19
---

# ChDR-902: an accepted draft
"""


@pytest.fixture
def project(tmp_path):
    (tmp_path / ".adlc" / "drafts" / "chdr").mkdir(parents=True)
    return tmp_path


def write(project, name, body):
    (project / ".adlc" / "drafts" / "chdr" / name).write_text(body, encoding="utf-8")


def run_bash(project):
    proc = subprocess.run(
        ["bash", str(BASH)], cwd=project, capture_output=True, text=True, timeout=30
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_frontmatter_status_drafts_are_pending(project):
    write(project, "ChDR-900-frontmatter.md", FRONTMATTER_DRAFT)
    out = run_bash(project)
    assert out["PENDING_CHDRS"] == 1, out
    assert out["ACCEPTED_CHDRS"] == 0, out
    assert out["EXISTING_CHDRS"] == 1, out


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_heading_status_drafts_are_pending(project):
    write(project, "ChDR-901-heading.md", HEADING_DRAFT)
    out = run_bash(project)
    assert out["PENDING_CHDRS"] == 1, out


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_accepted_drafts_are_not_pending(project):
    write(project, "ChDR-902-accepted.md", ACCEPTED_DRAFT)
    out = run_bash(project)
    assert out["ACCEPTED_CHDRS"] == 1, out
    assert out["PENDING_CHDRS"] == 0, out


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_both_status_forms_count(project):
    write(project, "ChDR-900-frontmatter.md", FRONTMATTER_DRAFT)
    write(project, "ChDR-901-heading.md", HEADING_DRAFT)
    write(project, "ChDR-902-accepted.md", ACCEPTED_DRAFT)
    out = run_bash(project)
    assert out["PENDING_CHDRS"] == 2, out
    assert out["ACCEPTED_CHDRS"] == 1, out
    assert out["EXISTING_CHDRS"] == 3, out


COMMENTED_DRAFT = """\
---
status: proposed  # still gathering evidence
date: 2026-10-20
type: incident
---

# ChDR-903: a draft annotated in the template's own style

The draft template teaches inline comments on sibling fields
(`type: incident  # incident | workaround | abandoned`), so `status:` may
carry one too.
"""

MIXED_CASE_DRAFT = """\
---
status: Proposed
date: 2026-10-20
---

# ChDR-904: a draft whose status was typed in title case
"""

MIXED_CASE_ACCEPTED_DRAFT = """\
---
status: Accepted  # settled in review
date: 2026-10-19
---

# ChDR-905: an accepted draft, annotated
"""

NO_STATUS_DRAFT = """\
# ChDR-906: a record with no status at all

Neither frontmatter nor a heading.
"""


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_frontmatter_status_with_inline_comment_is_pending(project):
    """`status: proposed  # why` is YAML frontmatter, not a different status."""
    write(project, "ChDR-903-commented.md", COMMENTED_DRAFT)
    out = run_bash(project)
    assert out["PENDING_CHDRS"] == 1, out
    assert out["EXISTING_CHDRS"] == 1, out


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_frontmatter_status_is_case_insensitive(project):
    """`status: Proposed` names the same status as `status: proposed`."""
    write(project, "ChDR-904-mixed-case.md", MIXED_CASE_DRAFT)
    out = run_bash(project)
    assert out["PENDING_CHDRS"] == 1, out


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_mixed_case_accepted_frontmatter_is_not_pending(project):
    """Normalising case must not turn an accepted draft into a pending one."""
    write(project, "ChDR-905-accepted.md", MIXED_CASE_ACCEPTED_DRAFT)
    out = run_bash(project)
    assert out["ACCEPTED_CHDRS"] == 1, out
    assert out["PENDING_CHDRS"] == 0, out


FULL_RECORD_ACCEPTED = """\
---
status: discovered  # discovered | proposed | accepted | rejected | superseded
date: 2026-10-01
reviewer: someone
---

# ChDR-907: a record published from the full template, then accepted

### Status: **Accepted**

## Context

The full-record template ships `status: discovered` in its frontmatter and
the accept flow updates only the heading. The heading is the decision.
"""


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_heading_outranks_stale_frontmatter_on_a_full_record(project):
    """A published record accepted via its heading must not read as pending."""
    write(project, "ChDR-907-full-record.md", FULL_RECORD_ACCEPTED)
    out = run_bash(project)
    assert out["ACCEPTED_CHDRS"] == 1, out
    assert out["PENDING_CHDRS"] == 0, out


@pytest.mark.skipif(shutil.which("bash") is None, reason="bash not available")
def test_draft_without_any_status_does_not_abort_the_loader(project):
    """A statusless draft is counted as existing, not as a fatal grep miss."""
    write(project, "ChDR-906-statusless.md", NO_STATUS_DRAFT)
    out = run_bash(project)
    assert out["PENDING_CHDRS"] == 0, out
    assert out["ACCEPTED_CHDRS"] == 0, out
    assert out["EXISTING_CHDRS"] == 1, out


def test_powershell_twin_reads_the_same_forms():
    """The bash and PowerShell setup scripts must agree (same stem, same JSON)."""
    text = PS1.read_text(encoding="utf-8")
    assert "status:" in text, "the PowerShell twin must read the frontmatter status"
    assert "### Status" in text, "the PowerShell twin must read the heading status"
