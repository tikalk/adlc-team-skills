import yaml
import json
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent.parent

MAX_FRONTMATTER_DESCRIPTION_CHARS = 1024  # Agent Skills specification limit


def _validate_skill_description(skill_file: Path, root: Path = None) -> str:
    """Return a failure message if the skill's description violates the rules, else ''."""
    root = root or ROOT
    rel = skill_file.relative_to(root)
    content = skill_file.read_text(encoding="utf-8")
    parts = content.split("---", 2)
    if len(parts) < 3:
        return f"Malformed frontmatter in {rel}"
    try:
        metadata = yaml.safe_load(parts[1])
    except yaml.YAMLError as e:
        return f"Invalid YAML in frontmatter of {rel}: {e}"
    if metadata is None or not isinstance(metadata, dict):
        return f"Frontmatter is not a mapping in {rel}"
    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        return f"Missing or empty description field in frontmatter of {rel}"
    if len(description) > MAX_FRONTMATTER_DESCRIPTION_CHARS:
        return (
            f"Description exceeds {MAX_FRONTMATTER_DESCRIPTION_CHARS} characters "
            f"({len(description)}) in {rel}"
        )
    return ""


def test_skill_description_presence_and_length():
    """Every SKILL.md must carry a non-empty description within the spec's 1024-char limit.

    The description is the trigger surface for model-invoked skills and the
    routing surface for mission-brief's universal orchestration; CONTRIBUTING
    documents it as required.
    """
    skill_files = list(ROOT.glob("skills/**/SKILL.md"))
    assert len(skill_files) > 0, "No skills found to test"

    for skill_file in skill_files:
        failure = _validate_skill_description(skill_file)
        assert not failure, failure


def test_description_validator_catches_violations(tmp_path):
    """The description validator must actually fail on broken frontmatter.

    Guards the guard: without this, the presence/length test could silently
    stop checking anything.
    """
    skill_dir = tmp_path / "sample-skill"
    skill_dir.mkdir()
    skill_file = skill_dir / "SKILL.md"

    skill_file.write_text(
        "---\nname: sample-skill\ndescription: ''\n---\n\n# Sample\n", encoding="utf-8"
    )
    missing = _validate_skill_description(skill_file, root=tmp_path)
    assert "Missing or empty description" in missing, f"expected missing-description failure, got: {missing!r}"

    skill_file.write_text(
        "---\nname: sample-skill\ndescription: " + "x" * (MAX_FRONTMATTER_DESCRIPTION_CHARS + 1) + "\n---\n\n# Sample\n",
        encoding="utf-8",
    )
    too_long = _validate_skill_description(skill_file, root=tmp_path)
    assert "exceeds" in too_long, f"expected length failure, got: {too_long!r}"

    skill_file.write_text(
        "---\nname: sample-skill\ndescription: Use when testing validators.\n---\n\n# Sample\n",
        encoding="utf-8",
    )
    ok = _validate_skill_description(skill_file, root=tmp_path)
    assert ok == "", f"expected valid skill to pass, got: {ok!r}"


def test_skill_directory_depth():
    """Every skill must live exactly two levels under skills/ (skills/<domain>/<skill>/).

    The README documents this invariant as what "fully resolv[es] the default
    depth limit of the `skills` CLI and ensur[es] all skills install out of
    the box" — so the tree must actually satisfy it.
    """
    skill_files = list(ROOT.glob("skills/**/SKILL.md"))
    assert len(skill_files) > 0, "No skills found to test"

    violators = []
    for skill_file in skill_files:
        dir_depth = len(skill_file.relative_to(ROOT / "skills").parts) - 1  # exclude SKILL.md
        if dir_depth != 2:
            violators.append(f"{skill_file.relative_to(ROOT)} (depth {dir_depth})")
    assert not violators, (
        "Skills must sit exactly 2 levels deep (skills/<domain>/<skill>/SKILL.md). "
        f"Violators: {violators}"
    )


def test_skill_description_use_when_prefix():
    """Descriptions must lead with "Use when…" — trigger only, no workflow summary.

    The description is the routing surface (mission-brief hands it to
    subagents; the model decides what to load from it). Superpowers'
    writing-skills measured that descriptions summarizing the workflow
    make agents follow the description instead of reading the skill body.
    """
    skill_files = list(ROOT.glob("skills/**/SKILL.md"))
    assert len(skill_files) > 0, "No skills found to test"

    offenders = []
    for skill_file in skill_files:
        parts = skill_file.read_text(encoding="utf-8").split("---", 2)
        assert len(parts) >= 3, f"Malformed frontmatter in {skill_file.relative_to(ROOT)}"
        metadata = yaml.safe_load(parts[1]) or {}
        description = metadata.get("description") or ""
        if not description.strip().lower().startswith("use when"):
            offenders.append(skill_file.relative_to(ROOT))
    assert not offenders, (
        "Skill descriptions must start with \"Use when…\" (trigger conditions, "
        f"not workflow summaries). Offenders: {offenders}"
    )


TOKEN_BUDGET_TARGET_LINES = 500    # writing-skills documented target — soft warning
TOKEN_BUDGET_HARD_CAP_LINES = 800  # hard cap — fails

# Legacy prompt-walls over the cap, grandfathered until they are split into
# references/ (requires before/after PromptFoo evidence per repo rules).
# This list may only shrink. Adding a new entry requires maintainer sign-off
# in the PR — new skills never join it.
TOKEN_BUDGET_EXEMPT = {
    "architect-implement",  # 1273 lines
    "team-repair",          # 1134 lines
}


