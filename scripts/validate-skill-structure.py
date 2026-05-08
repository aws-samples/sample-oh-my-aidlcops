#!/usr/bin/env python3
"""Validate SKILL.md structural consistency and cross-references.

Checks:
1. Required sections exist in every SKILL.md
2. Internal cross-references point to existing files
3. YAML code blocks are valid YAML
"""

import re
import sys
import yaml
from pathlib import Path


# ============================================================
# 1. Section Structure Validation
# ============================================================

REQUIRED_SECTIONS = [
    "When to Use",
    "Prerequisites",
    "상태 관리",
    "기존 스킬 연동",
    "참고 자료",
]

OPTIONAL_SECTIONS = [
    "Example Inputs/Outputs",
    "실행 흐름",
]


def check_sections(filepath: Path, content: str) -> list[str]:
    """Check that all required sections exist."""
    errors = []
    # Extract all ## headings
    headings = re.findall(r"^##\s+(.+)$", content, re.MULTILINE)
    
    for section in REQUIRED_SECTIONS:
        found = any(section.lower() in h.lower() for h in headings)
        if not found:
            errors.append(f"  Missing required section: '## {section}'")
    
    return errors


# ============================================================
# 2. Cross-Reference Validation
# ============================================================

def check_cross_references(filepath: Path, content: str, 
                           all_skill_dirs: list[str]) -> list[str]:
    """Check that internal skill references point to existing files."""
    errors = []
    
    # Find relative path references like (../incident-response/SKILL.md)
    refs = re.findall(r"\((\.\./[^)]+/SKILL\.md)\)", content)
    
    for ref in refs:
        # Resolve relative to current file's directory
        resolved = (filepath.parent / ref).resolve()
        if not resolved.exists():
            # Also check without resolve (relative check)
            rel_target = filepath.parent / ref
            if not rel_target.exists():
                errors.append(f"  Broken reference: {ref}")
    
    # Also check skill names mentioned in text
    # Pattern: `skill-name` skill or skill-name skill
    mentioned_skills = re.findall(r"`([a-z]+-[a-z-]+)`\s*(?:skill|스킬)", content)
    for skill_name in mentioned_skills:
        if skill_name not in all_skill_dirs and skill_name not in (
            "audit-trail",  # might be referenced generically
        ):
            # Not a hard error, just a warning
            pass
    
    return errors


# ============================================================
# 3. YAML Block Validation
# ============================================================

def check_yaml_blocks(filepath: Path, content: str) -> list[str]:
    """Validate YAML code blocks."""
    errors = []
    
    # Extract yaml blocks
    pattern = re.compile(r"```ya?ml\n(.*?)```", re.DOTALL)
    
    for i, match in enumerate(pattern.finditer(content), 1):
        block = match.group(1)
        line_num = content[:match.start()].count("\n") + 2
        
        try:
            yaml.safe_load(block)
        except yaml.YAMLError as e:
            # Get error line if available
            err_line = ""
            if hasattr(e, "problem_mark") and e.problem_mark:
                err_line = f" (line {e.problem_mark.line + 1} in block)"
            errors.append(
                f"  YAML block #{i} at line ~{line_num}: {e.problem}{err_line}"
            )
    
    return errors


# ============================================================
# Main
# ============================================================

def main():
    skills_dir = Path("plugins/agenticops/skills")
    
    if not skills_dir.exists():
        print(f"ERROR: {skills_dir} not found")
        sys.exit(1)
    
    skill_files = sorted(skills_dir.glob("*/SKILL.md"))
    all_skill_dirs = [f.parent.name for f in skill_files]
    
    print("=" * 70)
    print("SKILL.md Validation — Structure, References, YAML")
    print("=" * 70)
    
    total_errors = 0
    
    # --- Section Structure ---
    print("\n[1/3] Section Structure Validation")
    print("-" * 50)
    
    for filepath in skill_files:
        content = filepath.read_text()
        errors = check_sections(filepath, content)
        total_errors += len(errors)
        
        status = "✅" if not errors else "❌"
        print(f"  {status} {filepath.parent.name}")
        for e in errors:
            print(f"    {e}")
    
    # --- Cross References ---
    print("\n[2/3] Cross-Reference Validation")
    print("-" * 50)
    
    for filepath in skill_files:
        content = filepath.read_text()
        errors = check_cross_references(filepath, content, all_skill_dirs)
        total_errors += len(errors)
        
        status = "✅" if not errors else "❌"
        ref_count = len(re.findall(r"\((\.\./[^)]+/SKILL\.md)\)", content))
        print(f"  {status} {filepath.parent.name} ({ref_count} refs)")
        for e in errors:
            print(f"    {e}")
    
    # --- YAML Blocks ---
    print("\n[3/3] YAML Block Validation")
    print("-" * 50)
    
    total_yaml_blocks = 0
    for filepath in skill_files:
        content = filepath.read_text()
        yaml_count = len(re.findall(r"```ya?ml\n", content))
        total_yaml_blocks += yaml_count
        errors = check_yaml_blocks(filepath, content)
        total_errors += len(errors)
        
        if yaml_count > 0:
            status = "✅" if not errors else "❌"
            print(f"  {status} {filepath.parent.name} ({yaml_count} blocks)")
            for e in errors:
                print(f"    {e}")
        else:
            print(f"  ⏭️  {filepath.parent.name} (no YAML blocks)")
    
    # --- Summary ---
    print("\n" + "=" * 70)
    print(f"Summary: {len(skill_files)} files, {total_yaml_blocks} YAML blocks, {total_errors} errors")
    print("=" * 70)
    
    sys.exit(0 if total_errors == 0 else 1)


if __name__ == "__main__":
    main()
