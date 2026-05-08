#!/usr/bin/env python3
"""Validate Python code blocks in SKILL.md files.

Extracts ```python ... ``` blocks from markdown and runs ast.parse()
to check for syntax errors. Does NOT execute the code.
"""

import ast
import re
import sys
from pathlib import Path


def extract_python_blocks(md_content: str) -> list[tuple[int, str]]:
    """Extract python code blocks with their starting line numbers."""
    blocks = []
    pattern = re.compile(r"```python\n(.*?)```", re.DOTALL)
    
    for match in pattern.finditer(md_content):
        # Calculate line number of block start
        line_num = md_content[:match.start()].count("\n") + 2
        blocks.append((line_num, match.group(1)))
    
    return blocks


def validate_block(code: str, filename: str, line_offset: int) -> list[str]:
    """Try to parse a code block. Return list of errors."""
    errors = []
    try:
        ast.parse(code)
    except SyntaxError as e:
        actual_line = line_offset + (e.lineno or 0) - 1
        errors.append(
            f"  Line ~{actual_line}: SyntaxError: {e.msg}"
            f" (block starts at line {line_offset})"
        )
    return errors


def validate_file(filepath: Path) -> tuple[int, int, list[str]]:
    """Validate all python blocks in a file. Returns (total, errors, messages)."""
    content = filepath.read_text()
    blocks = extract_python_blocks(content)
    
    all_errors = []
    for line_num, code in blocks:
        errs = validate_block(code, str(filepath), line_num)
        all_errors.extend(errs)
    
    return len(blocks), len(all_errors), all_errors


def main():
    skills_dir = Path("plugins/agenticops/skills")
    
    if not skills_dir.exists():
        print(f"ERROR: {skills_dir} not found")
        sys.exit(1)
    
    skill_files = sorted(skills_dir.glob("*/SKILL.md"))
    
    if not skill_files:
        print("No SKILL.md files found")
        sys.exit(1)
    
    total_blocks = 0
    total_errors = 0
    
    print("=" * 60)
    print("Python Syntax Validation — SKILL.md code blocks")
    print("=" * 60)
    
    for filepath in skill_files:
        rel_path = filepath
        blocks, errors, messages = validate_file(filepath)
        total_blocks += blocks
        total_errors += errors
        
        status = "✅ PASS" if errors == 0 else "❌ FAIL"
        print(f"\n{status}  {rel_path} ({blocks} blocks, {errors} errors)")
        
        for msg in messages:
            print(msg)
    
    print("\n" + "=" * 60)
    print(f"Total: {total_blocks} blocks checked, {total_errors} syntax errors")
    print("=" * 60)
    
    sys.exit(0 if total_errors == 0 else 1)


if __name__ == "__main__":
    main()