def test_skill_token_budget():
    """SKILL.md bodies get a token budget: warn above the 500-line target,
    fail above the 800-line hard cap.

    The body is loaded wholesale when a skill fires; heavy reference content
    belongs in references/ (progressive disclosure). The warning is the
    ratchet — the hard cap is the enforcement. Legacy over-cap skills sit
    in TOKEN_BUDGET_EXEMPT (tracked debt; the list only shrinks).
    """
    import warnings

    oversize_soft, oversize_hard = [], []
    for skill_file in sorted(ROOT.glob("skills/**/SKILL.md")):
        name = skill_file.parent.name
        lines = skill_file.read_text(encoding="utf-8").count("\n")  # == wc -l
        if lines > TOKEN_BUDGET_HARD_CAP_LINES and name not in TOKEN_BUDGET_EXEMPT:
            oversize_hard.append(f"{skill_file.relative_to(ROOT)} ({lines} lines)")
        elif lines > TOKEN_BUDGET_TARGET_LINES:
            oversize_soft.append(f"{skill_file.relative_to(ROOT)} ({lines} lines)")

    if oversize_soft:
        warnings.warn(
            "Skills over the 500-line token-budget target — move heavy reference "
            f"content to references/: {oversize_soft}",
            stacklevel=2,
        )
    assert not oversize_hard, (
        f"Skills exceed the {TOKEN_BUDGET_HARD_CAP_LINES}-line hard cap — split heavy "
        f"reference content into references/: {oversize_hard}"
    )


def test_skill_frontmatter_and_directory_parity():
    """Verify every SKILL.md has valid YAML frontmatter and matches its directory name."""
    skill_files = list(ROOT.glob("skills/**/SKILL.md"))
    assert len(skill_files) > 0, "No skills found to test"
    
    for skill_file in skill_files:
        content = skill_file.read_text(encoding="utf-8")
        assert content.startswith("---"), f"Missing frontmatter header in {skill_file.relative_to(ROOT)}"
        
        # Extract frontmatter
        parts = content.split("---", 2)
        assert len(parts) >= 3, f"Malformed frontmatter in {skill_file.relative_to(ROOT)}"
        
        try:
            metadata = yaml.safe_load(parts[1])
        except yaml.YAMLError as e:
            pytest.fail(f"Invalid YAML in frontmatter of {skill_file.relative_to(ROOT)}: {e}")
            
        assert metadata is not None, f"Empty frontmatter in {skill_file.relative_to(ROOT)}"
        assert "name" in metadata, f"Missing name field in frontmatter of {skill_file.relative_to(ROOT)}"
        
        # Verify directory name matches skill name
        dir_name = skill_file.parent.name
        skill_name = metadata.get("name")
        assert dir_name == skill_name, (
            f"Parity mismatch: Skill directory '{dir_name}' does not match "
            f"frontmatter name '{skill_name}' in {skill_file.relative_to(ROOT)}"
        )

def test_template_and_boilerplate_frontmatter():
    """Verify all markdown templates and boilerplates have structurally well-formed metadata."""
    templates = list(ROOT.glob("skills/product/product-templates/*.md")) + \
                list(ROOT.glob("skills/evals/evals-templates/*.md")) + \
                list(ROOT.glob("skills/authoring/writing-skills/templates/*.md"))
    
    import re
    for template_file in templates:
        content = template_file.read_text(encoding="utf-8")
        # Template files can optionally start with a title or standard description
        if content.startswith("---"):
            parts = content.split("---", 2)
            assert len(parts) >= 3, f"Malformed frontmatter in template {template_file.relative_to(ROOT)}"
            
            # Clean up template interpolation blocks (e.g. {{...}} or Handlebars tags)
            # so the raw un-rendered text is structurally valid YAML for parsing.
            frontmatter_raw = parts[1]
            
            # Remove Handlebars block control tags entirely
            frontmatter_clean = re.sub(r"\{\{\#[^}]+\}\}", "", frontmatter_raw)
            frontmatter_clean = re.sub(r"\{\{\/[^}]+\}\}", "", frontmatter_clean)
            # Replace normal variables with dummy values
            frontmatter_clean = re.sub(r"\{\{[^}#\/]+\}\}", "dummy_val", frontmatter_clean)
            
            try:
                metadata = yaml.safe_load(frontmatter_clean)
                assert metadata is not None
            except yaml.YAMLError as e:
                pytest.fail(f"Invalid YAML in frontmatter of template {template_file.relative_to(ROOT)}: {e}. Cleaned frontmatter: {frontmatter_clean}")

def test_active_config_template_integrity():
    """Verify that default evals-config-template.yml contains required EDD keys."""
    config_file = ROOT / "skills/evals/evals-templates/evals-config-template.yml"
    assert config_file.exists()
    
    content = config_file.read_text(encoding="utf-8")
    try:
        config = yaml.safe_load(content)
    except yaml.YAMLError as e:
        pytest.fail(f"Invalid YAML in config template: {e}")
        
    # Check core EDD structure
    assert "system" in config
    assert "paths" in config
    assert "evaluation" in config
    assert "error_analysis" in config
    assert "evaluation_pyramid" in config
    assert "trajectory" in config
    assert "test_data" in config
    assert "cross_functional" in config
