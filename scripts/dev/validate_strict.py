#!/usr/bin/env python3
"""
Strict JSON Schema validation using jsonschema library.
Validates all plugin.json, SKILL.md frontmatter, .mcp.json, and marketplace.json files.
"""

import json
import yaml
import sys
from pathlib import Path
from jsonschema import validate, ValidationError, Draft7Validator
from typing import Dict, List, Tuple

def load_schema(schema_path: Path) -> dict:
    """Load a JSON schema from file."""
    with open(schema_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def extract_yaml_frontmatter(content: str) -> dict:
    """Extract YAML frontmatter from markdown file."""
    if not content.startswith('---\n'):
        return None

    end = content.find('\n---\n', 4)
    if end == -1:
        return None

    yaml_content = content[4:end]
    return yaml.safe_load(yaml_content)

def validate_file(file_path: Path, schema: dict, schema_name: str, is_frontmatter: bool = False) -> Tuple[bool, str]:
    """
    Validate a single file against schema.
    Returns (success, error_message).
    """
    try:
        if is_frontmatter:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            data = extract_yaml_frontmatter(content)
            if data is None:
                return False, "No valid YAML frontmatter found"
        else:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

        # Validate against schema
        validate(instance=data, schema=schema)
        return True, ""

    except ValidationError as e:
        # Format validation error with path
        path = " -> ".join(str(p) for p in e.path) if e.path else "root"
        return False, f"{path}: {e.message}"

    except json.JSONDecodeError as e:
        return False, f"JSON parse error: {e.msg} at line {e.lineno}"

    except yaml.YAMLError as e:
        return False, f"YAML parse error: {str(e)}"

    except Exception as e:
        return False, f"Unexpected error: {str(e)}"

def main():
    repo_root = Path(__file__).parent.parent.parent
    schemas_dir = repo_root / "schemas"

    results = {
        "jsonschema_lib_installed": True,
        "schemas_loaded": 0,
        "files_validated": 0,
        "passes": 0,
        "failures": [],
        "fixes_applied": [],
        "final_passes": 0
    }

    # Load all schemas
    schemas = {}
    schema_files = [
        ("plugin", "plugin.schema.json"),
        ("skill-frontmatter", "skill-frontmatter.schema.json"),
        ("mcp", "mcp.schema.json"),
        ("marketplace", "marketplace.schema.json")
    ]

    print("Loading schemas...")
    for name, filename in schema_files:
        schema_path = schemas_dir / filename
        if schema_path.exists():
            schemas[name] = load_schema(schema_path)
            results["schemas_loaded"] += 1
            print(f"  ✓ Loaded {filename}")
        else:
            print(f"  ✗ Schema not found: {filename}")
            sys.exit(1)

    print(f"\nLoaded {results['schemas_loaded']} schemas\n")

    # Validate marketplace.json
    print("Validating marketplace.json...")
    marketplace_path = repo_root / ".claude-plugin" / "marketplace.json"
    if marketplace_path.exists():
        results["files_validated"] += 1
        success, error = validate_file(marketplace_path, schemas["marketplace"], "marketplace")
        if success:
            results["passes"] += 1
            print(f"  ✓ PASS: {marketplace_path.relative_to(repo_root)}")
        else:
            results["failures"].append({
                "file": str(marketplace_path.relative_to(repo_root)),
                "error": error
            })
            print(f"  ✗ FAIL: {marketplace_path.relative_to(repo_root)}")
            print(f"    {error}")

    # Validate plugin.json files
    print("\nValidating plugin.json files...")
    plugins_dir = repo_root / "plugins"
    if plugins_dir.exists():
        for plugin_dir in sorted(plugins_dir.iterdir()):
            if plugin_dir.is_dir():
                plugin_json = plugin_dir / ".claude-plugin" / "plugin.json"
                if plugin_json.exists():
                    results["files_validated"] += 1
                    success, error = validate_file(plugin_json, schemas["plugin"], "plugin")
                    if success:
                        results["passes"] += 1
                        print(f"  ✓ PASS: {plugin_json.relative_to(repo_root)}")
                    else:
                        results["failures"].append({
                            "file": str(plugin_json.relative_to(repo_root)),
                            "error": error
                        })
                        print(f"  ✗ FAIL: {plugin_json.relative_to(repo_root)}")
                        print(f"    {error}")

    # Validate SKILL.md frontmatter
    print("\nValidating SKILL.md frontmatter...")
    for plugin_dir in sorted(plugins_dir.iterdir()):
        if plugin_dir.is_dir():
            skills_dir = plugin_dir / "skills"
            if skills_dir.exists():
                for skill_dir in sorted(skills_dir.iterdir()):
                    if skill_dir.is_dir():
                        skill_md = skill_dir / "SKILL.md"
                        if skill_md.exists():
                            results["files_validated"] += 1
                            success, error = validate_file(
                                skill_md,
                                schemas["skill-frontmatter"],
                                "skill-frontmatter",
                                is_frontmatter=True
                            )
                            if success:
                                results["passes"] += 1
                                print(f"  ✓ PASS: {skill_md.relative_to(repo_root)}")
                            else:
                                results["failures"].append({
                                    "file": str(skill_md.relative_to(repo_root)),
                                    "error": error
                                })
                                print(f"  ✗ FAIL: {skill_md.relative_to(repo_root)}")
                                print(f"    {error}")

    # Validate .mcp.json files
    print("\nValidating .mcp.json files...")
    for plugin_dir in sorted(plugins_dir.iterdir()):
        if plugin_dir.is_dir():
            mcp_json = plugin_dir / ".mcp.json"
            if mcp_json.exists():
                results["files_validated"] += 1
                success, error = validate_file(mcp_json, schemas["mcp"], "mcp")
                if success:
                    results["passes"] += 1
                    print(f"  ✓ PASS: {mcp_json.relative_to(repo_root)}")
                else:
                    results["failures"].append({
                        "file": str(mcp_json.relative_to(repo_root)),
                        "error": error
                    })
                    print(f"  ✗ FAIL: {mcp_json.relative_to(repo_root)}")
                    print(f"    {error}")

    # Summary
    print("\n" + "="*60)
    print("VALIDATION SUMMARY")
    print("="*60)
    print(f"Total files validated: {results['files_validated']}")
    print(f"Passes: {results['passes']}")
    print(f"Failures: {len(results['failures'])}")

    if results["failures"]:
        print("\nFailed files:")
        for failure in results["failures"]:
            print(f"  - {failure['file']}")
            print(f"    {failure['error']}")
        print("\n⚠️  Validation failed. Please fix the errors above.")
        return results, 1
    else:
        print("\n✅ All validations passed!")
        return results, 0

if __name__ == "__main__":
    results, exit_code = main()

    # Print JSON results
    print("\nResults JSON:")
    print(json.dumps(results, indent=2))

    sys.exit(exit_code)
