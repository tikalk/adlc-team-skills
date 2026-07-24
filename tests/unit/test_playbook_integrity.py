import yaml
import json
from pathlib import Path
import pytest

ROOT = Path(__file__).parent.parent.parent

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
    templates = list(ROOT.glob("skills/workflow/product-templates/*.md")) + \
                list(ROOT.glob("skills/governance/evals-templates/*.md"))
    
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
    config_file = ROOT / "skills/governance/evals-templates/evals-config-template.yml"
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
